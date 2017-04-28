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

class HomeViewController: FileListViewController
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
        let loginNotification = Notification.Name(NotificationNames.UserLoggedIn)
        let logoutNotification = Notification.Name(NotificationNames.UserLoggedOut)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(userLoggedIn),
                                               name: loginNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(userLoggedOut),
                                               name: logoutNotification,
                                               object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !CurrentUser.shared.isLoggedIn {
            performSegue(withIdentifier: SegueIds.ToLogin, sender: self)
        }
    }
    
    @objc fileprivate func userLoggedIn() {
        if let _ = presentedViewController as? LoginViewController {
            dismiss(animated: true, completion: nil)
        }
        
        
        
        self.directories = [CurrentUser.shared.encryptedDir, CurrentUser.shared.decryptedDir]
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
