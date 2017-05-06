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
        if let ciImage = friend.qrCode(ofSize: Constants.QRCodeShareSize)?.ciImage,
            let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) {
            items.append(UIImage(cgImage: cgImage))
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        present(activityVC, animated: true, completion: nil)
        
        activityVC.modalPresentationStyle = .popover
    }
    
    // MARK: - Model
    var friend: Friend? {
        didSet {
            refreshUI()
        }
    }
    
    var delegate: FriendViewDelegate?
    var isEditable: Bool = true {
        didSet {
            self.navigationItem.rightBarButtonItem?.isEnabled = isEditable
        }
    }
    
    var isViewingCurrentUser: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 64
        tableView.rowHeight = UITableViewAutomaticDimension

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editContact))
        self.navigationItem.rightBarButtonItem?.isEnabled = isEditable
        
        self.refreshUI()
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
