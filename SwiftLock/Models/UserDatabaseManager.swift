//
//  FriendsDatabase.swift
//  SwiftLock
//
//  Created by Mohak Shah on 30/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import MiniLockCore

/// Struct to manage an on-disk, encrypted UserDatabase
struct UserDatabaseManager
{
    enum Errors: Error {
        case jsonMappingError
        case databaseEncryptedBySomebodyElse
        case invalidDbURL
    }

    let url: URL
    let keyPair: MiniLock.KeyPair

    var userDb: UserDatabase {
        didSet {
            try? saveDatabaseToDisk()
        }
    }

    /// Initializes the object
    ///
    /// - Parameters:
    ///   - url: url where database should be saved
    ///   - keyPair: The KeyPair to use to encrypt/decrypt the db
    /// - Throws: UserDatabaseManager.Errors
    init(url: URL, keyPair: MiniLock.KeyPair) throws {
        if !url.isFileURL {
            throw Errors.invalidDbURL
        }

        self.url = url
        self.keyPair = keyPair
        self.userDb = UserDatabase()
        try? readDatabaseFromDisk()
    }
    
    /// Decrypts, reads and loads the userDb from the disk
    ///
    /// - Throws: UserDatabaseManager.Errors
    private mutating func readDatabaseFromDisk() throws {
        // decrypt the database in-memory
        let decryptor = try MiniLock.FileDecryptor(sourceFile: url, recipientKeys: keyPair)
        
        let data = try decryptor.decrypt(deleteSourceFile: false)
        
        // make sure the database was encrypted by the user
        guard decryptor.sender == keyPair.publicId else {
            throw Errors.databaseEncryptedBySomebodyElse
        }

        // map json to object
        guard let jsonString = String(bytes: data, encoding: .utf8),
            let userDb = try? UserDatabase(JSONString: jsonString) else {
            throw Errors.jsonMappingError
        }
        
        self.userDb = userDb
    }
    
    /// Encrypts and saves the userDb to disk
    ///
    /// - Throws: UserDatabaseManager.Errors
    private func saveDatabaseToDisk() throws {
        // convert the database to JSON
        guard let jsonString = userDb.toJSONString() else {
            throw Errors.jsonMappingError
        }
        
        let plainTextData = Data(jsonString.utf8)
        
        // encrypt and save the json to a temp file
        let tempURL = URL(string: "file://" + NSTemporaryDirectory())!.appendingPathComponent(UUID().uuidString, isDirectory: false)
        
        // encrypt to self
        try MiniLock.FileEncryptor.encrypt(plainTextData, destinationFileURL: tempURL, sender: keyPair, recipients: [keyPair.publicId])
        
        // The old db will be here in case of any errors
        let backupURL = url.appendingPathExtension("backup")
        
        do {
            // replace old db with new one
            try FileManager.default.replaceItem(at: url,
                                                withItemAt: tempURL,
                                                backupItemName: backupURL.lastPathComponent,
                                                options: [],
                                                resultingItemURL: nil)
        } catch {
            let nsError = error as NSError
            print(nsError)
            
            // try to restore from backup
            if !FileManager.default.fileExists(atPath: url.path) {
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try FileManager.default.moveItem(at: backupURL, to: url)
                } else {
                    // in case the original item was misplaced during the operation, restore it from wherever it is
                    if let originalItemLocation = nsError.userInfo["NSFileOriginalItemLocationKey"] as? URL,
                            originalItemLocation != url {
                        try FileManager.default.moveItem(at: originalItemLocation, to: url)
                    }
                }
            }
            
            // delete the temp file
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}
