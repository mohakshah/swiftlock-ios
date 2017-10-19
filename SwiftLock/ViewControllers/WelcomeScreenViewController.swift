//
//  WelcomeScreenViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 10/09/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

class WelcomeScreenViewController: UIViewController
{
    @IBAction func next(_ sender: Any) {
        if let pageVC = parent as? LoginPageViewController {
            pageVC.scrollToNext()
        }
    }
}
