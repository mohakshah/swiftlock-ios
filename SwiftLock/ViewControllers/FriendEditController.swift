//
//  FriendEditController
//  SwiftLock
//
//  Created by Mohak Shah on 05/05/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import MiniLockCore
import SkyFloatingLabelTextField

protocol FriendEditDelegate {
    func friendEditControllerDidCancel(_ editor: FriendEditController)
    func friendEditController(_ editor: FriendEditController, didEditFriend newFriend: Friend)
}

class FriendEditController: UITableViewController
{
    @IBOutlet weak var nameField: SkyFloatingLabelTextField! {
        didSet {
            nameField.text = friend?.name
            nameField.delegate = self
        }
    }
    @IBOutlet weak var idField: SkyFloatingLabelTextField! {
        didSet {
            idField.text = friend?.id.base58String
            idField.isUserInteractionEnabled = canEditId
            idField.delegate = self
        }
    }
    
    // MARK: - Model
    var friend: Friend? {
        didSet {
            refreshUI()
        }
    }
    
    var delegate: FriendEditDelegate? = nil
    
    // A parent VC can set this to false to just allow editing the name and not the miniLock Id
    var canEditId: Bool = true {
        didSet {
            idField?.isUserInteractionEnabled = canEditId
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // add 'done' and 'cancel' buttons to the navigation bar
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        
        // listen for textfield changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(validateNameField),
                                               name: Notification.Name.UITextFieldTextDidChange,
                                               object: nameField)
    }
    
    @objc private func cancel() {
        delegate?.friendEditControllerDidCancel(self)
    }
    
    @objc private func done() {
        // Get username
        guard let name = validateNameField() else {
            return
        }
        
        // Get miniLock Id
        guard let b58 = idField.text, !b58.isEmpty, let id = MiniLock.Id(fromBase58String: b58) else {
            // display error
            idField.errorMessage = "Invalid"
            idField.becomeFirstResponder()
            return
        }
        
        delegate?.friendEditController(self, didEditFriend: Friend(name: name, id: id))
    }
    
    private func refreshUI() {
        nameField?.text = friend?.name
        idField?.text = friend?.id.base58String
    }
}

// MARK :- UITextFieldDelegate
extension FriendEditController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameField {
            idField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        
        return true
    }
    
    /// Validates the name field
    ///
    /// - Returns: Returns the name if it's valid; otherwise, returns nil.
    @objc func validateNameField() -> String? {
        guard let name = nameField.text, !name.isEmpty else {
            // Display error
            nameField.errorMessage = "Invalid"
            nameField.becomeFirstResponder()
            return nil
        }
        
        // Remove error
        nameField.errorMessage = nil

        return name
    }
}

