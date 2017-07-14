
//
//  FileEncryptor.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 30/03/17.
//
//

import Foundation
import libsodium

extension MiniLock {
    public final class FileEncryptor: MiniLockProcess {

        private let sourceFile: URL
        private let sender: MiniLock.KeyPair
        private let recipients: [MiniLock.Id]
        
        private let paddedFileName: Data
        private let fileSize: Double
        
        private var bytesEncrypted: Int = 0 {
            didSet {
                processDelegate?.setProgress(to: Double(bytesEncrypted) / fileSize, process: self)
            }
        }
        
        /// A delegate to monitor the progresss of the process
        public weak var processDelegate: MiniLockProcessDelegate?

        /// Returns a FileEncryptor object that will encrypt the source file
        ///
        /// - Parameters:
        ///   - url: URL of the source file to encrypt
        ///   - sender: KeyPair of the sender
        ///   - recipients: Array of recipient Ids
        /// - Throws: If 'url' is invalid or if 'recipients' is empty
        public init(fileURL url: URL, sender: MiniLock.KeyPair, recipients: [MiniLock.Id]) throws {
            guard url.isFileURL else {
                throw Errors.notAFileURL
            }
            
            guard !url.lastPathComponent.isEmpty else {
                throw Errors.fileNameEmpty
            }

            self.sourceFile = url
            self.sender = sender

            if recipients.isEmpty {
                throw Errors.recepientListEmpty
            }

            self.recipients = recipients
            
            self.paddedFileName = FileEncryptor.paddedFileName(fromFileURL: url)
            
            self.fileSize = Double((try FileManager.default.attributesOfItem(atPath: self.sourceFile.path))[FileAttributeKey.size] as! UInt64)
        }
        
        /// Encrypts the source file.
        ///
        /// ## Note
        /// You may call only one of the multiple encrypt(..) methods per object instance.  The method is not thread-safe.
        ///
        /// - Parameters:
        ///   - destination: URL of the destination file
        ///   - deleteSourceFile: A Bool value indicating if the source file should be deleted after it is successfull encrypted
        public func encrypt(destinationFileURL destination: URL, deleteSourceFile: Bool) throws {
            _ = try self.encrypt(destinationDirectory: destination.deletingLastPathComponent(),
                                 filename: destination.lastPathComponent,
                                 deleteSourceFile: deleteSourceFile)
        }
        
        /// Encrypts the source file.
        ///
        /// ## Note
        /// You may call only one of the multiple encrypt(..) methods per object instance.  The method is not thread-safe.
        ///
        /// - Parameters:
        ///   - destinationDirectory: URL of the parent directory of the destination file
        ///   - suggestedFilename: The filename of the destination file. If nil is provided, a filename will be created from the source file's name.
        ///   - deleteSourceFile: A Bool value indicating if the source file should be deleted after it is successfull encrypted
        /// - Returns: The URL of the destination file
        public func encrypt(destinationDirectory: URL, filename suggestedFilename: String?, deleteSourceFile: Bool) throws -> URL {
            // create destination file
            let filename = suggestedFilename ?? sourceFile.appendingPathExtension(MiniLock.FileFormat.FileExtension).lastPathComponent
            let destination = try GlobalUtils.createNewFile(inDirectory: destinationDirectory, withName: filename)
            let fileManager = FileManager.default

            // open destination file for writing
            var createdSuccessfully = fileManager.createFile(atPath: destination.path, contents: nil, attributes: nil)
            if !createdSuccessfully {
                throw Errors.couldNotCreateFile
            }
            
            let destinationHandle = try FileHandle(forWritingTo: destination)
            
            var encryptedSuccessfully = false

            defer {
                destinationHandle.closeFile()
                if !encryptedSuccessfully {
                    do {
                        try fileManager.removeItem(at: destination)
                    } catch (let error) {
                        print("Error deleting the destination: ", error)
                    }
                }
            }

            // open the source file for reading
            let sourceHandle = try FileHandle(forReadingFrom: sourceFile)
            defer {
                sourceHandle.closeFile()
                if deleteSourceFile && fileManager.fileExists(atPath: sourceFile.absoluteString) {
                    do {
                        try fileManager.removeItem(at: sourceFile)
                    } catch (let error) {
                        print("Error deleting the source file: ", error)
                    }
                }
            }
            
            // get a file descriptor and path to a temp file
            let (payloadFD, payloadPath) = GlobalUtils.createUniqueFile(withExtension: nil, in: nil)
            if payloadFD == -1 {
                throw Errors.couldNotCreateFile
            }
            
            let payloadHandle = FileHandle(fileDescriptor: payloadFD, closeOnDealloc: true)

            defer {
                // close and delete payload file
                payloadHandle.closeFile()
                
                // create url object from payloadPath
                if let url = URL(string: "file://" + String(cString: payloadPath)) {
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch (let error) {
                        print("Error deleting the temp payload file: ", error)
                    }
                } else {
                    print("Could not create URL object from payloadPath:", "file://" + String(cString: payloadPath))
                }
            }
            
            // Initialize a StreamEncryptor object. It will automatically use a random file key and nonce
            let encryptor = StreamEncryptor()
            
            // Encrypt the filename block and write it to the payload
            let encryptedBlock = try encryptor.encrypt(messageBlock: paddedFileName, isLastBlock: false)
            payloadHandle.write(encryptedBlock)

            // read the first plain text block
            var currentBlock = sourceHandle.readData(ofLength: MiniLock.FileFormat.PlainTextBlockMaxBytes)
            if currentBlock.isEmpty {
                throw Errors.sourceFileEmpty
            }
            
            while !currentBlock.isEmpty {
                try autoreleasepool {
                    // read next block
                    let nextBlock = sourceHandle.readData(ofLength: MiniLock.FileFormat.PlainTextBlockMaxBytes)
                    
                    // encrypt current block
                    let encryptedBlock = try encryptor.encrypt(messageBlock: currentBlock, isLastBlock: nextBlock.isEmpty)

                    // append current block to the payload
                    payloadHandle.write(encryptedBlock)
                    
                    // increment the byte count
                    bytesEncrypted += currentBlock.count
                    
                    currentBlock = nextBlock
                }
            }
            
            sourceHandle.closeFile()
            
            // delete source file if requested
            if deleteSourceFile {
                do {
                    try fileManager.removeItem(at: sourceFile)
                } catch (let error) {
                    print("Error deleting the source file: ", error)
                }
            }

            // seek to the beginning of payloadHandle
            payloadHandle.seek(toFileOffset: UInt64(0))
            
            // write magic bytes to destination
            destinationHandle.write(Data(MiniLock.FileFormat.MagicBytes))
            
            // create header
            let header = Header(sender: sender,
                                recipients: recipients,
                                fileInfo: Header.FileInfo(key: encryptor.key, nonce: encryptor.fileNonce, hash: encryptor.cipherTextHash))
            
            guard let headerData = header?.toJSONStringWithoutEscapes()?.data(using: .utf8) else {
                throw Errors.couldNotConstructHeader
            }

            let headerSize = headerData.count

            // calculate little-endian bytes representing the header size and write those bytes to destination
            var headerSizeBytes = Data()
            for i in 0..<FileFormat.HeaderBytesLength {
                let byte = UInt8((headerSize >> (8 * i)) & 0xff)
                headerSizeBytes.append(byte)
            }
            
            destinationHandle.write(headerSizeBytes)

            // write the header to destination
            destinationHandle.write(headerData)
            
            // copy over the payloadHandle to destination
            currentBlock = payloadHandle.readData(ofLength: MiniLock.FileFormat.PlainTextBlockMaxBytes)
            
            while !currentBlock.isEmpty {
                autoreleasepool {
                    destinationHandle.write(currentBlock)
                    currentBlock = payloadHandle.readData(ofLength: MiniLock.FileFormat.PlainTextBlockMaxBytes)
                }
            }
            
            encryptedSuccessfully = true
            
            return destination
        }
        
        class func paddedFileName(fromFileURL url: URL) -> Data {
            var filename = [UInt8](url.lastPathComponent.utf8)
            
            if filename.count > FileFormat.FileNameMaxLength {
                // keep just the first FileFormat.FileNameMaxLength bytes
                filename.removeLast(filename.count - FileFormat.FileNameMaxLength)
            }

            // pad to fit FileFormat.FileNameMaxLength bytes
            filename += [UInt8](repeating: 0, count: FileFormat.FileNameMaxLength - filename.count + 1)
            
            return Data(filename)
        }
    }
}

extension MiniLock.FileEncryptor {
    /// Encrypts a Data object and saves to a file.
    /// Use this class method in situations where plain text data must not be written to disk.
    ///
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - destination: URL of the destination file
    ///   - sender: KeyPair of the sender
    ///   - recipients: array of recipient ids
    public class func encrypt(_ data: Data, destinationFileURL destination: URL, sender: MiniLock.KeyPair, recipients: [MiniLock.Id]) throws {
        guard !recipients.isEmpty, !data.isEmpty else {
            throw MiniLock.Errors.recepientListEmpty
        }

        let fileManager = FileManager.default
        
        // open destination file for writing
        var createdSuccessfully = fileManager.createFile(atPath: destination.path, contents: nil, attributes: nil)
        if !createdSuccessfully {
            throw MiniLock.Errors.couldNotCreateFile
        }
        
        let destinationHandle = try FileHandle(forWritingTo: destination)
        
        var encryptedSuccessfully = false

        defer {
            destinationHandle.closeFile()
            if !encryptedSuccessfully {
                do {
                    try fileManager.removeItem(at: destination)
                } catch (let error) {
                    print("Error deleting the destination: ", error)
                }
            }
        }
        
        // get a file descriptor and path to a temp file
        let (payloadFD, payloadPath) = GlobalUtils.createUniqueFile(withExtension: nil, in: nil)
        if payloadFD == -1 {
            throw MiniLock.Errors.couldNotCreateFile
        }
        
        let payloadHandle = FileHandle(fileDescriptor: payloadFD, closeOnDealloc: true)
        
        defer {
            // close and delete payload file
            payloadHandle.closeFile()

            // create url object from payloadPath
            if let url = URL(string: "file://" + String(cString: payloadPath)) {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch (let error) {
                    print("Error deleting the temp payload file: ", error)
                }
            } else {
                print("Could not create URL object from payloadPath:", "file://" + String(cString: payloadPath))
            }
        }
        
        // Initialize a StreamEncryptor object. It will automatically use a random file key and nonce
        let encryptor = MiniLock.StreamEncryptor()
        
        // Use an empty filename for the first block
        let paddedFileName = Data(repeating: 0, count: MiniLock.FileFormat.FileNameMaxLength + 1)
        let encryptedBlock = try encryptor.encrypt(messageBlock: paddedFileName, isLastBlock: false)
        
        payloadHandle.write(encryptedBlock)
        
        // calculate the total blocks (max size MiniLock.FileFormat.PlainTextBlockMaxBytes) that will be written
        let totalDataBlocks = (data.count / MiniLock.FileFormat.PlainTextBlockMaxBytes)
            + (data.count % MiniLock.FileFormat.PlainTextBlockMaxBytes > 0 ? 1 : 0)
        
        // blockStart and blockEnd point to the position of the current block in input data
        var blockStart = 0
        var blockEnd = MiniLock.FileFormat.PlainTextBlockMaxBytes
        for _ in 0..<totalDataBlocks {
            // in case the size of the last block is < MiniLock.FileFormat.PlainTextBlockMaxBytes
            if blockEnd > data.count {
                blockEnd = data.count
            }
            
            // encrypt the current block and write it to the payload file
            let encryptedBlock = try encryptor.encrypt(messageBlock: data.subdata(in: blockStart..<blockEnd),
                                                       isLastBlock: blockEnd == data.count)
            payloadHandle.write(encryptedBlock)
            
            // increment the start and end pointers
            blockStart += MiniLock.FileFormat.PlainTextBlockMaxBytes
            blockEnd += MiniLock.FileFormat.PlainTextBlockMaxBytes
        }
        
        // seek to the beginning of payloadHandle
        payloadHandle.seek(toFileOffset: 0)
        
        // write magic bytes to destination
        destinationHandle.write(Data(MiniLock.FileFormat.MagicBytes))
        
        // create header
        let header = MiniLock.Header(sender: sender,
                                     recipients: recipients,
                                     fileInfo: MiniLock.Header.FileInfo(key: encryptor.key, nonce: encryptor.fileNonce, hash: encryptor.cipherTextHash))
        
        guard let headerData = header?.toJSONStringWithoutEscapes()?.data(using: .utf8) else {
            throw MiniLock.Errors.couldNotConstructHeader
        }
        
        let headerSize = headerData.count
        
        // calculate little-endian bytes representing the header size and write those bytes to destination
        var headerSizeBytes = Data()
        for i in 0..<MiniLock.FileFormat.HeaderBytesLength {
            let byte = UInt8((headerSize >> (8 * i)) & 0xff)
            headerSizeBytes.append(byte)
        }

        destinationHandle.write(headerSizeBytes)

        // write the header to destination
        destinationHandle.write(headerData)
        
        // copy over the payloadHandle to destination
        var currentBlock = payloadHandle.readData(ofLength: MiniLock.FileFormat.PlainTextBlockMaxBytes)
        
        while !currentBlock.isEmpty {
            autoreleasepool {
                destinationHandle.write(currentBlock)
                currentBlock = payloadHandle.readData(ofLength: MiniLock.FileFormat.PlainTextBlockMaxBytes)
            }
        }

        encryptedSuccessfully = true
        
        return
    }
}
