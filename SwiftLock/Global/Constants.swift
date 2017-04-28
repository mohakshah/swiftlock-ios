//
//  Constants.swift
//  SwiftLock
//
//  Created by Mohak Shah on 22/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

struct ColorPalette {
    static let tint = UIColor(fromHex: [Character]("64c897".characters))
    static let background = UIColor(red:0.86, green:0.89, blue:0.93, alpha:1.0)
    static let logo = UIColor(red:0.24, green:0.49, blue:0.69, alpha:1.0)
    
    static let defaultColor = UIColor.white
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

extension UIColor {
    convenience init(fromHex hex: [Character]) {
        guard hex.count == 6 else {
            self.init(white: 1.0, alpha: 1.0)
            return
        }
        
        guard let r = Int(String(hex[0..<2]), radix: 16),
            let g = Int(String(hex[2..<4]), radix: 16),
            let b = Int(String(hex[4..<6]), radix: 16) else {
                self.init(white: 1.0, alpha: 1.0)
                return
        }
        
        self.init(red: CGFloat(r) / 255.0,
                  green: CGFloat(g) / 255.0,
                  blue: CGFloat(b) / 255.0,
                  alpha: 1.0)
    }
}
