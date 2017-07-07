
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

        let sourceFile: URL
        let sender: MiniLock.KeyPair
        let recipients: [MiniLock.Id]
        
        let paddedFileName: Data
        let fileSize: Double
        
        var bytesEncrypted: Int = 0 {
            didSet {
                processDelegate?.setProgress(to: Double(bytesEncrypted) / fileSize, process: self)
            }
        }

        public weak var processDelegate: MiniLockProcessDelegate?

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
        
        public func encrypt(destinationFileURL destination: URL, deleteSourceFile: Bool) throws {
            _ = try self.encrypt(destinationDirectory: destination.deletingLastPathComponent(),
                         filename: destination.lastPathComponent,
                         deleteSourceFile: deleteSourceFile)
        }
        
        public func encrypt(destinationDirectory: URL, filename suggestedFilename: String?, deleteSourceFile: Bool) throws -> URL {
            // create destination file
            let filename = suggestedFilename ?? sourceFile.appendingPathExtension(MiniLock.FileFormat.FileExtension).lastPathComponent
            let destination = try GlobalUtils.createNewFile(inDirectory: destinationDirectory, withName: filename)
            
            var encryptedSuccessfully = false
            let fileManager = FileManager.default

            // open destination file for writing
            var createdSuccessfully = fileManager.createFile(atPath: destination.path, contents: nil, attributes: nil)
            if !createdSuccessfully {
                throw Errors.couldNotCreateFile
            }
            
            let destinationHandle = try FileHandle(forWritingTo: destination)
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
            
            // write symmetrically encrypted payload to payloadHandle
            let encryptor = StreamEncryptor()
            let encryptedBlock = try encryptor.encrypt(messageBlock: paddedFileName, isLastBlock: false)

            payloadHandle.write(encryptedBlock)

            var currentBlock = sourceHandle.readData(ofLength: MiniLock.FileFormat.PlainTextBlockMaxBytes)
            if currentBlock.isEmpty {
                throw Errors.sourceFileEmpty
            }
            
            while !currentBlock.isEmpty {
                try autoreleasepool {
                    let nextBlock = sourceHandle.readData(ofLength: MiniLock.FileFormat.PlainTextBlockMaxBytes)
                    let encryptedBlock = try encryptor.encrypt(messageBlock: currentBlock, isLastBlock: nextBlock.isEmpty)

                    payloadHandle.write(encryptedBlock)
                    
                    bytesEncrypted += currentBlock.count
                    
                    currentBlock = nextBlock
                }
            }
            
            sourceHandle.closeFile()
            
            // delete source file
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

            // write header length to destination
            let headerSize = headerData.count
            
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
    public class func encrypt(_ data: Data, destinationFileURL destination: URL, sender: MiniLock.KeyPair, recipients: [MiniLock.Id]) throws {
        guard !recipients.isEmpty, !data.isEmpty else {
            throw MiniLock.Errors.recepientListEmpty
        }
        
        var encryptedSuccessfully = false
        let fileManager = FileManager.default
        
        // open destination file for writing
        var createdSuccessfully = fileManager.createFile(atPath: destination.path, contents: nil, attributes: nil)
        if !createdSuccessfully {
            throw MiniLock.Errors.couldNotCreateFile
        }
        
        let destinationHandle = try FileHandle(forWritingTo: destination)
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
        
        // write symmetrically encrypted payload to payloadHandle
        let encryptor = MiniLock.StreamEncryptor()
        let paddedFileName = Data(repeating: 0, count: MiniLock.FileFormat.FileNameMaxLength + 1)
        let encryptedBlock = try encryptor.encrypt(messageBlock: paddedFileName, isLastBlock: false)
        
        payloadHandle.write(encryptedBlock)
        
        let totalDataBlocks = (data.count / MiniLock.FileFormat.PlainTextBlockMaxBytes)
            + (data.count % MiniLock.FileFormat.PlainTextBlockMaxBytes > 0 ? 1 : 0)
        
        var blockStart = 0
        var blockEnd = MiniLock.FileFormat.PlainTextBlockMaxBytes
        for _ in 0..<totalDataBlocks {
            if blockEnd > data.count {
                blockEnd = data.count
            }
            
            let encryptedBlock = try encryptor.encrypt(messageBlock: data.subdata(in: blockStart..<blockEnd),
                                                       isLastBlock: blockEnd == data.count)
            payloadHandle.write(encryptedBlock)
            
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
        
        // write header length to destination
        let headerSize = headerData.count
        
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
    }
}
