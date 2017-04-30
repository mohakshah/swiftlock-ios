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
    }

    let url: URL
    let keyPair: MiniLock.KeyPair
    
    var friends: [Friend] {
        didSet {
            try? saveFriendListToDb()
        }
    }

    init(url: URL, keyPair: MiniLock.KeyPair) throws {
        self.url = url
        self.keyPair = keyPair
        self.friends = [Friend]()
        try updateFriendsFromDb()
    }
    
    private mutating func updateFriendsFromDb() throws {
        let decryptor = try MiniLock.FileDecryptor(sourceFile: url, recipientKeys: keyPair)
        
        let data = try decryptor.decrypt(deleteSourceFile: false)
        guard let jsonString = String(bytes: data, encoding: .utf8) else {
            throw Errors.jsonMappingError
        }
        
        guard let friendsList = Array<Friend>(JSONString: jsonString) else {
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
        
        try MiniLock.FileEncryptor.encrypt(plainTextData, destinationFileURL: tempURL, sender: keyPair, recipients: [keyPair.publicId])
        
        try FileManager.default.moveItem(at: tempURL, to: url)
    }
}
