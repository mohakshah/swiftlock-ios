//
//  IntroCustomPageView.swift
//  SwiftLock
//
//  Created by Mohak Shah on 13/02/18.
//  Copyright © 2018 Mohak Shah. All rights reserved.
//

import UIKit

class IntroCustomPageView: UIView
{
    // MARK: - XIB Outlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textView: UITextView!
    
    // MARK: - Public Interface
    public var image: UIImage? {
        get {
            return imageView?.image
        }

        set {
            imageView?.image = newValue
        }
    }
    
    public var text: String? {
        get {
            return textView?.text
        }
        
        set {
            textView?.text = newValue
        }
    }
}
