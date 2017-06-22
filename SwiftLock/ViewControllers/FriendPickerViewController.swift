//
//  FriendPickerViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 08/05/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

protocol FriendPickerDelegate {
    func friendPicker(_ picker: FriendPickerViewController, didPickFriends friends: [Friend])
    func friendPickerDidCancel(_ picker: FriendPickerViewController)
}

class FriendPickerViewController: FriendListViewController {
    
    struct Constants {
        static let MVCTitle = "Select Friends"
    }
    
    var delegate: FriendPickerDelegate?
    
    var leftBarButtonItem: UIBarButtonItem?
    var rightBarButtonItem: UIBarButtonItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.isEditing = true

        leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
        self.navigationItem.leftBarButtonItem = leftBarButtonItem
        
        self.navigationItem.title = Constants.MVCTitle
    }

    @objc fileprivate func done() {
        if let indices = tableView.indexPathsForSelectedRows,
            let friendList = CurrentUser.shared.friendsDb?.friends {
            var selectedFriends = [Friend]()
            for index in indices {
                if index.section == 0 {
                    if let currentUser = currentUser {
                        selectedFriends.append(currentUser)
                    }
                    
                    continue
                }

                selectedFriends.append(friendList[index.row])
            }

            delegate?.friendPicker(self, didPickFriends: selectedFriends)
        }
    }
    
    @objc fileprivate func cancel() {
        delegate?.friendPickerDidCancel(self)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
        self.navigationItem.leftBarButtonItem = leftBarButtonItem
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
