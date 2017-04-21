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

class HomeViewController: FileListViewController {
    
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
        if currentFile == nil {
            currentFile = url
        } else {
            print("Sorry, currently working on another file:", currentFile!)
        }
    }
    
    fileprivate func decrypt(_ url: URL) {
        print("Decrypting...")
        currentFile = nil
    }
    
    fileprivate func encrypt(_ url: URL) {
        print("Encrypting...")
        currentFile = nil
    }
}
