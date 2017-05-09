//
//  FriendsDatabase.swift
//  SwiftLock
//
//  Created by Mohak Shah on 30/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import MiniLockCore

struct FriendsDatabase
{
    enum Errors: Error {
        case jsonMappingError
        case databaseEncryptedBySomebodyElse
    }

    let url: URL
    let keyPair: MiniLock.KeyPair
    
    var friends: [Friend] {
        didSet {
            try? saveFriendListToDb()
            print("Friend List: \(friends)")
        }
    }

    init(url: URL, keyPair: MiniLock.KeyPair) throws {
        self.url = url
        self.keyPair = keyPair
        self.friends = [Friend]()
        try? updateFriendsFromDb()
    }
    
    mutating func insertSorted(friend: Friend) {
        for i in 0..<friends.count {
            if friends[i].name.localizedCaseInsensitiveCompare(friend.name) == ComparisonResult.orderedDescending {
                friends.insert(friend, at: i)
                return
            }
        }
        
        friends.append(friend)
    }
    
    private mutating func updateFriendsFromDb() throws {
        let decryptor = try MiniLock.FileDecryptor(sourceFile: url, recipientKeys: keyPair)
        
        let data = try decryptor.decrypt(deleteSourceFile: false)
        
        // make sure the database was encrypted by the user
        guard decryptor.sender == keyPair.publicId else {
            throw Errors.databaseEncryptedBySomebodyElse
        }

        guard let jsonString = String(bytes: data, encoding: .utf8),
            let friendsList = Array<Friend>(JSONString: jsonString) else {
            throw Errors.jsonMappingError
        }
        
        self.friends = friendsList
    }
    
    private func saveFriendListToDb() throws {
        guard let jsonString = friends.toJSONString() else {
            throw Errors.jsonMappingError
        }
        
        let plainTextData = Data(jsonString.utf8)
        
        let tempURL = URL(string: "file://" + NSTemporaryDirectory())!.appendingPathComponent(UUID().uuidString, isDirectory: false)
        
        // encrypt to self
        try MiniLock.FileEncryptor.encrypt(plainTextData, destinationFileURL: tempURL, sender: keyPair, recipients: [keyPair.publicId])
        
        let backupURL = url.appendingPathExtension("backup")
        
        do {
            try FileManager.default.replaceItem(at: url,
                                                withItemAt: tempURL,
                                                backupItemName: backupURL.lastPathComponent,
                                                options: [],
                                                resultingItemURL: nil)
        } catch {
            let nsError = error as NSError
            print(nsError)
            
            // restore from backup
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
            
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}
