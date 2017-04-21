//
//  Constants.swift
//  SwiftLock
//
//  Created by Mohak Shah on 22/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

struct ColorPalette {
    static let tint = UIColor(red:0.95, green:0.45, blue:0.00, alpha:1.0)
    static let background = UIColor(red:0.86, green:0.89, blue:0.93, alpha:1.0)
    static let logo = UIColor(red:0.24, green:0.49, blue:0.69, alpha:1.0)
}

struct NotificationNames {
    static let UserLoggedIn = "SLUserDidLogin"
    static let UserLoggedOut = "SLUserDidLogout"
}

struct BinarySizes {
    static let KB = 1 << 10
    static let MB = 1 << 20
    static let GB = 1 << 30
}
