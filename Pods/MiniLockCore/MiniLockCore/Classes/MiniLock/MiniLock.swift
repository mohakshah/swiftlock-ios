//
//  MiniLock.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 19/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import libsodium
import libb2s

public class MiniLock
{
    public enum Errors: Error, CustomStringConvertible {
        case recepientListEmpty
        case notAFileURL
        case fileNameEmpty
        case couldNotCreateFile
        case sourceFileEmpty
        case couldNotConstructHeader
        case notAMiniLockFile
        case corruptMiniLockFile
        case notARecipient
        case couldNotDecodeFileName
        case headerParsingError
        case processAlreadyComplete
        
        
        public var description: String {
            switch self {
            case .corruptMiniLockFile:
                return "The file is corrupt."
                
            case .couldNotConstructHeader:
                return "There was an error creating the header."
                
            case .couldNotCreateFile:
                return "There was an error creating a new file."
                
            case .couldNotDecodeFileName:
                return "The filename embedded in the encrypted file is corrupt."
                
            case .fileNameEmpty:
                return "Input filename was empty."
                
            case .headerParsingError:
                return "File header is corrupt."
                
            case .notAFileURL:
                return "URL provided does not point to a file."
                
            case .notAMiniLockFile:
                return "The file is not a miniLock encrypted file."
                
            case .processAlreadyComplete:
                return "The encryption/decryption process is already complete."
                
            case .recepientListEmpty:
                return "No recipients selected."
                
            case .sourceFileEmpty:
                return "The file you selected was empty."
                
            case .notARecipient:
                return "You are not a recipient."
            }
        }
    }
    
    public enum ProcessStatus {
        case incomplete, succeeded, failed
    }

    public class func isEncryptedFile(url: URL) throws -> Bool {
        guard url.isFileURL else {
            throw Errors.notAFileURL
        }
        
        // read magic bytes from the file
        let readHandle = try FileHandle(forReadingFrom: url)
        let fileBytes = [UInt8](readHandle.readData(ofLength: FileFormat.MagicBytes.count))

        readHandle.closeFile()
        
        // compare to minilock's magic bytes
        if fileBytes == FileFormat.MagicBytes {
            return true
        }
        
        return false
    }
}

public protocol MiniLockProcessDelegate: class {
    
    /// Implement this function to get updates on a MiniLock process
    /// such as file encryption/decryption
    ///
    /// - Parameters:
    ///   - progress: values in the range [0.0, 1.0]
    ///   - process: the process calling the funcion
    func setProgress(to progress: Double, process: MiniLockProcess)
}

public protocol MiniLockProcess {
    var processDelegate: MiniLockProcessDelegate? { get set }
}
