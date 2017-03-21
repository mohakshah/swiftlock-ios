//
//  Base58.swift
//  SwiftLock
//
//  Created by Mohak Shah on 19/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import libbase58


/// A wrapper class for libbase58

class Base58
{
    static func encode(bytes: [UInt8]) -> String? {
        var b58String: String? = nil

        // create and initialize a CChar array
        let approximateStringSize = bytes.count * 138 / 100 + 2
        let b58CharArray = UnsafeMutablePointer<CChar>.allocate(capacity: approximateStringSize)
        b58CharArray.initialize(to: 0, count: approximateStringSize)

        // this pointer will be used to update the final size of the char array
        let finalStringSize = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        finalStringSize.initialize(to: approximateStringSize, count: 1)
        
        let encodingWasSuccessful = b58enc(b58CharArray,
                                            finalStringSize,
                                            UnsafeRawPointer(bytes),
                                            bytes.count)
        
        if encodingWasSuccessful {
            b58String = String(cString: b58CharArray)
        }
        
        
        // free up the memory
        finalStringSize.deinitialize(count: 1)
        finalStringSize.deallocate(capacity: 1)
        b58CharArray.deinitialize(count: approximateStringSize)
        b58CharArray.deallocate(capacity: approximateStringSize)

        return b58String
    }
    
    static func decode(_ base58String: String) -> [UInt8]? {
        let cStringLength = base58String.lengthOfBytes(using: .utf8)

        guard cStringLength > 0,
            let cString = base58String.cString(using: .utf8) else {
                return nil
        }

        var binaryArray: [UInt8]? = nil
        
        // allocate memory for the binary data
        let initialBinarySize = cStringLength
        let binary = UnsafeMutablePointer<UInt8>.allocate(capacity: initialBinarySize)
        binary.initialize(to: 0, count: initialBinarySize)
        
        let finalSizePointer = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        finalSizePointer.initialize(to: initialBinarySize, count: 1)

        let decodingWasSuccessful = b58tobin(binary,
                                             finalSizePointer,
                                             UnsafePointer<Int8>(cString),
                                             cStringLength)
        
        let finalSize = finalSizePointer[0]

        if decodingWasSuccessful && finalSize <= initialBinarySize {
            // the output is right aligned, for some odd reason
            binaryArray = [UInt8](UnsafeBufferPointer<UInt8>(start: binary + initialBinarySize - finalSize, count: finalSize))
        }
        
        // free up the memory
        binary.deinitialize(count: cString.count)
        binary.deallocate(capacity: cString.count)
        finalSizePointer.deinitialize(count: 1)
        finalSizePointer.deallocate(capacity: 1)

        return binaryArray
    }
}
