//
//  GlobalExtensions.swift
//  Frainz-iOS
//
//  Created by Mohak Shah on 06/03/17.
//  Copyright © 2017 Frainz. All rights reserved.
//

import UIKit


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
    func alert(withTitle title: String, message: String?) {
        DispatchQueue.main.async { [weak weakSelf = self] in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Strings.OK, style: .cancel, handler: nil))
            
            weakSelf?.present(alert, animated: true, completion: nil)
        }
    }
    
    func dismissSelf() {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func addBlockingView(withMessage message: String?) -> BlockingView? {
        if let blockingView = Bundle.main.loadNibNamed("BlockingView", owner: nil, options: nil)?.first as? BlockingView {
            blockingView.frame = view.bounds
            blockingView.message = message
            view.addSubview(blockingView)
            return blockingView
        }
        
        return nil
    }
    
    var mainVC: UIViewController {
        if let rootVC = (self as? UINavigationController)?.viewControllers.first {
            return rootVC
        }
        
        return self
    }
    
    func onLoginCall(_ selector: Selector) {
        let loginNotification = Notification.Name(NotificationNames.UserLoggedIn)
        
        NotificationCenter.default.addObserver(self,
                                               selector: selector,
                                               name: loginNotification,
                                               object: nil)
    }
    
    func onLogoutCall(_ selector: Selector) {
        let logoutNotification = Notification.Name(NotificationNames.UserLoggedOut)
        
        NotificationCenter.default.addObserver(self,
                                               selector: selector,
                                               name: logoutNotification,
                                               object: nil)
    }
}



extension String {
    // courtesy: http://stackoverflow.com/a/34454633/4590902
    func adding(seperator: String, afterCharacters n: Int) -> String {
        var seperatedString = ""
        
        let characters = [Character](self.characters)
        
        stride(from: 0, to: characters.count, by: n).forEach { (start) in
            if start > 0 {
                seperatedString += seperator
            }
            
            seperatedString += String(characters[start..<min(start + n, characters.count)])
        }
        
        return seperatedString
    }
}
