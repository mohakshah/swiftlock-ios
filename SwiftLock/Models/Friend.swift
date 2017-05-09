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

struct Friend: Mappable {
    private var _name: String!
    private var _id: MiniLock.Id!
    
    var name: String {
        return _name
    }
    var id: MiniLock.Id {
        return _id
    }

    init(name: String, id: MiniLock.Id) {
        self._name = name
        self._id = id
    }
    
    // MARK: - JSON Mapping
    
    init?(map: Map) {
        if map.JSON["name"] == nil || map.JSON["id"] == nil {
            return nil
        }
    }

    mutating func mapping(map: Map) {
        _name   <- map["name"]
        _id     <- (map["id"], Friend.id2B58Transform)
    }
    
    static let id2B58Transform = TransformOf<MiniLock.Id, String>(fromJSON: { (string) -> MiniLock.Id? in
        guard let string = string else {
            return nil
        }
        return MiniLock.Id(fromBase58String: string)
    }, toJSON: { (id) -> String? in
        return id?.base58String
    })
    
    // MARK: - QRCode Encoding
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
        let escapedName = name.replacingOccurrences(of: ";", with: "\\;").replacingOccurrences(of: ":", with: "\\:")
        return "SL:N:" + escapedName + ";I:" + id.base58String + ";;"
    }
    
    // MARK: - QRCode Decoding
    private static let b58Digits = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    
    private static let pattern = "^(?:SL:)(?:N:)" // (tags) match "SL:N:" but _don't_include_ in results

                        // (Name) match 1 or more characters except ':' & ';'. Those characters are accepted only if escaped with '\'
                        + "((?:(?:\\\\(?:[;:]))|(?:[^:;]))+)"
        
                        // (tags) match ";I:" but _don't_include_ in results
                        + "(?:;I:)"
        
                        // (Id) match 1 or more base58 characters
                        + "([" + b58Digits + "]+)"
        
                        // (tags) match the ending ";;" but _don't_include_ in results
                        + "(?:;;)$"
    
    private static let qrCodeSchemeRegex = try! NSRegularExpression(pattern: pattern, options: [])
    
    static func decodeQRCodeScheme(_ scheme: String) -> (name: String, id: MiniLock.Id)? {
        guard let match = qrCodeSchemeRegex.firstMatch(in: scheme,
                                                       options: [],
                                                       range: NSRange(location: 0, length: scheme.characters.count)) else {
                                                        return nil
        }
        
        guard match.numberOfRanges == 3 else {
            return nil
        }

        let name = (scheme as NSString).substring(with: match.rangeAt(1))
                                        .replacingOccurrences(of: "\\;", with: ";")
                                        .replacingOccurrences(of: "\\:", with: ":")
        
        let b58 = (scheme as NSString).substring(with: match.rangeAt(2))
        guard let id = MiniLock.Id(fromBase58String: b58) else {
            return nil
        }
        
        
        return (name, id)
    }
    
    init?(fromQRCodeScheme scheme: String) {
        guard let (name, id) = Friend.decodeQRCodeScheme(scheme) else {
            return nil
        }
        
        self._name = name
        self._id = id
    }
}
