//
//  SecureBytes.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 22/06/17.
//
//

import Foundation
import libsodium


/// A simple wrapper class to securely hold an array of bytes.
/// The bytes are allocated using sodium_malloc.
/// On deallocation, the memory holding the bytes is zeroed
/// by sodium_free before the bytes are freed.
///
/// Note: The memory be zeroed and freed only on deinitialization.
///       Since this is a class, any dangling reference to it will
///       prevent deinitialization.
public class SecureBytes {
    let length: Int
    let bytes: UnsafeMutablePointer<UInt8>
    
    /// Allocates an array of bytes of size 'length' using sodium_malloc
    ///
    /// - Parameters:
    ///   - length: size of the array
    /// - Returns: nil if allocation failed for some reason (e.g. Low memory)
    init?(ofLength length: Int) {
        self.length = length
        guard let bytesPointer = sodium_malloc(length) else {
            // Could not allocate memory
            return nil
        }

        bytes = UnsafeMutablePointer<UInt8>(OpaquePointer(bytesPointer))
    }
    
    deinit {
        sodium_free(bytes)
    }
}
