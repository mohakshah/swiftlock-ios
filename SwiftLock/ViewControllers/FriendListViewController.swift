//
//  FriendListViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 04/05/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import AVFoundation
import QRCodeReader
import AudioToolbox

class FriendListViewController: UITableViewController
{
    struct Constants {
        static let CellReuseIdentifier = "FriendListCell"
        static let FriendVCSegue = "FriendList2Friend"
        static let AddFriendSegue = "FriendList2Add"
        static let FriedsDbName = "friends.db"
        
        static let NameForCurrentUser = "Me"
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

        // setup 'addButton' and 'deleteButton'
        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addFriend))
        deleteButton = UIBarButtonItem(title: Strings.Delete, style: .plain, target: self, action: #selector(deleteSelected))
        deleteButton!.tintColor = .red
        
        // add 'addButton' and editButton to the navigation bar
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        self.navigationItem.rightBarButtonItem = addButton
        
        // register for login/logout notifications
        onLoginCall(#selector(self.userLoggedIn))
        onLogoutCall(#selector(userLoggedOut))
    }
    
    @objc fileprivate func userLoggedIn() {
        // Create a new Friend with the default name and newly logged in user's public id and update the currentUser
        currentUser = Friend(name: CurrentUser.shared.userDbManager?.userDb.preferences.name ?? Constants.NameForCurrentUser,
                             id: CurrentUser.shared.keyPair!.publicId)
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    @objc fileprivate func userLoggedOut() {
        // In case we are displaying a Friend's details, go back to the root VC
        self.navigationController?.popToRootViewController(animated: true)
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    @objc fileprivate func addFriend() {
        present(addFriendOptionsSheet, animated: true, completion: nil)
    }
    
    lazy var addFriendOptionsSheet: UIAlertController = {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // option to scan qr code
        if AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera, AVCaptureDevice.DeviceType.builtInTelephotoCamera],
                                           mediaType: AVMediaType.video,
                                           position: .unspecified).devices.count > 0 {
            sheet.addAction(UIAlertAction(title: Strings.ScanQRCode, style: .default) { [weak self] (_) in
                if QRCodeReader.isAvailable() {
                    self?.present(self!.qrReaderVC, animated: true, completion: nil)
                } else {
                    // We don't have access to the device's camera
                    self?.alert(withTitle: Strings.CameraAuthorizationDeniedTitle, message: Strings.CameraAuthorizationDeniedMessage)
                }
            })
        }

        // option to enter details manually
        sheet.addAction(UIAlertAction(title: Strings.EnterManually, style: .default) { [weak self] (_) in
            self?.performSegue(withIdentifier: Constants.AddFriendSegue, sender: nil)
        })
        
        // option to dismiss
        sheet.addAction(UIAlertAction(title: Strings.Cancel, style: .cancel) { [weak self] (_) in
            self?.dismiss(animated: true, completion: nil)
        })
        
        return sheet
    }()
    
    // lazily instantiate and setup QRReaderVC
    lazy var qrReaderVC: QRCodeReaderViewController = {
        let builder = QRCodeReaderViewControllerBuilder {
            $0.reader = QRCodeReader(metadataObjectTypes: [AVMetadataObject.ObjectType.qr], captureDevicePosition: .back)
        }
        
        let reader = QRCodeReaderViewController(builder: builder)
        reader.delegate = self
        reader.modalPresentationStyle = .formSheet
        return reader
    }()
}

// MARK: - Table view data source
extension FriendListViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int {
        if CurrentUser.shared.userDbManager != nil {
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
            return CurrentUser.shared.userDbManager?.userDb.friends.count ?? 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.CellReuseIdentifier, for: indexPath)

        // Configure the cell...
        if indexPath.section == 0 {
            cell.textLabel?.text = currentUser?.name
        } else {
            if let name = CurrentUser.shared.userDbManager?.userDb.friends[indexPath.row].name {
                cell.textLabel?.text = name
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
            CurrentUser.shared.userDbManager?.userDb.friends.remove(at: indexPath.row)
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
        
        // switch between 'deleteButton' and 'addButton'
        if editing {
            self.navigationItem.rightBarButtonItem = deleteButton
        } else {
            self.navigationItem.rightBarButtonItem = addButton
        }
    }
    
    @objc fileprivate func deleteSelected() {
        // delete selected rows, starting from the last index
        if let indices = tableView.indexPathsForSelectedRows?.sorted(by: { $0.row > $1.row }),
            var friendList = CurrentUser.shared.userDbManager?.userDb.friends {
            tableView.beginUpdates()
            // remove from the temp array
            for index in indices {
                friendList.remove(at: index.row)
            }
            
            // save the temp
            CurrentUser.shared.userDbManager?.userDb.friends = friendList
            tableView.deleteRows(at: indices, with: .automatic)
            tableView.endUpdates()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Constants.FriendVCSegue,
            let friendVC = segue.destination.mainVC as? FriendViewController {
            if selectedIndex.section == 0 {
                // display the current user's details
                friendVC.friend = currentUser
                friendVC.isViewingCurrentUser = true
            } else {
                // display the details of the friend selected
                friendVC.friend = CurrentUser.shared.userDbManager?.userDb.friends[selectedIndex.row]
                friendVC.isEditable = true
            }

            friendVC.delegate = self
        } else if segue.identifier == Constants.AddFriendSegue,
            let addVC = segue.destination.mainVC as? FriendEditController {
            addVC.delegate = self
        }
    }
}

// MARK: - FriendViewDelegate
extension FriendListViewController: FriendViewDelegate {
    func friendViewDelegate(_ viewer: FriendViewController, didEditFriendTo newFriend: Friend) {
        if selectedIndex.section == 0 {
            CurrentUser.shared.userDbManager?.userDb.preferences.name = newFriend.name
            currentUser = newFriend
        } else {
            // remove the old one and insert the new one
            CurrentUser.shared.userDbManager?.userDb.friends.remove(at: selectedIndex.row)
            CurrentUser.shared.userDbManager?.userDb.insertSorted(friend: newFriend)
        }

        tableView.reloadData()
    }
}

// MARK: - FriendEditDelegate
// Note: These methods will be called when a new friend is added manually,
// _not_ when an existing one is being added.
extension FriendListViewController: FriendEditDelegate {
    func friendEditControllerDidCancel(_ editor: FriendEditController) {
        dismiss(animated: true, completion: nil)
    }
    
    func friendEditController(_ editor: FriendEditController, didEditFriend newFriend: Friend) {
        // insert the manually entered info to the database
        CurrentUser.shared.userDbManager?.userDb.insertSorted(friend: newFriend)
        dismiss(animated: true) { [weak self] in self?.tableView.reloadData() }
    }
}

// MARK: - QRCodeReaderViewControllerDelegate
extension FriendListViewController: QRCodeReaderViewControllerDelegate {
    func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        // vibrate the phone
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        // Try to create a Friend object from the value of the scanned QR Code
        guard let newFriend = Friend(fromQRCodeScheme: result.value) else {
            // alert and continue scanning
            let alertVC = UIAlertController(title: Strings.InvalidQRCode, message: Strings.TryAgain, preferredStyle: .alert)
            alertVC.addAction(UIAlertAction(title: Strings.OK, style: .cancel, handler: { (_) in reader.startScanning() }))
            reader.present(alertVC, animated: true, completion: nil)
            return
        }

        // dismiss the scanner vc and add the friend to the database
        dismiss(animated: true, completion: nil)
        CurrentUser.shared.userDbManager?.userDb.insertSorted(friend: newFriend)
        tableView.reloadData()
    }
    
    func reader(_ reader: QRCodeReaderViewController, didSwitchCamera newCaptureDevice: AVCaptureDeviceInput) {
        // don't care
    }
    
    func readerDidCancel(_ reader: QRCodeReaderViewController) {
        dismiss(animated: true, completion: nil)
    }
}
