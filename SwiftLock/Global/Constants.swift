//
//  Constants.swift
//  SwiftLock
//
//  Created by Mohak Shah on 22/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

struct ColorPalette {
    static let tint = UIColor(fromHex: [Character]("64c897"))
    static let background = UIColor.white
    static let logo = UIColor(red:0.24, green:0.49, blue:0.69, alpha:1.0)
    
    static let defaultColor = UIColor.white
}

struct NotificationNames {
    static let UserLoggedIn = "SLUserDidLogin"
    static let UserLoggedInForTheFirstTime = "SLUserDidLoginFirstTime"
    static let UserLoggedOut = "SLUserDidLogout"
}
