//
//  Friend.swift
//  SwiftLock
//
//  Created by Mohak Shah on 25/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation
import MiniLockCore
import ObjectMapper

struct Friend: ImmutableMappable {
    let name: String?
    let id: MiniLock.Id
    
    init(map: Map) throws {
        name = try? map.value("name")
        
        // decode id from the base58 String
        let b58Id: String = try map.value("id")
        guard let id = MiniLock.Id(fromBase58String: b58Id) else {
            throw MapError(key: "id", currentValue: b58Id, reason: "Corrupt base58 encoded string")
        }
        
        self.id = id
    }
    
    func mapping(map: Map) {
        name            >>> map["name"]
        id.base58String >>> map["id"]
    }
}
