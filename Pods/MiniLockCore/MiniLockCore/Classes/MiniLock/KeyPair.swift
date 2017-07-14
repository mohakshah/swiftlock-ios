//
//  KeyPair.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 26/03/17.
//
//

import Foundation
import libsodium
import libb2s

extension MiniLock
{
    struct KeySizes {
        static let PublicKeyCheckSum = 1
        static let PublicKey = crypto_box_publickeybytes()
        static let PrivateKey = crypto_box_secretkeybytes()
    }
    
    /// A structure to hold a set of miniLock public and private keys.
    /// The public key is stored as a MiniLock.Id and the private key is stored using the SecureBytes class.
    public struct KeyPair
    {
        struct ScryptParameters {
            static let N: UInt64 = UInt64(pow(2.0, 17.0))
            static let R: UInt32 = 8
            static let P: UInt32 = 1
            static let OutputLength = KeySizes.PrivateKey
        }
        
        static let Blake2SOutputLength = 32
        
        public let privateKey: SecureBytes
        public let publicId: MiniLock.Id
        
        /// Returns a KeyPair object initialized from an existing private key
        ///
        /// - Returns: nil if privatekey length != KeySizes.PrivateKey
        public init?(fromPrivateKey privateKey: SecureBytes) {
            if privateKey.length != KeySizes.PrivateKey {
                return nil
            }
            
            // derive the public key from the private key
            let publicKey = [UInt8](repeating: 0, count: KeySizes.PublicKey)
            crypto_scalarmult_base(UnsafeMutablePointer(mutating: publicKey), privateKey.bytes)

            self.publicId = Id(fromBinaryPublicKey: publicKey)!
            self.privateKey = privateKey
        }
        
        /// Returns a KeyPair object initialized from a user's email id and password.
        ///
        /// - Returns: nil if scrypt algorithm fails
        public init?(fromEmail email: String, andPassword password: String) {
            // hash the password using blake2s
            let blake2sInput = [UInt8](password.utf8)
            guard let blake2sOutput = SecureBytes(ofLength: KeyPair.Blake2SOutputLength) else {
                return nil
            }
            
            blake2s(blake2sOutput.bytes,
                    blake2sInput,
                    nil,
                    blake2sOutput.length,
                    blake2sInput.count,
                    0)
            
            // zero out blake2sInput
            sodium_memzero(UnsafeMutablePointer(mutating: blake2sInput), blake2sInput.count)
            
            // hash the result of the previous hash using scrypt with the email as the salt
            let scryptSalt: [UInt8] = Array(email.utf8)
            guard let scryptOutput = SecureBytes(ofLength: ScryptParameters.OutputLength) else {
                return nil
            }

            let ret = crypto_pwhash_scryptsalsa208sha256_ll(blake2sOutput.bytes,
                                                            KeyPair.Blake2SOutputLength,
                                                            scryptSalt,
                                                            scryptSalt.count,
                                                            ScryptParameters.N,
                                                            ScryptParameters.R,
                                                            ScryptParameters.P,
                                                            scryptOutput.bytes,
                                                            ScryptParameters.OutputLength)
            
            guard ret == 0 else {
                return nil
            }
            
            self.init(fromPrivateKey: scryptOutput)
        }
    }
    
}
