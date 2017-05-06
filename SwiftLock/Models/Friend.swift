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
    let name: String
    let id: MiniLock.Id
    
    init(name: String, id: MiniLock.Id) {
        self.name = name
        self.id = id
    }
    
    init(map: Map) throws {
        name = try map.value("name")
        
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
    
    static let qrCodeCache = NSCache<NSString, CIImage>()
    
    func qrCode(ofSize size: CGSize) -> UIImage? {
        if let ciImage = qrCode() {
            let transform = CGAffineTransform(scaleX: size.width / ciImage.extent.size.width,
                                              y: size.height / ciImage.extent.size.height)
            return UIImage(ciImage: ciImage.applying(transform))
        }

        return nil
    }
    
    func qrCode() -> CIImage? {
        let scheme = qrCodeScheme()
        if let ciImage = Friend.qrCodeCache.object(forKey: scheme as NSString) {
            return ciImage
        }

        let filter = CIFilter(name: "CIQRCodeGenerator")!
        let data = Data(scheme.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let ciImage = filter.outputImage {
            Friend.qrCodeCache.setObject(ciImage, forKey: scheme as NSString)
            return ciImage
        }
        
        return nil
    }
    
    func qrCodeScheme() -> String {
        let escapedName = name.replacingOccurrences(of: ";", with: "\\;")
        return "SL:N:" + escapedName + ";I:" + id.base58String + ";;"
    }
}
