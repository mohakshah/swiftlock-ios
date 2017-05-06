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
        }
    }
    @IBOutlet weak var idField: SkyFloatingLabelTextField! {
        didSet {
            idField.text = friend?.id.base58String
            idField.isUserInteractionEnabled = canEditId
        }
    }
    
    // MARK: - Model
    var friend: Friend? {
        didSet {
            refreshUI()
        }
    }
    
    var delegate: FriendEditDelegate? = nil
    var canEditId: Bool = true {
        didSet {
            idField?.isUserInteractionEnabled = canEditId
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
    }
    
    @objc private func cancel() {
        delegate?.friendEditControllerDidCancel(self)
    }
    
    @objc private func done() {
        guard let name = nameField.text, !name.isEmpty else {
            nameField.errorMessage = "Invalid"
            nameField.becomeFirstResponder()
            return
        }
        
        guard let b58 = idField.text, !b58.isEmpty, let id = MiniLock.Id(fromBase58String: b58) else {
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

extension FriendEditController: UITextViewDelegate {
    
}
