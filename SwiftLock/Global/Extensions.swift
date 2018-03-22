//
//  GlobalExtensions.swift
//  SwiftLock
//
//  Created by Mohak Shah on 06/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import MiniLockCore

// MARK: - UIView extension
extension UIView {
    func subViewArea() -> CGSize {
        var rect = CGRect.zero
        for subview in subviews {
            rect = rect.union(subview.frame)
        }
        
        return rect.size
    }
}

// MARK: - UIViewController
extension UIViewController
{
    /// Presents an UIAlertController with a title, message and an O.K. button that dismisses the alert
    ///
    /// - Parameters:
    ///   - title: Title of the alert
    ///   - message: Detailed message of the alert
    func alert(withTitle title: String, message: String?) {
        DispatchQueue.main.async { [weak weakSelf = self] in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Strings.OK, style: .cancel, handler: nil))
            
            weakSelf?.present(alert, animated: true, completion: nil)
        }
    }
    
    /// Calls dismiss on presenting VC
    func dismissSelf() {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    /// Adds a BlockingView with a message to the root view of self
    ///
    /// - Parameter message: The message to display in the view
    /// - Returns: Returns the BlockingView that was just added.
    func addBlockingView(withMessage message: String?) -> BlockingView? {
        if let blockingView = Bundle.main.loadNibNamed("BlockingView", owner: nil, options: nil)?.first as? BlockingView {
            blockingView.frame = view.bounds
            blockingView.message = message
            view.addSubview(blockingView)
            return blockingView
        }
        
        return nil
    }
    
    /// If self is a UINavigationController, returns the rootVC of self. Otherwise returns slef
    var mainVC: UIViewController {
        if let rootVC = (self as? UINavigationController)?.viewControllers.first {
            return rootVC
        }
        
        return self
    }
    
    /// Adds an observer in notification center for notification named 'NotificationNames.UserLoggedIn'
    ///
    /// - Parameter selector: The selector called when the notification is broadcast
    func onLoginCall(_ selector: Selector) {
        NotificationCenter.default.addObserver(self,
                                               selector: selector,
                                               name: Notification.Name(NotificationNames.UserLoggedIn),
                                               object: nil)
    }
    
    /// Adds an observer in notification center for notification named 'NotificationNames.UserLoggedOut'
    ///
    /// - Parameter selector: The selector called when the notification is broadcast
    func onLogoutCall(_ selector: Selector) {
        NotificationCenter.default.addObserver(self,
                                               selector: selector,
                                               name: Notification.Name(NotificationNames.UserLoggedOut),
                                               object: nil)
    }
}



extension String {
    /// Adds 'seperator' after every 'n' characters in self
    /// courtesy: http://stackoverflow.com/a/34454633/4590902
    ///
    /// - Parameters:
    ///   - seperator: The string to insert after 'n' characters
    ///   - n: No. of characters to group
    /// - Returns: The string with seperators inserted
    func adding(seperator: String, afterCharacters n: Int) -> String {
        var seperatedString = ""
        
        let characters = [Character](self)
        
        stride(from: 0, to: characters.count, by: n).forEach { (start) in
            if start > 0 {
                seperatedString += seperator
            }
            
            seperatedString += String(characters[start..<min(start + n, characters.count)])
        }
        
        return seperatedString
    }
}

extension UIColor {
    /// Initializes a UIColor object from an array of RGB hex characters with alpha channel set to 1.0.
    ///
    /// - Parameter hex: An array of 6 hex characters such as [f, f, 0, 0, f, f]
    /// Note: if the input is invalid, a UIColor(white: 1.0, alpha: 1.0) is returned
    convenience init(fromHex hex: [Character]) {
        guard hex.count == 6 else {
            self.init(white: 1.0, alpha: 1.0)
            return
        }
        
        guard let r = Int(String(hex[0..<2]), radix: 16),
            let g = Int(String(hex[2..<4]), radix: 16),
            let b = Int(String(hex[4..<6]), radix: 16) else {
                self.init(white: 1.0, alpha: 1.0)
                return
        }
        
        self.init(red: CGFloat(r) / 255.0,
                  green: CGFloat(g) / 255.0,
                  blue: CGFloat(b) / 255.0,
                  alpha: 1.0)
    }
}

/// Verbose description of the errors
extension MiniLock.Errors: LocalizedError {
    public var errorDescription: String? {
        // use the builtin English descriptions
        return NSLocalizedString(String(describing: self), comment: "")
    }
}
