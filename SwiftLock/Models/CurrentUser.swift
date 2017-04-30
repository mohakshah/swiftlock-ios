//
//  CurrentUser.swift
//  SwiftLock
//
//  Created by Mohak Shah on 08/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import MiniLockCore
import libb2s

class CurrentUser
{
    struct Constants {
        static let EncryptedDirectoryName = "Encrypted"
        static let DecryptedDirectoryName = "Decrypted"
        static let FriedsDbName = "friends.db"
        
        static let PublicKeySaltUserDefaultsKey = "SaltForPublicKey"
        
        static let HashOutputBytes = 16
    }

    static let shared = CurrentUser()
    
    let salt: [UInt8]

    private init() {
        if let saltString = UserDefaults.standard.string(forKey: Constants.PublicKeySaltUserDefaultsKey) {
            salt = Array(saltString.utf8)
        } else {
            let saltString = UUID().uuidString
            UserDefaults.standard.set(saltString, forKey: Constants.PublicKeySaltUserDefaultsKey)
            salt = Array(saltString.utf8)
        }
    }
    
    private var _keyPair: MiniLock.KeyPair? = nil
    
    var keyPair: MiniLock.KeyPair? {
        return _keyPair
    }
    
    var isLoggedIn: Bool {
        return _keyPair != nil
    }
    
    func login(withKeyPair keyPair: MiniLock.KeyPair) {
        _keyPair = keyPair
        
        setupDirectories()
        print("Home dir: ", _homeDir!)
        _friendDb = try? FriendsDatabase(url: homeDir.appendingPathComponent(Constants.FriedsDbName, isDirectory: false),
                              keyPair: keyPair)
        
        // post a notification
        let notification = Notification.Name(rawValue: NotificationNames.UserLoggedIn)
        NotificationCenter.default.post(name: notification, object: self)
    }
    
    func logout() {
        _keyPair = nil
        
        // post a notificaiton
        let notification = Notification.Name(rawValue: NotificationNames.UserLoggedOut)
        NotificationCenter.default.post(name: notification, object: self)
        
        closeDirectories()
    }
    
    private var _homeDir: URL?
    private var _encryptedDir: URL?
    private var _decryptedDir: URL?
    private var _friendDb: FriendsDatabase?
    
    var homeDir: URL! {
        return _homeDir
    }
    
    var encryptedDir: URL! {
        return _encryptedDir
    }
    
    var decryptedDir: URL! {
        return _decryptedDir
    }
    
    var friendDb: FriendsDatabase! {
        return _friendDb
    }
    
    private func setupDirectories() {
        _homeDir = addSubDirectory(to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
                                  named: generateHomeDirBasename())
        
        _encryptedDir = addSubDirectory(to: homeDir, named: Constants.EncryptedDirectoryName)
        _decryptedDir = addSubDirectory(to: homeDir, named: Constants.DecryptedDirectoryName)
    }
    
    private func closeDirectories() {
        _homeDir = nil
        _encryptedDir = nil
        _decryptedDir = nil
    }
    
    private func generateHomeDirBasename() -> String {
        let input = _keyPair!.publicId.binary + salt
        var output = [UInt8](repeating: 0, count: Constants.HashOutputBytes)
        blake2s(UnsafeMutablePointer(mutating: output),
                input,
                nil,
                output.count,
                input.count,
                0)

        return Base58.encode(bytes: output)
    }

    private func addSubDirectory(to parent: URL, named name: String) -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        
        var whatExistsIsADir: ObjCBool = false
        
        let somethingExists = withUnsafeMutablePointer(to: &whatExistsIsADir) { (pointer) -> Bool in
            return FileManager.default.fileExists(atPath: url.path, isDirectory: pointer)
        }
        
        if somethingExists {
            if whatExistsIsADir.boolValue {
                return url
            } else {
                try! FileManager.default.removeItem(at: url)
            }
        }
        
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
        
        return url
    }
}
