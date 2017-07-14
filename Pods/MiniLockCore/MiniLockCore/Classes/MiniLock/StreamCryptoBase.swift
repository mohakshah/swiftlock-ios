//
//  StreamCryptoBase.swift
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
    struct CryptoSecretBoxSizes {
        static let CipherTextPadding = crypto_secretbox_boxzerobytes()
        static let MessagePadding = crypto_secretbox_zerobytes()
        static let MAC = crypto_secretbox_macbytes()
        static let SecretKey = crypto_secretbox_keybytes()
        static let Nonce = crypto_secretbox_noncebytes()
    }

    /// A base class that contains the common entities of Encryptor and Decryptor classes
    /// It doesn't provide any functionalities.
    public class StreamCryptoBase {
        static let Blake2sOutputLength = 32
        
        enum CryptoError: Error {
            case processComplete
            case inputSizeInvalid
            case decryptionFailed
            case macVerificationFailed
        }
        
        var _processStatus: ProcessStatus = .incomplete

        /// Current status of the process
        public var processStatus: ProcessStatus {
            return _processStatus
        }
        
        var fullNonce: [UInt8]
        
        /// The nonce used for MAC of the encrypted blocks
        public var fileNonce: [UInt8] {
            return Array(fullNonce[0..<MiniLock.FileFormat.FileNonceBytes])
        }
        
        var blake2SStatePointer = UnsafeMutablePointer<blake2s_state>.allocate(capacity: 1)
        var _cipherTextHash = [UInt8](repeating: 0, count: StreamCryptoBase.Blake2sOutputLength)

        /// The blake2s hash of the cipher text. The value beomes available after the last block has been processed.
        public var cipherTextHash: [UInt8] {
            return _cipherTextHash
        }
        
        /// The symmetric key used to encrypt the file payload
        public let key: [UInt8]
        
        
        public init(key: [UInt8], fileNonce: [UInt8]) throws {
            // verify input data
            guard key.count == CryptoSecretBoxSizes.SecretKey,
                fileNonce.count == MiniLock.FileFormat.FileNonceBytes else {
                    throw CryptoError.inputSizeInvalid
            }
            
            self.key = key
            fullNonce = fileNonce + [UInt8](repeating: 0, count: CryptoSecretBoxSizes.Nonce - MiniLock.FileFormat.FileNonceBytes)
            
            // init blake2s stream hashing
            blake2s_init(blake2SStatePointer, StreamCryptoBase.Blake2sOutputLength)
        }
        
        deinit {
            blake2SStatePointer.deallocate(capacity: 1)
        }
        
        func incrementNonce() {
            for i in MiniLock.FileFormat.FileNonceBytes..<CryptoSecretBoxSizes.Nonce {
                fullNonce[i] = fullNonce[i] &+ 1
                
                // byte did not wrap around
                if fullNonce[i] != 0 {
                    break
                }
            }
        }
    }
}
