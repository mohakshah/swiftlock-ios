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
    
    @IBOutlet weak var scrollView: UIScrollView!

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
}
