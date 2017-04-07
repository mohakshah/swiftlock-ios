//
//  LoginViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 20/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import zxcvbn_ios
import SkyFloatingLabelTextField
import MiniLockCore

fileprivate struct LocalConstants {
    static let minPassphraseEntropy = 100.00
    static let emailPattern = "^[-0-9a-zA-Z.+_]+@[-0-9a-zA-Z.+_]+\\.[a-zA-Z]{2,20}$"
}

fileprivate struct LocalStrings {
    static let MessageDuringKeyGeneration = "Generating your keys"
}

class LoginViewController: UIViewController {

    // MARK:- Storyboard Outlets/Actions
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var passwordStateSwitch: UIImageView!
    @IBOutlet weak var emailField: SkyFloatingLabelTextField! {
        didSet {
            emailField?.delegate = self
        }
    }
    
    @IBOutlet weak var passwordField: SkyFloatingLabelTextField! {
        didSet {
            passwordField?.delegate = self
        }
    }
    
    @IBAction func performLogin(_ sender: Any) {
        guard validateEmailField() else {
            emailField.becomeFirstResponder()
            return
        }
        
        guard validatePasswordField() else {
            // suggest a password
            passwordField.becomeFirstResponder()
            return
        }
        
        let email = emailField.text!
        let password = passwordField.text!
        
        blockUIForKeyGeneration()
        DispatchQueue.global(qos: .userInteractive).async { [weak weakSelf = self] in
            let keyPair = MiniLock.KeyPair(fromEmail: email, andPassword: password)!
            print(keyPair.publicId)
            DispatchQueue.main.async {
                weakSelf?.unblockUI()
                // TODO: update the global keypair
            }
        }
    }
    
    @IBAction func switchPasswordViewingState(_ sender: Any) {
        passwordStateSwitch.isHighlighted = !passwordStateSwitch.isHighlighted
        passwordField.isSecureTextEntry = !passwordField.isSecureTextEntry
    }
    
    // MARK:- View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // listen for textfield changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(validateEmailField),
                                               name: Notification.Name.UITextFieldTextDidChange,
                                               object: emailField)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(validatePasswordField),
                                               name: Notification.Name.UITextFieldTextDidChange,
                                               object: passwordField)
        
        
        
        // listen for the keyboard activity
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillAppear(notification:)),
                                               name: Notification.Name.UIKeyboardWillShow,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(notification:)),
                                               name: Notification.Name.UIKeyboardWillHide,
                                               object: nil)

    }
    
    override func viewDidLayoutSubviews() {
        scrollView.layoutSubviews()

        // disable scrollbars so they don't interfere during resizing
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        scrollView.contentSize = scrollView.subViewArea()

        // re-enable the scrollbars
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
    }
    
    
    // MARK: UI Blocking
    fileprivate var blockingView: BlockingView?
    
    fileprivate func blockUIForKeyGeneration() {
        if blockingView == nil {
            blockingView = addBlockingView(withMessage: LocalStrings.MessageDuringKeyGeneration)
        }
    }
    
    fileprivate func unblockUI() {
        blockingView?.removeFromSuperview()
        blockingView = nil
    }
}

// MARK: - TextField methods
extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
    
    // checks email validity and updates the errormesssage accordingly
    // returns true if the email is valid
    func validateEmailField() -> Bool {
        if let email = emailField.text,
            isAValidEmail(email) {
            emailField.errorMessage = nil
            return true
        } else {
            emailField.errorMessage = "Invalid email"
            return false
        }
    }
    
    // checks password validity and updates the errormesssage accordingly
    // returns true if the password is valid
    func validatePasswordField() -> Bool {
        if let password = passwordField.text,
            isAStrongEnoughPassword(password) {
            passwordField.errorMessage = nil
            return true
        } else {
            passwordField.errorMessage = "Passphrase is weak"
            return false
        }
    }
    
    // return true if the email string matches regex in LocalConstants.emailPattern
    fileprivate func isAValidEmail(_ email: String) -> Bool {
        if let regex = (try? NSRegularExpression(pattern: LocalConstants.emailPattern, options: [.anchorsMatchLines])),
            let _ = regex.firstMatch(in: email, options: [], range: NSRange(location: 0, length: email.characters.count)) {
            return true
        } else {
            return false
        }
    }
    
    // returns true if the entropy of password > minPassphraseEntropy
    fileprivate func isAStrongEnoughPassword(_ password: String) -> Bool {
        if let entropy = Double(DBZxcvbn().passwordStrength(password, userInputs: [emailField.text ?? ""]).entropy),
            entropy >= LocalConstants.minPassphraseEntropy {
            return true
        } else {
            return false
        }
    }
    
    // resizes the scrollView to adjust to the keyboard appearing
    func keyboardWillAppear(notification: Notification) {
        guard let kbFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey]
            as? NSValue)?.cgRectValue else { return }
        
        // set the content inset
        let keyboardInset = UIEdgeInsetsMake(0, 0, kbFrame.height, 0)
        scrollView.contentInset = keyboardInset
        scrollView.scrollIndicatorInsets = keyboardInset
    }
    
    func keyboardWillHide(notification: Notification) {
        // unset the content inset
        let zeroInset = UIEdgeInsets.zero
        scrollView.contentInset = zeroInset
        scrollView.scrollIndicatorInsets = zeroInset
    }
}
