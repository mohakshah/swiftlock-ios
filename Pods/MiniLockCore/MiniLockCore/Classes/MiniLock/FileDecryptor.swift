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
        public var processStatus: MiniLock.ProcessStatus {
            return _processStatus
        }
        private var _sender: MiniLock.Id?
        public var sender: MiniLock.Id! {
            return _sender
        }
        
        private var headerOffsetInSourceFile: UInt64 = 0

        public weak var processDelegate: MiniLockProcessDelegate?
        
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
        
        public func decrypt(deleteSourceFile: Bool) throws -> Data {
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
            
            // since this is an in-memory decryption, we don't care about the filename
            let firstBlock = try readNextBlock(fromFileHandle: sourceHandle)
            let _ = try decryptor.decrypt(cipherBlock: firstBlock, isLastBlock: false)
            
            var currentBlock = try readNextBlock(fromFileHandle: sourceHandle)
            if currentBlock.isEmpty {
                throw Errors.corruptMiniLockFile
            }
            
            var decryptedData = Data()
            
            while !currentBlock.isEmpty {
                try autoreleasepool {
                    let nextBlock = try readNextBlock(fromFileHandle: sourceHandle)
                    let decryptedBlock = try decryptor.decrypt(cipherBlock: currentBlock, isLastBlock: nextBlock.isEmpty)

                    decryptedData.append(decryptedBlock)

                    bytesDecrypted += currentBlock.count
                    currentBlock = nextBlock
                }
            }
            
            return decryptedData
        }
        
        private func getBlockDecryptor() throws -> StreamDecryptor {
            // open the source file for reading the header
            let sourceHandle = try FileHandle(forReadingFrom: sourceFile)
            defer {
                sourceHandle.closeFile()
            }
            
            // verify magic bytes
            let sourceMagicBytes = [UInt8](sourceHandle.readData(ofLength: FileFormat.MagicBytes.count))
            
            guard sourceMagicBytes == FileFormat.MagicBytes else {
                throw Errors.notAMiniLockFile
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
            self.headerOffsetInSourceFile = sourceHandle.offsetInFile

            return try StreamDecryptor(key: [UInt8](fileKey), fileNonce: [UInt8](fileNonce))
        }

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
            
            sourceHandle.seek(toFileOffset: headerOffsetInSourceFile)

            let firstBlock = try readNextBlock(fromFileHandle: sourceHandle)
            let decryptedFirstBlock = try decryptor.decrypt(cipherBlock: firstBlock, isLastBlock: false)
            
            var basename: String
            
            if suggestedFilename == nil || suggestedFilename!.isEmpty {
                guard let embeddedFilename = getFileName(fromBlock: decryptedFirstBlock) else {
                    throw Errors.couldNotDecodeFileName
                }
                
                basename = embeddedFilename
            } else {
                basename = suggestedFilename!
            }
            
            let destinationFile = try GlobalUtils.createNewFile(inDirectory: destinationDirectory, withName: basename)

            let destinationHandle = try FileHandle(forWritingTo: destinationFile)
            
            defer {
                destinationHandle.closeFile()
            }
            
            var currentBlock = try readNextBlock(fromFileHandle: sourceHandle)
            if currentBlock.isEmpty {
                throw Errors.corruptMiniLockFile
            }
            
            while !currentBlock.isEmpty {
                try autoreleasepool {
                    let nextBlock = try readNextBlock(fromFileHandle: sourceHandle)
                    let decryptedBlock = try decryptor.decrypt(cipherBlock: currentBlock, isLastBlock: nextBlock.isEmpty)
                    
                    destinationHandle.write(decryptedBlock)
                    
                    bytesDecrypted += currentBlock.count
                    currentBlock = nextBlock
                }
            }

            if deleteSourceFile {
                do {
                    try FileManager.default.removeItem(at: sourceFile)
                } catch (let error) {
                    print("Error deleting the source file: ", error)
                }
            }
            
            return destinationFile
        }
        
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
            
            var blockLength = 0
            
            for i in 0..<FileFormat.BlockSizeTagLength {
                blockLength |= Int(blockLengthBytes[i]) << (8 * i)
            }
            
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
        
        private func getFileName(fromBlock block: Data) -> String? {
            var i = block.count - 1
            
            while i >= 0 {
                if block[i] != 0 {
                    break
                }
                
                i -= 1
            }
            
            return String(bytes: block[0...i], encoding: .utf8)
        }
    }
}
