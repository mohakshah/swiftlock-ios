//
//  Ed25519KeyPair.swift
//  SwiftLock
//
//  Created by Mohak Shah on 19/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import libsodium
import libb2s

fileprivate struct LocalConstants {
    static let PublicKeyChecksumSize = 1
    static let PublicKeySize = Int(crypto_box_PUBLICKEYBYTES)
    static let PrivateKeySize = Int(crypto_box_SECRETKEYBYTES)
}

struct Ed25519KeyPair
{
    let privateKey, publicKey: [UInt8]
    let printablePublicKey: String
    
    init?(fromPrivateKey privateKey: [UInt8]) {
        if privateKey.count != LocalConstants.PrivateKeySize {
            print("Invalid private key length")
            return nil
        }
        
        // derive the public key from the private key
        let publicKey = UnsafeMutablePointer<UInt8>.allocate(capacity: LocalConstants.PublicKeySize + LocalConstants.PublicKeyChecksumSize)
        crypto_scalarmult_base(publicKey, privateKey)
        
        // append the checksum to the public key
        blake2s(publicKey.advanced(by: LocalConstants.PublicKeySize),
                publicKey,
                nil,
                LocalConstants.PublicKeyChecksumSize,
                LocalConstants.PublicKeySize,
                0)
        
        self.publicKey = Array<UInt8>(UnsafeBufferPointer(start: publicKey, count: LocalConstants.PublicKeySize + LocalConstants.PublicKeyChecksumSize))
        self.privateKey = privateKey
        
        guard let base58Representation = Base58.encode(bytes: self.publicKey) else {
            print("Could not encode the public key to base58!!!")
            return nil
        }
        
        self.printablePublicKey = base58Representation
    }
}
