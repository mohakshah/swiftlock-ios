//
//  FriendListViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 04/05/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

class FriendListViewController: UITableViewController
{
    struct Constants {
        static let CellReuseIdentifier = "FriendListCell"
        static let FriendVCSegue = "FriendList2Friend"
        static let AddFriendSegue = "FriendList2Add"
        static let FriedsDbName = "friends.db"
        
        static let NameForCurrentUser = "Me"
    }
    
    // MARK: - Model
    fileprivate var friendsDb: FriendsDatabase? {
        didSet {
            tableView.reloadData()
        }
    }
    
    var currentUser: Friend?
    var selectedIndex = IndexPath(row: 0, section: 0)
    
    var addButton: UIBarButtonItem?
    var deleteButton: UIBarButtonItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if CurrentUser.shared.isLoggedIn {
            userLoggedIn()
        }
        
        tableView.allowsMultipleSelectionDuringEditing = true

        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addFriend))
        deleteButton = UIBarButtonItem(title: Strings.Delete, style: .plain, target: self, action: #selector(deleteSelected))
        deleteButton!.tintColor = .red
        
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        self.navigationItem.rightBarButtonItem = addButton
        
        // register for login/logout notifications
        onLoginCall(#selector(self.userLoggedIn))
        onLogoutCall(#selector(userLoggedOut))
    }
    
    @objc fileprivate func userLoggedIn() {
        currentUser = Friend(name: Constants.NameForCurrentUser, id: CurrentUser.shared.keyPair!.publicId)
        openDatabase()
    }
    
    @objc fileprivate func userLoggedOut() {
        closeDatabase()
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    fileprivate func openDatabase() {
        friendsDb = try? FriendsDatabase(url: CurrentUser.shared.homeDir.appendingPathComponent(Constants.FriedsDbName),
                                    keyPair: CurrentUser.shared.keyPair!)
    }
    
    fileprivate func closeDatabase() {
        friendsDb = nil
    }
    
    @objc fileprivate func addFriend() {
        // add friend segue
        print("Can't add a friend yet!")
        performSegue(withIdentifier: Constants.AddFriendSegue, sender: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if friendsDb != nil {
            // self and friends
            return 2
        } else {
            // nothing to show
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return friendsDb?.friends.count ?? 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.CellReuseIdentifier, for: indexPath)

        // Configure the cell...
        if indexPath.section == 0 {
            cell.textLabel?.text = currentUser?.name
        } else {
            if let name = friendsDb?.friends[indexPath.row].name {
                cell.textLabel?.text = name
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
            friendsDb?.friends.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.endUpdates()
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // can't delete self, obviously
        if indexPath.section == 0 {
            return false
        }
        
        return true
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !self.isEditing {
            selectedIndex = indexPath
            
            performSegue(withIdentifier: Constants.FriendVCSegue, sender: nil)
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if editing {
            self.navigationItem.rightBarButtonItem = deleteButton
        } else {
            self.navigationItem.rightBarButtonItem = addButton
        }
    }
    
    @objc fileprivate func deleteSelected() {
        if let indices = tableView.indexPathsForSelectedRows,
            var friendList = friendsDb?.friends {
            tableView.beginUpdates()
            for index in indices {
                friendList.remove(at: index.row)
            }
            friendsDb?.friends = friendList
            tableView.deleteRows(at: indices, with: .automatic)
            tableView.endUpdates()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let friendVC = segue.destination.mainVC as? FriendViewController {
            if selectedIndex.section == 0 {
                friendVC.friend = currentUser
                friendVC.isViewingCurrentUser = true
            } else {
                friendVC.friend = friendsDb?.friends[selectedIndex.row]
                friendVC.isEditable = true
            }

            friendVC.delegate = self
        } else if let addVC = segue.destination.mainVC as? FriendEditController {
            addVC.delegate = self
        }
    }
}

extension FriendListViewController: FriendViewDelegate {
    func friendViewDelegate(_ viewer: FriendViewController, didEditFriendTo newFriend: Friend) {
        if selectedIndex.section == 0 {
            // TODO: Save the new username to user preferences
            currentUser = newFriend
        } else {
            friendsDb?.friends.remove(at: selectedIndex.row)
            friendsDb?.insertSorted(friend: newFriend)
        }
        tableView.reloadData()
    }
}

extension FriendListViewController: FriendEditDelegate {
    func friendEditControllerDidCancel(_ editor: FriendEditController) {
        dismiss(animated: true, completion: nil)
    }
    
    func friendEditController(_ editor: FriendEditController, didEditFriend newFriend: Friend) {
        friendsDb?.insertSorted(friend: newFriend)
        dismiss(animated: true) { [weak self] in self?.tableView.reloadData() }
    }
}
