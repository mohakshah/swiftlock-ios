//
//  EncryptActivity.swift
//  SwiftLock
//
//  Created by Mohak Shah on 20/06/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import MiniLockCore

class EncryptActivity: UIActivity
{
    override var activityType: UIActivityType? {
        return UIActivityType("Encrypt")
    }
    
    override var activityTitle: String? {
        return Strings.EncryptActivity
    }
    
    override var activityImage: UIImage? {
        return #imageLiteral(resourceName: "encrypt-activity-icon")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        if let url = activityItems.first as? URL {
            if (try? !MiniLock.isEncryptedFile(url: url)) ?? false {
                return true
            }
        }
        
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        if let url = activityItems.first as? URL {
            _ = AppDelegate.openFile(url: url)
        }
    }
    
    override class var activityCategory: UIActivityCategory {
        return .action
    }
}
