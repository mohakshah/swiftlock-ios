//
//  LoginPageViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 10/09/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

class LoginPageViewController: UIPageViewController {
    struct Constants {
        static let pageIds = ["Welcome Screen", "Login Screen"]
        static let NotFirstLoginUserDefaultsKey = "LoginPageVC.NotFirstLogin"
    }

    // MARK: Model
    fileprivate lazy var pages: [UIViewController] = {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return Constants.pageIds.map { storyboard.instantiateViewController(withIdentifier: $0) }
    }()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = self
        
        // Show the Welcome screen on the first display and Login screen on consecutive displays 
        if let firstVC = (isFirstLogin ? pages.first : pages.last) {
            setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
        }
        
        // change color of the indicator dots
        let appearance = UIPageControl.appearance()
        appearance.pageIndicatorTintColor = UIColor.lightGray
        appearance.currentPageIndicatorTintColor = UIColor.darkGray
    }
    
    fileprivate var isFirstLogin: Bool {
        if UserDefaults.standard.bool(forKey: Constants.NotFirstLoginUserDefaultsKey) {
            return false
        } else {
            UserDefaults.standard.set(true, forKey: Constants.NotFirstLoginUserDefaultsKey)
            return true
        }
    }
    
    func scrollToNext() {
        if let currentVC = self.viewControllers?.first,
            let vcIndex = pages.index(of: currentVC), vcIndex != pages.count - 1 {
            setViewControllers([pages[vcIndex + 1]], direction: .forward, animated: true, completion: nil)
        }
    }
}

// MARK: - UIPageViewControllerDataSource
extension LoginPageViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let vcIndex = pages.index(of: viewController), vcIndex != pages.count - 1 {
            return pages[vcIndex + 1]
        }
        
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let vcIndex = pages.index(of: viewController), vcIndex != 0 {
            return pages[vcIndex - 1]
        }
        
        return nil
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pages.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        if let firstVC = pageViewController.viewControllers?.first,
            let index = pages.index(of: firstVC) {
            return index
        }
        
        return 0
    }
}
