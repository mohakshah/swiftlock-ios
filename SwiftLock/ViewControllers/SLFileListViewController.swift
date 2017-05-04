//
//  SLFileListViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 30/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

/// Custom FileListVC that lists the files in the currently logged in user's encryted and decrypted directories.
class SLFileListViewController: FileListViewController {

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
    
    @objc fileprivate func userLoggedIn() {
        self.directories = [CurrentUser.shared.encryptedDir, CurrentUser.shared.decryptedDir]
    }
    
    @objc fileprivate func userLoggedOut() {
        self.directories = []
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.tabBarItem.title = "Files"
    }
}
