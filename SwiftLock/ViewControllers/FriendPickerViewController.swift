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

/// FriendPickerViewController displays a list of all friends and the current user
///  and allows choosing one or more of them. When user selects 'done' or 'cancel', the delegate is informed of their action
class FriendPickerViewController: FriendListViewController
{
    struct Constants {
        static let MVCTitle = "Select Friends"
    }
    
    var delegate: FriendPickerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.isEditing = true

        // add 'cancel' and 'done' buttons to the navigation bar
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        
        self.navigationItem.title = Constants.MVCTitle
    }
    
    fileprivate var viewAppearingForTheFirstTime: Bool = true
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // select the 'self' by default when the view appears for the first time
        if viewAppearingForTheFirstTime {
            tableView.selectRow(at: IndexPath(row: 0, section: 0),
                                animated: false,
                                scrollPosition: .none)
            
            viewAppearingForTheFirstTime = false
        }
    }

    @objc fileprivate func done() {
        if let indices = tableView.indexPathsForSelectedRows,
            let friendList = CurrentUser.shared.friendsDb?.friends {
            // create an array of 'Friend' objects selected
            var selectedFriends = [Friend]()
            for index in indices {
                if index.section == 0 {
                    // add the current user if they are also selected
                    if let currentUser = currentUser {
                        selectedFriends.append(currentUser)
                    }
                    
                    continue
                }

                selectedFriends.append(friendList[index.row])
            }

            // call the delegate's didPickFriends
            delegate?.friendPicker(self, didPickFriends: selectedFriends)
        }
    }
    
    @objc fileprivate func cancel() {
        delegate?.friendPickerDidCancel(self)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
