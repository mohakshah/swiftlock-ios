//
//  StreamEncryptor.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 23/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import libsodium
import libb2s

extension MiniLock
{
    public final class StreamEncryptor: StreamCryptoBase
    {
        private let messagePadding = [UInt8](repeating: 0, count: CryptoSecretBoxSizes.MessagePadding)
        private var cipherBuffer = [UInt8](repeating: 0, count: CryptoSecretBoxSizes.CipherTextPadding
                                                                + MiniLock.FileFormat.BlockSizeTagLength
                                                                + MiniLock.FileFormat.PlainTextBlockMaxBytes
                                                                + CryptoSecretBoxSizes.MAC)

        /// Initialize with a random encryption key and nonce
        public convenience init() {
            // create a random fileKey
            let fileKey = [UInt8](repeating: 0, count: CryptoSecretBoxSizes.SecretKey)
            randombytes_buf(UnsafeMutableRawPointer(mutating: fileKey), CryptoSecretBoxSizes.SecretKey)

            // no need to throw since use has not provided any input
            try! self.init(key: fileKey)
        }

        /// Initialize with a provide encryption key and a random nonce
        ///
        /// - Parameter key: encryptionkey to use
        /// - Throws: throws if size of key is invalid
        public convenience init(key: [UInt8]) throws {
            // create a random file nonce
            let fileNonce = [UInt8](repeating: 0, count: MiniLock.FileFormat.FileNonceBytes)
            randombytes_buf(UnsafeMutableRawPointer(mutating: fileNonce), fileNonce.count)

            // throw in case "key" is improper
            try self.init(key: key, fileNonce: fileNonce)
        }

        /// Encrypts block with the key and nonce that the object was initalized with.
        /// The cipher text is preceded by block length tag and followed by the MAC
        ///
        /// - Parameters:
        ///   - block: [UInt8] to encrypt. Size should lie between (0, MiniLock.FileFormat.PlainTextBlockMaxBytes]
        ///   - isLastBlock: set to true if this is the last block
        /// - Returns: (cipher text + mac) is returned in form of [UInt8]
        /// - Throws: MiniLockStreamCryptor.CryptoError
        public func encrypt(messageBlock: Data, isLastBlock: Bool) throws -> Data {
            if processStatus != .incomplete  {
                throw CryptoError.processComplete
            }

            guard messageBlock.count > 0,
                messageBlock.count <= MiniLock.FileFormat.PlainTextBlockMaxBytes else {
                    throw CryptoError.inputSizeInvalid
            }

            if isLastBlock {
                // set MSB of the block counter
                fullNonce[fullNonce.count - 1] |= 0x80

                _processStatus = .succeeded
            }

            // add padding to block
            let paddedMessage = messagePadding + messageBlock

            // encrypt the message and extract the cipherText from cipherBuffer
            crypto_secretbox(UnsafeMutablePointer(mutating: cipherBuffer).advanced(by: MiniLock.FileFormat.BlockSizeTagLength),
                             paddedMessage,
                             UInt64(paddedMessage.count),
                             fullNonce,
                             key)

            incrementNonce()
            
            var cipherText = Data(bytesNoCopy: UnsafeMutablePointer(mutating: cipherBuffer).advanced(by: CryptoSecretBoxSizes.CipherTextPadding),
                                  count: MiniLock.FileFormat.BlockSizeTagLength + messageBlock.count + CryptoSecretBoxSizes.MAC,
                                  deallocator: .none)

            // set the block length tag
            for i in 0..<MiniLock.FileFormat.BlockSizeTagLength {
                cipherText[i] = UInt8((messageBlock.count >> (8 * i)) & 0xff)
            }

            // update blake2s
            cipherText.withUnsafeBytes { (cipherTextBytesPointer) -> Void in
                blake2s_update(blake2SStatePointer, cipherTextBytesPointer, cipherText.count)
            }
            

            if isLastBlock {
                // finalize and extract the hash
                blake2s_final(blake2SStatePointer,
                              UnsafeMutablePointer(mutating: _cipherTextHash),
                              StreamCryptoBase.Blake2sOutputLength)
            }

            return cipherText
        }
    }
}
