//
//  HomeViewController+Walkthrough.swift
//  SwiftLock
//
//  Created by Mohak Shah on 04/03/18.
//  Copyright © 2018 Mohak Shah. All rights reserved.
//

import Foundation
import EAIntroView

// Walkthrough related methods
extension HomeViewController
{
    fileprivate struct Constants {
        /// Tuples of images and text that are to be displayed during the intro walkthrough
        static let IntroImageTextPairs: [(UIImage, String)] = [
            (#imageLiteral(resourceName: "Screen 1.jpg"), "Share your id with your friends from the “Friends” tab. Ask them to scan the QR Code or   use the “Share” button to share via Twitter, email, etc."),
            (#imageLiteral(resourceName: "Screen 2.jpg"), "Scan your friends’ QR Codes to send them encrypted files."),
            (#imageLiteral(resourceName: "Screen 3.jpg"), "Tap ‘+’ button on the “Files” tab to pick a photo from your library and encrypt it. Optionally, open files in SwiftLock using the “Share Sheet” from other apps to encrypt those files."),
            (#imageLiteral(resourceName: "Screen 4.jpg"), "Next, select the recipients. These are the people who will be able to decrypt the file. Keep “Me” checked so that you yourself can decrypt the file in the future."),
            (#imageLiteral(resourceName: "Screen 5.jpg"), "Tap on the encrypted file’s name to share it via a medium of your choice."),
            (#imageLiteral(resourceName: "Screen 6.jpg"), "If you receive an encrypted file from your friend, open it in SwiftLock using the “Share Sheet” to decrypt it.")
        ]
    }
        
    /// Starts the intro walkthrough
    func startWalkthrough() {
        var introPages = [EAIntroPage]()
        
        for (image, text) in Constants.IntroImageTextPairs {
            let page = EAIntroPage(customViewFromNibNamed: "IntroCustomPageView")!
            guard let introView = page.customView as? IntroCustomPageView else {
                break
            }
            
            introView.image = image
            introView.text = text
            
            introPages.append(page)
        }
        
        guard let introView = EAIntroView(frame: view.bounds, andPages: introPages) else {
            print("Failed to initialize EAIntroView")
            return
        }
        
        introView.backgroundColor = UIColor(red:0.24, green:0.49, blue:0.69, alpha:1.0)
        
        introView.show(in: view)
    }
}
