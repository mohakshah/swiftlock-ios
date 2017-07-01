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


class LoginViewController: UIViewController
{
    struct SegueIds {
        static let ToSuggester = "Login2Suggester"
    }

    struct Constants {
        static let minPassphraseEntropy = 100.00
        static let emailPattern = "^[-0-9a-zA-Z.+_]+@[-0-9a-zA-Z.+_]+\\.[a-zA-Z]{2,20}$"
    }
    
    struct Strings {
        static let MessageDuringKeyGeneration = "Generating your keys"
        static let KeyGenerationFailedTitle = "Key generation failed"
        static let KeyGenerationFailedMessage = "Key generation requires 128 MB of memory. You may be able to free up some memory by force quitting other apps."
    }

    // MARK:- Storyboard Outlets/Actions
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var passwordStateSwitch: UIImageView!
    @IBOutlet weak var emailField: SkyFloatingLabelTextField! {
        didSet {
            emailField?.delegate = self
            
            // populate with test email
            #if DEBUG
                emailField?.text = "example@example.com"
            #endif
        }
    }
    
    @IBOutlet weak var passwordField: SkyFloatingLabelTextField! {
        didSet {
            passwordField?.delegate = self
            
            // populate with test password
            #if DEBUG
                passwordField?.text = "demolished protocol climbs woodcut ampere"
            #endif
        }
    }
    
    @IBAction func performLogin(_ sender: Any) {
        guard validateEmailField() else {
            emailField.becomeFirstResponder()
            return
        }
        
        guard validatePasswordField() else {
            passwordField.becomeFirstResponder()
            return
        }
        
        let email = emailField.text!
        let password = passwordField.text!
        
        blockUIForKeyGeneration()
        
        // go off the main Q
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            // try and generate a MiniLock.KeyPair from the email and password that the user entered
            guard let keyPair = MiniLock.KeyPair(fromEmail: email, andPassword: password) else {
                DispatchQueue.main.async {
                    // unblock the UI and alert the user
                    self?.unblockUI()
                    self?.alert(withTitle: Strings.KeyGenerationFailedTitle, message: Strings.KeyGenerationFailedMessage)
                }
                
                return
            }

            #if DEBUG
                print(keyPair.publicId)
            #endif
            
            // login with the keypair we just generated and unblock the UI
            CurrentUser.shared.login(withKeyPair: keyPair, email: email)
            DispatchQueue.main.async {
                self?.unblockUI()
            }
        }
    }
    
    @IBAction func switchPasswordViewingState(_ sender: Any) {
        // inverts the state of passwordField's secureTextEntry and passwordStateSwitch's highlight
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
        super.viewDidLayoutSubviews()
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
            blockingView = addBlockingView(withMessage: Strings.MessageDuringKeyGeneration)
        }
    }
    
    fileprivate func unblockUI() {
        blockingView?.removeFromSuperview()
        blockingView = nil
    }
    
    // MARK: Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == SegueIds.ToSuggester, let navVC = segue.destination as? UINavigationController, let suggesterVC = navVC.mainVC as? PassphraseSuggesterViewController {
            // set self as the delegate
            suggesterVC.delegate = self
            
            // setup the modal presentation to show a popover even in a CompactWidth environment
            navVC.modalPresentationStyle = .popover
            navVC.preferredContentSize = CGSize(width: 256, height: 128)
            
            // setup the popover presentation
            if let ppc = navVC.popoverPresentationController {
                ppc.delegate = self
                ppc.permittedArrowDirections = .any
                if let view = sender as? UIView {
                    ppc.sourceView = view.superview
                    ppc.sourceRect = view.frame
                }
            }
        }
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
            passwordField.errorMessage = "Passphrase is weak. Try one of the suggested passphrases."
            return false
        }
    }
    
    // return true if the email string matches regex in LocalConstants.emailPattern
    fileprivate func isAValidEmail(_ email: String) -> Bool {
        if let regex = (try? NSRegularExpression(pattern: Constants.emailPattern, options: [.anchorsMatchLines])),
            let _ = regex.firstMatch(in: email, options: [], range: NSRange(location: 0, length: email.characters.count)) {
            return true
        } else {
            return false
        }
    }
    
    // returns true if the entropy of password > minPassphraseEntropy
    fileprivate func isAStrongEnoughPassword(_ password: String) -> Bool {
        if let entropy = Double(DBZxcvbn().passwordStrength(password, userInputs: [emailField.text ?? ""]).entropy),
            entropy >= Constants.minPassphraseEntropy {
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

// MARK: - PassphraseSuggesterDelegate
extension LoginViewController: PassphraseSuggesterDelegate {
    func passphraseSuggester(_ suggester: PassphraseSuggesterViewController, didSelectPassword password: String) {
        // make sure its the right controller before dismissing
        guard presentedViewController?.mainVC == suggester else {
            return
        }
        
        dismiss(animated: true, completion: nil)
        
        // update the password field and error messages
        self.passwordField.text = password
        _ = validatePasswordField()
        
        // show the selected passphrase
        if self.passwordField.isSecureTextEntry {
            self.switchPasswordViewingState(self)
        }
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension LoginViewController: UIPopoverPresentationControllerDelegate {
    // This is to make sure that the popover does not expand to full screen even in a CompactWidth environment
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
