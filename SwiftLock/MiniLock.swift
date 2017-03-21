//
//  MiniLock.swift
//  SwiftLock
//
//  Created by Mohak Shah on 19/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import libsodium
import libb2s

class MiniLock
{
    fileprivate struct LocalConstants {
        static let Blake2sOutputLength = 32
        struct ScryptParameters {
            static let N: UInt64 = UInt64(pow(2.0, 17.0))
            static let R: UInt32 = 8
            static let P: UInt32 = 1
            static let OutputLength = 32
        }
    }

    static func deriveKeyPair(fromEmail email: String, andPassword password: String) -> Ed25519KeyPair? {
        // hash the password using blake2s
        let blake2sInput: [UInt8] = Array(password.utf8)
        let blake2sOutput = UnsafeMutablePointer<UInt8>.allocate(capacity: LocalConstants.Blake2sOutputLength)

        blake2s(blake2sOutput,
                blake2sInput,
                nil,
                LocalConstants.Blake2sOutputLength,
                blake2sInput.count,
                0)
        
        // hash the result of the previous hash using scrypt with the email as the salt
        let scryptSalt: [UInt8] = Array(email.utf8)
        let scryptOutput = UnsafeMutablePointer<UInt8>.allocate(capacity: LocalConstants.ScryptParameters.OutputLength)
        let ret = crypto_pwhash_scryptsalsa208sha256_ll(blake2sOutput,
                                              LocalConstants.Blake2sOutputLength,
                                              scryptSalt,
                                              scryptSalt.count,
                                              LocalConstants.ScryptParameters.N,
                                              LocalConstants.ScryptParameters.R,
                                              LocalConstants.ScryptParameters.P,
                                              scryptOutput,
                                              LocalConstants.ScryptParameters.OutputLength)
        
        if ret != 0 {
            print("Error while applying the scrypt algorithm")
            return nil
        }

        // create a [UInt8] from scrypt's output and use it to generate a keypair
        let privateKey: [UInt8] = Array(UnsafeBufferPointer(start: scryptOutput,
                                                            count: LocalConstants.ScryptParameters.OutputLength))
        return Ed25519KeyPair(fromPrivateKey: privateKey)
    }
    
}
