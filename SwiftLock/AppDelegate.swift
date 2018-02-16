//
//  AppDelegate.swift
//  SwiftLock
//
//  Created by Mohak Shah on 19/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import libsodium

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // initialize the sodium library
        DispatchQueue.global(qos: .utility).async {
            let ret = sodium_init()
            print("libsodium initialized with return value \(ret)")
        }
        
        UIApplication.shared.delegate?.window??.tintColor = ColorPalette.tint
        UIApplication.shared.delegate?.window??.backgroundColor = ColorPalette.background

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return openFile(url: url)
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        // empty the qrcode cache
        Friend.qrCodeCache.removeAllObjects()
    }
    
    /// Asks HomeVC to handle the file url
    ///
    /// - Parameter url: URL to a _file_
    /// - Returns: returns true if homeVC was successfully handed the url
    func openFile(url: URL) -> Bool {
        if url.isFileURL,
            let homeVC = window?.rootViewController?.mainVC as? HomeViewController {
            homeVC.handleFile(url: url)
            return true
        }
        
        return false
    }
    
    /// Asks HomeVC to start the walkthrough
    func showWalkthrough() {
        if let homeVC = window?.rootViewController?.mainVC as? HomeViewController {
            homeVC.startWalkthrough()
        }
    }
    
    /// Convenience class function for the instance method openFile(url: )
    class func openFile(url: URL) -> Bool {
        return (UIApplication.shared.delegate as! AppDelegate).openFile(url: url)
    }
}

