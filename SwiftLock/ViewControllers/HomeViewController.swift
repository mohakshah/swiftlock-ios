//
//  HomeViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 08/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import MiniLockCore

fileprivate struct SegueIds {
    static let ToLogin = "Home2Login"
}

class HomeViewController: UITabBarController
{
    fileprivate var currentFile: URL? {
        didSet {
            guard let url = currentFile  else  {
                return
            }

            do {
                if try MiniLock.isEncryptedFile(url: url) {
                    decrypt(url)
                } else {
                    encrypt(url)
                }
            } catch (let error) {
                print(error)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // register for login and logout notifications
        onLoginCall(#selector(userLoggedIn))
        onLogoutCall(#selector(userLoggedOut))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !CurrentUser.shared.isLoggedIn {
            performSegue(withIdentifier: SegueIds.ToLogin, sender: self)
        }
    }
    
    @objc fileprivate func userLoggedIn() {
        if let _ = presentedViewController as? LoginViewController {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc fileprivate func userLoggedOut() {
        performSegue(withIdentifier: SegueIds.ToLogin, sender: self)
    }
    
    func handleFile(url: URL) {
        if currentFile == nil && CurrentUser.shared.isLoggedIn {
            currentFile = url
        } else {
            do {
                try FileManager.default.removeItem(at: url)
            } catch (let error) {
                print("Error deleting the source file: ", error)
            }

            print("Sorry, currently working on another file:", currentFile!)
        }
    }
    
    fileprivate func decrypt(_ url: URL) {
        print("Decrypting...")
        do {
            let decryptor = try MiniLock.FileDecryptor(sourceFile: url, recipientKeys: CurrentUser.shared.keyPair!)
            try decryptor.decrypt(destinationDirectory: CurrentUser.shared.decryptedDir, filename: nil, deleteSourceFile: true)
        } catch (let error) {
            print("error:", error)
        }
        currentFile = nil
    }
    
    fileprivate func encrypt(_ url: URL) {
        print("Encrypting...")
        do {
            let encryptor = try MiniLock.FileEncryptor(fileURL: url, sender: CurrentUser.shared.keyPair!, recipients: [])
            try encryptor.encrypt(destinationDirectory: CurrentUser.shared.encryptedDir, filename: nil, deleteSourceFile: true)
        } catch (let error) {
            print("error:", error)
        }

        currentFile = nil
    }
}
