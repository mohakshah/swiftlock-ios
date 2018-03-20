//
//  UserDatabase.swift
//  SwiftLock
//
//  Created by Mohak Shah on 21/03/18.
//  Copyright © 2018 Mohak Shah. All rights reserved.
//

import Foundation
import ObjectMapper

/// A database that contains an array of the user's friends and the user's preferences.
struct UserDatabase: ImmutableMappable
{
    var friends: [Friend]
    var preferences: UserPreferences

    init() {
        friends = [Friend]()
        preferences = UserPreferences()
    }
    
    init(map: Map) throws {
        friends = try map.value("friends")
        preferences = try map.value("preferences")
    }
    
    func mapping(map: Map) {
        friends     >>> map["friends"]
        preferences >>> map["preferences"]
    }
    
    /// Inserts 'friend', in the friends array, sorted by their 'name' property
    ///
    /// - Parameter friend: Friend to add to the db
    mutating func insertSorted(friend: Friend) {
        for i in 0..<friends.count {
            if friends[i].name.localizedCaseInsensitiveCompare(friend.name) == ComparisonResult.orderedDescending {
                friends.insert(friend, at: i)
                return
            }
        }
        
        friends.append(friend)
    }
}
