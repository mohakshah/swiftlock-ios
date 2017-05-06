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
        onLoginCall(#selector(userLoggedIn))
        onLogoutCall(#selector(userLoggedOut))
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
