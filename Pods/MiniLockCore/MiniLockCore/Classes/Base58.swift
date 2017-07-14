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
    
    /// Encodes an array of bytes into a String of base58 characters
    ///
    /// - Parameter bytes: bytes to encode
    /// - Returns: A base58 String representation of the input bytes
    public static func encode(bytes: [UInt8]) -> String {
        if bytes.isEmpty {
            return ""
        }

        // The retured array will not be larger than this
        var overEstimatedCStringSize = bytes.count * 138 / 100 + 2
        let b58CString = [CChar](repeating: 0, count: overEstimatedCStringSize)
        
        withUnsafeMutablePointer(to: &overEstimatedCStringSize) { sizePtr -> Void in
            // no need to check for return value since size of 'b58CString' is quite large
            b58enc(UnsafeMutablePointer(mutating: b58CString),
                   sizePtr,
                   bytes,
                   bytes.count)
        }
        
        return String(cString: b58CString)
    }
    
    /// Decodes a base58 encoding string into an array of bytes
    ///
    /// - Parameter base58String: A base58 encoded string
    /// - Returns: Decoded array of bytes or nil if the input is invalid
    public static func decode(_ base58String: String) -> [UInt8]? {
        // create a c string
        let cString = [CChar](base58String.utf8CString)
        let cStringLength = cString.count - 1

        guard cStringLength > 0 else {
                return nil
        }

        // allocate (more than enough) memory for the binary data
        var binarySize = cStringLength
        let binary = [UInt8](repeating: 0, count: binarySize)

        // try decoding the c string
        let decodingWasSuccessful = withUnsafeMutablePointer(to: &binarySize) { (binarySizePtr: UnsafeMutablePointer<Int>) -> Bool in
            return b58tobin(UnsafeMutablePointer(mutating: binary),
                            binarySizePtr,
                            UnsafePointer<Int8>(cString),
                            cStringLength)
        }

        if decodingWasSuccessful {
            // the output is right aligned, for some odd reason
            let decodedDataRange = (binary.count - binarySize)..<binary.count
            return [UInt8](binary[decodedDataRange])
        } else {
            return nil
        }
    }
}
