//
//  FileFormat.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 26/03/17.
//
//

import Foundation
import libsodium

extension MiniLock {
    /// Contains the constants used in miniLock's file format.
    public struct FileFormat {
        static let Version = 1
        static let PlainTextBlockMaxBytes = 1048576
        static let FileNonceBytes = 16
        static let BlockSizeTagLength = 4
        
        static let FileNameMaxLength = 255
        
        static let MagicBytes: [UInt8] = [0x6d, 0x69, 0x6e, 0x69, 0x4c, 0x6f, 0x63, 0x6b]
        static let HeaderBytesLength = 4
        
        static let FileExtension = "miniLock"
    }
}
