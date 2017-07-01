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
        // return true if the first item in activityItems is a URL to a file not encrypted by miniLock
        if let url = activityItems.first as? URL {
            if (try? MiniLock.isEncryptedFile(url: url)) ?? false {
                return true
            }
        }
        
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        // let AppDelegate handle the file
        if let url = activityItems.first as? URL {
            _ = AppDelegate.openFile(url: url)
        }
    }
    
    override class var activityCategory: UIActivityCategory {
        return .action
    }
}
