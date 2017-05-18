//
//  PassphraseSuggesterViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 18/05/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import libsodium

protocol PassphraseSuggesterDelegate {
    func passphraseSuggester(_ suggester: PassphraseSuggesterViewController, didSelectPassword password: String)
}

class PassphraseSuggesterViewController: UIViewController
{
    static let NavVCStoryboardId = "PassphraseSuggesterNavigationController"
    
    // MARK: - Storyboard outlets
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var passphraseField: UILabel!
    
    // MARK: - properties
    fileprivate lazy var wordList: [String] = {
        if let url = Bundle.main.url(forResource: "Words", withExtension: "plist"),
            let words = NSArray(contentsOf: url) as? [String] {
            return words
        }
        
        // in case of error, return an empty array
        return [String]()
    }()

    var delegate: PassphraseSuggesterDelegate?
    var wordsToSelect = 7
    
    // MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // add bar button items
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: Strings.Accept, style: .plain, target: self, action: #selector(accept))

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(generateNewPassphrase))
        
        // display a password after loading
        generateNewPassphrase()
    }
    
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
    
    @objc fileprivate func accept() {
        if let password = passphraseField.text, !password.isEmpty {
            delegate?.passphraseSuggester(self, didSelectPassword: password)
        }
    }
    
    @objc fileprivate func generateNewPassphrase() {
        if wordList.isEmpty {
            return
        }

        // add "wordsToSelect" no. of words to an array
        var words = [String]()
        for _ in 0..<wordsToSelect {
            let random = Int(randombytes_uniform(UInt32(wordList.count)))
            words.append(wordList[random])
        }
        
        // suggest the concatenation of those words
        passphraseField.text = words.joined(separator: " ")
    }
    
}
