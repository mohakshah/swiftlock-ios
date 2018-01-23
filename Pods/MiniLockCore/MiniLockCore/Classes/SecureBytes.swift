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
/// ## Note: 
/// The memory is zeroed and freed when the object is deinitialized.
/// Since this is a class, care must be taken to ensure no dangling references to an object remain.
public class SecureBytes
{
    /// Length of the bytes stores
    public let length: Int

    /// Array of bytes stored
    public let bytes: UnsafeMutablePointer<UInt8>
    
    /// Returns a SecureBytes object initialized with an array of bytes of size
    /// 'length' allocated using sodium_malloc
    ///
    /// - Parameters:
    ///   - length: size of the array
    /// - Returns: nil if allocation failed for some reason (e.g. Low memory)
    public init?(ofLength length: Int) {
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
