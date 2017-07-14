//
//  FileDecryptor.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 21/04/17.
//
//

import Foundation

extension MiniLock
{
    /// The class has two public methods:
    ///     - decrypt(deleteSourceFile: Bool) throws -> Data
    ///     - decrypt(destinationDirectory: URL, filename suggestedFilename: String?, deleteSourceFile: Bool) throws -> URL
    public final class FileDecryptor: MiniLockProcess
    {
        private let sourceFile: URL
        private let recipientKeys: KeyPair
        private let fileSize: Double
        private var bytesDecrypted: Int = 0 {
            didSet {
                processDelegate?.setProgress(to: Double(bytesDecrypted) / fileSize, process: self)
            }
        }
        
        private var _processStatus: MiniLock.ProcessStatus = .incomplete
        
        /// Determines the current state of decryption
        public var processStatus: MiniLock.ProcessStatus {
            return _processStatus
        }
        private var _sender: MiniLock.Id?
        
        /// Id of the sender of the file. \n
        /// Warning: Available only after the end of decryption when processStatus's value is 'succeeded'
        public var sender: MiniLock.Id! {
            return _sender
        }
        
        private var headerOffsetInSourceFile: UInt64 = 0

        /// A delegate to monitor the progresss of the process
        public weak var processDelegate: MiniLockProcessDelegate?
        
        /// Returns a FileDecryptor object that will try to decrypt 'sourceFile' using 'recipientKeys'
        ///
        /// - Parameters:
        ///   - sourceFile: URL of the encrypted file
        ///   - recipientKeys: KeyPair of the recipient who is trying to decrypt the file
        /// - Throws: MiniLock.Errors if sourceFile is invalid
        public init(sourceFile: URL, recipientKeys: KeyPair) throws {
            guard sourceFile.isFileURL else {
                throw Errors.notAFileURL
            }
            
            guard !sourceFile.lastPathComponent.isEmpty else {
                throw Errors.fileNameEmpty
            }
            
            self.sourceFile = sourceFile
            self.recipientKeys = recipientKeys
            
            self.fileSize = Double((try FileManager.default.attributesOfItem(atPath: self.sourceFile.path))[FileAttributeKey.size] as! UInt64)
        }
        
        /// Decrypts the source file _in-memory_ and returns the plain text data.
        ///
        /// ## Note
        /// You may either call this method or decrypt(destinationDirectory: filename: deleteSourceFile:) per object instance but not both.
        /// The method is not thread-safe.
        ///
        /// - Parameter deleteSourceFile: Bool value indicating if the source file should be deleted after a successful operation.
        /// - Returns: Decrypted file data
        public func decrypt(deleteSourceFile: Bool) throws -> Data {
            // sanity check
            guard processStatus == .incomplete else {
                throw Errors.processAlreadyComplete
            }

            let decryptor = try getBlockDecryptor()

            // open the source file for reading
            let sourceHandle = try FileHandle(forReadingFrom: sourceFile)
            defer {
                sourceHandle.closeFile()
            }
            
            sourceHandle.seek(toFileOffset: headerOffsetInSourceFile)
            
            // since this is an in-memory decryption, we don't care about the filename in the first block
            let firstBlock = try readNextBlock(fromFileHandle: sourceHandle)
            let _ = try decryptor.decrypt(cipherBlock: firstBlock, isLastBlock: false)
            
            // read and decrypt the blocks that follow
            var currentBlock = try readNextBlock(fromFileHandle: sourceHandle)
            if currentBlock.isEmpty {
                throw Errors.corruptMiniLockFile
            }

            var decryptedData = Data()
            
            while !currentBlock.isEmpty {
                try autoreleasepool {
                    // read the next block
                    let nextBlock = try readNextBlock(fromFileHandle: sourceHandle)
                    
                    // decrypt the current block
                    let decryptedBlock = try decryptor.decrypt(cipherBlock: currentBlock, isLastBlock: nextBlock.isEmpty)

                    // append to the in-memory object
                    decryptedData.append(decryptedBlock)

                    // update the byte count
                    bytesDecrypted += currentBlock.count
                    currentBlock = nextBlock
                }
            }
            
            sourceHandle.closeFile()
            
            // delete the source file if requested
            if deleteSourceFile {
                do {
                    try FileManager.default.removeItem(at: sourceFile)
                } catch (let error) {
                    print("Error deleting the source file: ", error)
                }
            }
            
            return decryptedData
        }
        
        /// Decrypts the source file's header, extracts the symmetric encryption key and nonce from it
        ///
        /// - Returns:  Returns a StreamDecryptor object initialized with the values in the header
        /// - Throws: If the file header is corrupt or if 'recipientKeys' cannot decrypt the header
        private func getBlockDecryptor() throws -> StreamDecryptor {
            // open the source file for reading the header
            let sourceHandle = try FileHandle(forReadingFrom: sourceFile)
            defer {
                sourceHandle.closeFile()
            }
            
            // verify magic bytes
            let sourceMagicBytes = [UInt8](sourceHandle.readData(ofLength: FileFormat.MagicBytes.count))
            
            guard sourceMagicBytes == FileFormat.MagicBytes else {
                throw Errors.corruptMiniLockFile
            }
            
            // read header length
            let headerSizeBytes = sourceHandle.readData(ofLength: FileFormat.HeaderBytesLength)
            guard headerSizeBytes.count == FileFormat.HeaderBytesLength else {
                throw Errors.corruptMiniLockFile
            }
            
            var headerLength = 0
            
            for i in 0..<headerSizeBytes.count {
                headerLength |= Int(headerSizeBytes[i]) << (8 * i)
            }
            
            // read the header
            var headerBytes = [UInt8](sourceHandle.readData(ofLength: headerLength))
            guard headerBytes.count == headerLength,
                let headerString = String(bytes: headerBytes, encoding: .utf8) else {
                    throw Errors.corruptMiniLockFile
            }
            
            // free up memory
            headerBytes.removeAll(keepingCapacity: false)
            
            // get fileInfo and decryptInfo from the header
            guard let header = try? Header(JSONString: headerString) else {
                throw Errors.corruptMiniLockFile
            }
            
            guard let decryptInfo = header.decryptDecryptInfo(usingRecipientKeys: recipientKeys),
                let fileInfo = decryptInfo.decryptFileInfo(usingRecipientKeys: recipientKeys) else {
                    throw Errors.notARecipient
            }
            
            guard let fileKey = Data(base64Encoded: fileInfo.key),
                let fileNonce = Data(base64Encoded: fileInfo.nonce) else {
                    throw Errors.corruptMiniLockFile
            }
            
            self._sender = decryptInfo.senderId
            
            // set the 'headerOffsetInSourceFile' var to let the decrypt method know where to start reading blocks from
            self.headerOffsetInSourceFile = sourceHandle.offsetInFile

            return try StreamDecryptor(key: [UInt8](fileKey), fileNonce: [UInt8](fileNonce))
        }

        /// Decrypts the source file, saving the plain text data to a destination file.
        ///
        /// ## Note
        /// You may either call this method or decrypt(deleteSourceFile: Bool) per object instance but not both.
        /// The method is not thread-safe.
        ///
        /// - Parameters:
        ///   - destinationDirectory: URL of the parent directory of the destination file.
        ///   - suggestedFilename: Preferred filename of the destination file. This may not be the one that is finally used since a file with the same name may already exist, in which case a different name is used _based_ on this name. If nil is provided, the filename embedded inside the encrypted file is used.
        ///   - deleteSourceFile: Boolean value indicating if the source file should be deleted after a successful operation.
        /// - Returns: URL of the file in which the plain text was finally put.
        public func decrypt(destinationDirectory: URL, filename suggestedFilename: String?, deleteSourceFile: Bool) throws -> URL {
            guard processStatus == .incomplete else {
                throw Errors.processAlreadyComplete
            }
            
            let decryptor = try getBlockDecryptor()
            
            // open the source file for reading
            let sourceHandle = try FileHandle(forReadingFrom: sourceFile)
            defer {
                sourceHandle.closeFile()
            }
            
            // seek to the offset past the file header
            sourceHandle.seek(toFileOffset: headerOffsetInSourceFile)

            // read and decrypt the first block
            let firstBlock = try readNextBlock(fromFileHandle: sourceHandle)
            let decryptedFirstBlock = try decryptor.decrypt(cipherBlock: firstBlock, isLastBlock: false)
            
            var basename: String
            
            if suggestedFilename == nil || suggestedFilename!.isEmpty {
                // if the file name is left for us to decide, decode the filename from the first block
                guard let embeddedFilename = decryptedFirstBlock.withUnsafeBytes({ return String(cString: $0, encoding: .utf8) }) else {
                    throw Errors.couldNotDecodeFileName
                }
                
                basename = embeddedFilename
            } else {
                basename = suggestedFilename!
            }
            
            // create the destination file and open it for writing
            let destinationFile = try GlobalUtils.createNewFile(inDirectory: destinationDirectory, withName: basename)

            let destinationHandle = try FileHandle(forWritingTo: destinationFile)
            
            var decryptedSuccessfully = false

            defer {
                destinationHandle.closeFile()
                
                // delete destination if decryption failed
                if !decryptedSuccessfully {
                    do {
                        try FileManager.default.removeItem(at: destinationFile)
                    } catch {
                        print("Error deleting incomplete file:", error)
                    }
                }
            }
            
            var currentBlock = try readNextBlock(fromFileHandle: sourceHandle)
            if currentBlock.isEmpty {
                throw Errors.corruptMiniLockFile
            }
            
            // read all blocks sequentially, decrypt them and write the decrypted blocks to destinationHandle
            while !currentBlock.isEmpty {
                try autoreleasepool {
                    // read the next block
                    let nextBlock = try readNextBlock(fromFileHandle: sourceHandle)
                    
                    // decrypt the current block
                    let decryptedBlock = try decryptor.decrypt(cipherBlock: currentBlock, isLastBlock: nextBlock.isEmpty)
                    
                    // write the decrypted block to the destination URL
                    destinationHandle.write(decryptedBlock)
                    
                    // update the byte count
                    bytesDecrypted += currentBlock.count
                    currentBlock = nextBlock
                }
            }
            
            decryptedSuccessfully = true

            // delete the source file if that was requested
            if deleteSourceFile {
                do {
                    try FileManager.default.removeItem(at: sourceFile)
                } catch (let error) {
                    print("Error deleting the source file: ", error)
                }
            }
            
            return destinationFile
        }
        
        /// Reads the next block from 'fileHandle', verifies it and then returns it
        ///
        /// - Parameter fileHandle: The FileHandle object to read the data from
        /// - Returns: A Data object containing the next block in the file, including 
        ///             the header bytes that indicate its size in the front and the 
        ///             MAC bytes in the end. An empty Data object is returned if no 
        ///             data is left to read from the FileHandle.
        /// - Throws: Throws if an invalid file is encountered
        private func readNextBlock(fromFileHandle fileHandle: FileHandle) throws -> Data {
            // read block length bytes
            let blockLengthBytes = fileHandle.readData(ofLength: FileFormat.BlockSizeTagLength)
            
            // no data left in the file
            if blockLengthBytes.count == 0 {
                return  Data()
            }

            guard blockLengthBytes.count == FileFormat.BlockSizeTagLength else {
                throw Errors.corruptMiniLockFile
            }
            
            // calculate block length from the bytes just read
            var blockLength = 0
            
            for i in 0..<FileFormat.BlockSizeTagLength {
                blockLength |= Int(blockLengthBytes[i]) << (8 * i)
            }
            
            // make sure it is a valid size
            guard blockLength <= FileFormat.PlainTextBlockMaxBytes else {
                throw Errors.corruptMiniLockFile
            }
            
            // Also gotta read the MAC bytes
            blockLength += CryptoSecretBoxSizes.MAC
            
            let block = fileHandle.readData(ofLength: blockLength)
            
            guard block.count == blockLength else {
                throw Errors.corruptMiniLockFile
            }
            
            return blockLengthBytes + block
        }
    }
}
