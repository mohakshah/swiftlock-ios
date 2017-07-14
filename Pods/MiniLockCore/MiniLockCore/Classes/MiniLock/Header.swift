//
//  Header.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 31/03/17.
//
//

import Foundation
import ObjectMapper
import libsodium

extension MiniLock {
    struct CryptoBoxSizes {
        static let Nonce = crypto_box_noncebytes()
        static let PublicKey = crypto_box_publickeybytes()
        static let PrivateKey = crypto_box_secretkeybytes()
        static let MAC = crypto_box_macbytes()
    }

    /// Structure to hold a miniLock file header. Allows easy conversion to and from JSON file header.
    struct Header: ImmutableMappable {
        let version: Int
        let ephemeralPublicKey: String
        let decryptInfo: [String: String]
        
        /// Returns a Header object ready to be embedded in a file (after conversion to JSON).
        /// Returns nil in case an error occurs.
        ///
        /// ## Note:
        /// Calling 'toJSONString' after initialization will escap the "/" character with a "\\" in the resultant JSON string.
        /// You can either remove those manually or use the 'toJSONStringWithoutEscapes' method.
        ///
        /// - Parameters:
        ///     - sender: Key pair of the sender
        ///     - recipient: Array of miniLock Ids of recipients who will be able to decrypt the file
        ///     - fileInfo: A FileInfo object containing the key, nonce and hash of the file ths header is meant for
        init?(sender: MiniLock.KeyPair, recipients: [MiniLock.Id], fileInfo: FileInfo) {
            // recipient list can't be empty
            guard !recipients.isEmpty else {
                return nil
            }
            
            // convert fileInfo object in to a JSON string
            guard let fileInfoString = fileInfo.toJSONStringWithoutEscapes() else {
                return nil
            }

            // create a nonce for each recipient
            var recipientNonces = [[UInt8]]()
            for _ in 0..<recipients.count {
                let nonce = [UInt8](repeating: 0, count: CryptoBoxSizes.Nonce)
                randombytes_buf(UnsafeMutablePointer(mutating: nonce), nonce.count)
                recipientNonces.append(nonce)
            }

            let fileInfoBytes = [UInt8](fileInfoString.utf8)
            var encryptedFileInfo = [String]()
            
            for i in 0..<recipients.count {
                // encrypt fileInfo string using the sender's private key and current recipient's public key
                let cipherText = [UInt8](repeating: 0, count: fileInfoBytes.count + CryptoBoxSizes.MAC)
                let ret = crypto_box_easy(UnsafeMutablePointer(mutating: cipherText),
                                          fileInfoBytes,
                                          UInt64(fileInfoBytes.count),
                                          recipientNonces[i],
                                          recipients[i].binary,
                                          sender.privateKey.bytes)
                
                if ret != 0 {
                    return nil
                }
                
                encryptedFileInfo.append(Data(bytes: cipherText).base64EncodedString())
            }
            
            // Now we put these encrypted fileInfo strings in their individual decryptInfo objects
            // and encrypt those decryptInfo objects with an ephemeral key pair.
            
            // generate an ephemeral key pair
            let ephemeralPK = [UInt8](repeating: 0, count: CryptoBoxSizes.PublicKey)
            let ephemeralSK = [UInt8](repeating: 0, count: CryptoBoxSizes.PrivateKey)
            
            crypto_box_keypair(UnsafeMutablePointer(mutating: ephemeralPK), UnsafeMutablePointer(mutating: ephemeralSK))
            self.ephemeralPublicKey = Data(bytes: ephemeralPK).base64EncodedString()

            var decryptInfoList = [String: String]()
            
            
            for i in 0..<recipients.count {
                // create a decryptInfo object for current recipient with the corresponding
                // encrypted fileInfo string and get its json string
                guard let jsonString = DecryptInfo(senderId: sender.publicId,
                                                   recipientId: recipients[i],
                                                   fileInfo: encryptedFileInfo[i])
                                        .toJSONString(prettyPrint: false) else {
                                                return nil
                }
                
                // convert the string to byte array
                let jsonBytes = [UInt8](jsonString.utf8)
                
                // encrypt those bytes using ephemeral secret key and the current recipient's public key
                let cipherText = [UInt8](repeating: 0, count: jsonBytes.count + CryptoBoxSizes.MAC)
                let ret = crypto_box_easy(UnsafeMutablePointer(mutating: cipherText),
                                          jsonBytes,
                                          UInt64(jsonBytes.count),
                                          recipientNonces[i],
                                          recipients[i].binary,
                                          ephemeralSK)
                
                if ret != 0 {
                    return nil
                }
                
                // add cipherText to decryptInfoList using recipient nonce as key
                let nonce = Data(bytes: recipientNonces[i]).base64EncodedString()
                decryptInfoList[nonce] = Data(bytes: cipherText).base64EncodedString()
                
            }
            
            self.decryptInfo = decryptInfoList
            self.version = MiniLock.FileFormat.Version
        }
        
        // JSON <-> Object Mapping
        init(map: Map) throws {
            version = try map.value("version")
            ephemeralPublicKey = try map.value("ephemeral")
            decryptInfo = try map.value("decryptInfo")
        }
        
        func mapping(map: Map) {
            version 			>>> map["version"]
            ephemeralPublicKey 	>>> map["ephemeral"]
            decryptInfo         >>> map["decryptInfo"]
        }
        
        /// Iterates over the encrypted decryptInfo objects stored in the self.decryptInfo dictionary
        /// and attempts to decrypt them until one of them is successfully decrypted or no objects are left in the dictionary.
        ///
        /// - Parameter recipientKeys: The key pair of the recipient to use to decrypt the objects.
        /// - Returns: A DecryptInfo object on success or nil on failure.
        func decryptDecryptInfo(usingRecipientKeys recipientKeys: KeyPair) -> DecryptInfo? {
            // decode the base64 encoded ephemeral public key
            let epehemeralPublicKeyBinary = [UInt8](Data(base64Encoded: ephemeralPublicKey) ?? Data())
            guard epehemeralPublicKeyBinary.count == CryptoBoxSizes.PublicKey else {
                return nil
            }
            
            // iterate over each pair of nonce and encrypted decryptInfo object
            for (nonceString, cipherString) in decryptInfo {
                let nonce = [UInt8](Data(base64Encoded: nonceString) ?? Data())
                let encryptedBytes = [UInt8](Data(base64Encoded: cipherString) ?? Data())
                
                guard nonce.count == CryptoBoxSizes.Nonce,
                    encryptedBytes.count > CryptoBoxSizes.MAC else {
                        continue
                }
                
                let decipheredBytes = [UInt8](repeating: 0, count: encryptedBytes.count - CryptoBoxSizes.MAC)
                
                // try to decrypt encryptedBytes using recipient's private key and the ephemeral public key
                let ret = crypto_box_open_easy(UnsafeMutablePointer(mutating: decipheredBytes),
                                               encryptedBytes,
                                               UInt64(encryptedBytes.count),
                                               nonce,
                                               epehemeralPublicKeyBinary,
                                               recipientKeys.privateKey.bytes)
                
                // if decryption succeededd, create a DecryptInfo object from the JSON plaintext and return that
                if ret == 0,
                    let jsonString = String(bytes: decipheredBytes, encoding: .utf8),
                    var ptDecryptInfo = try? DecryptInfo(JSONString: jsonString) {
                    ptDecryptInfo.nonce = nonce
                    return ptDecryptInfo
                }
            }
            
            // return nil if no object was successfully decrypted
            return nil
        }

    }
}

// MARK: - DecryptInfo
extension MiniLock.Header {
    /// Structure to hold a miniLock header's _plaintext_ decryptInfo object
    struct DecryptInfo: ImmutableMappable {
        let senderId, recipientId: MiniLock.Id
        let fileInfo: String
        var nonce: [UInt8]?
        
        init(senderId: MiniLock.Id, recipientId: MiniLock.Id, fileInfo: String) {
            self.senderId = senderId
            self.recipientId = recipientId
            self.fileInfo = fileInfo
        }
        
        // JSON <-> Object Mapping

        init(map: Map) throws {
            let senderIdString: String = try map.value("senderID")
            let recipientIdString: String = try map.value("recipientID")
            
            guard let senderId = MiniLock.Id(fromBase58String: senderIdString),
                let recipientId = MiniLock.Id(fromBase58String: recipientIdString) else {
                    throw MiniLock.Errors.headerParsingError
            }
            
            self.senderId = senderId
            self.recipientId = recipientId
            self.fileInfo = try map.value("fileInfo")
        }
        
        func mapping(map: Map) {
            senderId.base58String       >>> map["senderID"]
            recipientId.base58String    >>> map["recipientID"]
            fileInfo                    >>> map["fileInfo"]
        }
        
        /// Attempts to decrypt the fileInfo object
        ///
        /// - Parameter recipientKeys: The key pair of the recipient to use to decrypt the objects.
        /// - Returns: FileInfo object on success or nil on failure.
        func decryptFileInfo(usingRecipientKeys recipientKeys: MiniLock.KeyPair) -> FileInfo? {
            // sanity checks
            guard let nonce = nonce,
                nonce.count == MiniLock.CryptoBoxSizes.Nonce,
                recipientKeys.publicId == recipientId else {
                    return nil
            }
            
            // convert fileInfo string to bytes
            let cipherBytes = [UInt8](Data(base64Encoded: fileInfo) ?? Data())
            
            guard cipherBytes.count > MiniLock.CryptoBoxSizes.MAC else {
                return nil
            }
            
            let decipheredBytes = [UInt8](repeating: 0, count: cipherBytes.count - MiniLock.CryptoBoxSizes.MAC)
            
            // try to decrypt  using recipient's private key and sender's public key
            let ret = crypto_box_open_easy(UnsafeMutablePointer(mutating: decipheredBytes),
                                           cipherBytes,
                                           UInt64(cipherBytes.count),
                                           nonce,
                                           senderId.binary,
                                           recipientKeys.privateKey.bytes)
            
            // if decryption was successful, create a FileInfo object from JSON and return it
            if ret == 0,
                let jsonString = String(bytes: decipheredBytes, encoding: .utf8),
                let ptFileInfo = try? FileInfo(JSONString: jsonString) {
                    return ptFileInfo
            }
            
            // if not, return nil
            return nil
        }
    }
}

// MARK: - FileInfo
extension MiniLock.Header {
    struct FileInfo: ImmutableMappable {
        let key, nonce, hash: String
        
        init(key: [UInt8], nonce: [UInt8], hash: [UInt8]) {
            self.key = Data(bytes: key).base64EncodedString()
            self.nonce = Data(bytes: nonce).base64EncodedString()
            self.hash = Data(bytes: hash).base64EncodedString()
        }
        
        // JSON <-> Object Mapping

        init(map: Map) throws {
            key = try map.value("fileKey")
            nonce = try map.value("fileNonce")
            hash = try map.value("fileHash")
        }
        
        func mapping(map: Map) {
            key     >>> map["fileKey"]
            nonce   >>> map["fileNonce"]
            hash    >>> map["fileHash"]
        }
    }
}

extension BaseMappable {
    /// Replaces "\\/" in the String returned by toJSONString(prettyPrint: false) with "/" and returns that string
    func toJSONStringWithoutEscapes() -> String? {
        guard let jsonString = self.toJSONString(prettyPrint: false) else {
            return nil
        }
        
        return jsonString.replacingOccurrences(of: "\\/", with: "/")
    }
}
