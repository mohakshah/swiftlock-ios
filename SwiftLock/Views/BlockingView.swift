//
//  BlockingView.swift
//  SwiftLock
//
//  Created by Mohak Shah on 07/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

class BlockingView: UIView {

    @IBOutlet weak var outerBox: UIView! {
        didSet {
            outerBox.layer.cornerRadius = 5.0
            outerBox.layer.masksToBounds = true
        }
    }

    @IBOutlet weak var messageLabel: UILabel! {
        didSet {
            messageLabel.text = message
        }
    }
    
    public var message: String? = nil {
        didSet {
            messageLabel?.text = message
        }
    }
}
