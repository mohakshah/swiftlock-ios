//
//  Base58.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 19/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import libbase58


/// A wrapper class for libbase58

public class Base58
{
    // Disable instantiation
    private init() {}
    
    public static func encode(bytes: [UInt8]) -> String {
        if bytes.isEmpty {
            return ""
        }

        var overEstimatedCStringSize = bytes.count * 138 / 100 + 2
        let b58CString = [CChar](repeating: 0, count: overEstimatedCStringSize)
        
        // no need to check for return value with a string size this large
        _ = withUnsafeMutablePointer(to: &overEstimatedCStringSize) { (sizePtr) -> Bool in
            return b58enc(UnsafeMutablePointer(mutating: b58CString),
                          sizePtr,
                          bytes,
                          bytes.count)
        }
        
        return String(cString: b58CString)
    }
    
    public static func decode(_ base58String: String) -> [UInt8]? {
        let cStringLength = base58String.lengthOfBytes(using: .utf8)

        guard cStringLength > 0,
            let cString = base58String.cString(using: .utf8) else {
                return nil
        }

        // allocate memory for the binary data
        var binarySize = cStringLength
        let binary = [UInt8](repeating: 0, count: binarySize)

        let decodingWasSuccessful = withUnsafeMutablePointer(to: &binarySize) { (sizePtr) -> Bool in
                    b58tobin(UnsafeMutablePointer(mutating: binary),
                            sizePtr,
                            UnsafePointer<Int8>(cString),
                            cStringLength)
        }

        if decodingWasSuccessful {
            // the output is right aligned, for some odd reason
            return [UInt8](binary[binary.count - binarySize..<binary.count])
        } else {
            return nil
        }
    }
}
