//
//  UserPreferences.swift
//  SwiftLock
//
//  Created by Mohak Shah on 20/03/18.
//  Copyright © 2018 Mohak Shah. All rights reserved.
//

import Foundation
import ObjectMapper

/// Struct that hold's a user's preferences
struct UserPreferences: Mappable
{
    var name: String? = nil

    init() {
        
    }

    init?(map: Map) {
        
    }
    
    mutating func mapping(map: Map) {
        name    <- map["name"]
    }
}
