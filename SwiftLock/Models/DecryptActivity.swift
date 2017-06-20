//
//  DecryptActivity.swift
//  SwiftLock
//
//  Created by Mohak Shah on 20/06/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import MiniLockCore

class DecryptActivity: UIActivity
{
    override var activityType: UIActivityType? {
        return UIActivityType("Decrypt")
    }
    
    override var activityTitle: String? {
        return Strings.DecryptActivity
    }
    
    override var activityImage: UIImage? {
        return #imageLiteral(resourceName: "decrypt-activity-icon")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        if let url = activityItems.first as? URL {
            if (try? MiniLock.isEncryptedFile(url: url)) ?? false {
                return true
            }
        }
        
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        if let url = activityItems.first as? URL,
            let homeVC = UIApplication.shared.delegate?.window??.rootViewController?.mainVC as? HomeViewController {
            homeVC.handleFile(url: url)
        }
    }
    
    override class var activityCategory: UIActivityCategory {
        return .action
    }
}
