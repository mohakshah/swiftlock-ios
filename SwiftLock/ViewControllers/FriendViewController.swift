//
//  FriendViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 05/05/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import Photos

protocol FriendViewDelegate {
    func friendViewDelegate(_ viewer: FriendViewController, didEditFriendTo newFriend: Friend)
}

/// Displays details of a Friend object like name, id, QRCode and provides the option to share using the standard share sheet
class FriendViewController: UITableViewController
{
    struct Constants {
        static let EditFriendSegue = "FriendView2Edit"
        static let QRCodeShareSize = CGSize(width: 800.0, height: 800.0)
    }

    // MARK: - Storyboard Outlets
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var qrCode: UIImageView!
    @IBOutlet weak var publicId: UILabel!

    @IBAction func share(_ sender: Any) {
        guard let friend = friend else {
            return
        }

        var items = [Any]()
        let text = "Here is " + (isViewingCurrentUser ? "my" : "\(friend.name)'s") + " miniLock Id: \(friend.id.base58String)"
        items.append(text)

        // convert the CIImage of the qrCode to CGImage so that it can be shared
        if let ciImage = friend.qrCodeCI,
            let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) {
            items.append(UIImage(cgImage: cgImage))
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.modalPresentationStyle = .popover
        
        present(activityVC, animated: true, completion: nil)
    }
    
    // MARK: - Model
    var friend: Friend? {
        didSet {
            refreshUI()
        }
    }
    
    var delegate: FriendViewDelegate?
    
    // A parent VC can set this to allow/disallow editing of the Friend
    var isEditable: Bool = true {
        didSet {
            self.navigationItem.rightBarButtonItem?.isEnabled = isEditable
        }
    }
    
    // A parent VC can set this to just allow editing the name and not the miniLock Id
    var isViewingCurrentUser: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // configure the tableView
        tableView.estimatedRowHeight = 64
        tableView.rowHeight = UITableViewAutomaticDimension

        // add edit button to the navigation bar
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editContact))
        self.navigationItem.rightBarButtonItem?.isEnabled = isEditable
        
        self.refreshUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // disable large titles
        if #available(iOS 11.0, *) {
            self.navigationController?.navigationBar.prefersLargeTitles = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // re-enable large titles
        if #available(iOS 11.0, *) {
            self.navigationController?.navigationBar.prefersLargeTitles = true
        }
    }
    
    private func refreshUI() {
        name?.text = friend?.name
        qrCode?.image = friend?.qrCode(ofSize: qrCode.frame.size)
        publicId?.text = friend?.id.base58String.adding(seperator: " ", afterCharacters: 5)
    }
    
    @objc private func editContact() {
        performSegue(withIdentifier: Constants.EditFriendSegue, sender: nil)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let editVC = segue.destination.mainVC as? FriendEditController {
            editVC.friend = friend
            editVC.delegate = self
            
            if isViewingCurrentUser {
                editVC.canEditId = false
            }
        }
    }
}

extension FriendViewController: FriendEditDelegate {
    func friendEditController(_ editor: FriendEditController, didEditFriend newFriend: Friend) {
        self.friend = newFriend
        dismiss(animated: false, completion: nil)
        delegate?.friendViewDelegate(self, didEditFriendTo: newFriend)
    }
    
    func friendEditControllerDidCancel(_ editor: FriendEditController) {
        dismiss(animated: false, completion: nil)
    }
}
