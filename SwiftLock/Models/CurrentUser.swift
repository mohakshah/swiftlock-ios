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
        static let FriedsDbName = "user.db"
        
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
    private var _email: String? = nil
    
    var keyPair: MiniLock.KeyPair? {
        return _keyPair
    }
    
    var email: String? {
        return _email
    }

    var isLoggedIn: Bool {
        return _keyPair != nil
    }

    func login(withKeyPair keyPair: MiniLock.KeyPair, email: String) {
        _keyPair = keyPair

        // check if the home directory of the user already exists
        let homeDirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(generateHomeDirBasename())
        let isFirstLoginByThisUser = !FileManager.default.fileExists(atPath: homeDirURL.path)

        setupDirectories()
        userDbManager = try? UserDatabaseManager(url: homeDir.appendingPathComponent(Constants.FriedsDbName), keyPair: keyPair)

        // post a notification
        if isFirstLoginByThisUser {
            NotificationCenter.default.post(name: Notification.Name(rawValue:  NotificationNames.UserLoggedInForTheFirstTime), object: self)
            
            let indexOfAt = email.index(of: "@") ?? email.endIndex
            userDbManager?.userDb.preferences.name = String(email[..<indexOfAt])
        }

        NotificationCenter.default.post(name: Notification.Name(rawValue:  NotificationNames.UserLoggedIn), object: self)
    }

    func logout() {
        _keyPair = nil
        
        // post a notificaiton
        let notification = Notification.Name(rawValue: NotificationNames.UserLoggedOut)
        NotificationCenter.default.post(name: notification, object: self)
        
        userDbManager = nil
        
        closeDirectories()
    }
    
    private var _homeDir: URL?
    private var _encryptedDir: URL?
    private var _decryptedDir: URL?
    
    var homeDir: URL! {
        return _homeDir
    }
    
    var encryptedDir: URL! {
        return _encryptedDir
    }
    
    var decryptedDir: URL! {
        return _decryptedDir
    }
    
    var userDbManager: UserDatabaseManager?
    
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
        output[0] = 0 // to stop the "output was never mutated" warning
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
