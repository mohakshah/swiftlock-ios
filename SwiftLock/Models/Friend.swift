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

/// Structure that holds a person's name and MiniLock Id
struct Friend: ImmutableMappable {
    let name: String
    let id: MiniLock.Id

    init(name: String, id: MiniLock.Id) {
        self.name = name
        self.id = id
    }
    
    // MARK: - JSON Mapping
    
    init(map: Map) throws {
        name = try map.value("name")
        let idString: String = try map.value("id")
        
        guard let id = MiniLock.Id(fromBase58String: idString) else {
            throw MapError(key: nil, currentValue: nil, reason: nil)
        }
        
        self.id = id
    }
    
    func mapping(map: Map) {
        name >>> map["name"]
        id.base58String >>> map["id"]
    }
    
    // MARK: - QRCode Encoding
    
    // Cache to hold the qrcodes
    static let qrCodeCache = NSCache<NSString, CIImage>()
    
    /// Generates a QRCode image of this friend
    ///
    /// - Parameter size: Dimension of the required QR Code
    /// - Returns: UIImage of the qrCode generated or nil in case of error
    func qrCode(ofSize size: CGSize) -> UIImage? {
        // get the CIImage version of the QR Code
        if let ciImage = qrCodeCI {
            // transform the CIImage to the requested dimensions and return the UIImage
            let transform = CGAffineTransform(scaleX: size.width / ciImage.extent.size.width,
                                              y: size.height / ciImage.extent.size.height)

            return UIImage(ciImage: ciImage.applying(transform))
        }

        return nil
    }

    /// CIImage of the friend's qrCode or nil in case of error
    var qrCodeCI: CIImage? {
        // check if the CIImage is already in 'qrCodeCache'
        let scheme = qrCodeScheme
        if let ciImage = Friend.qrCodeCache.object(forKey: scheme as NSString) {
            // return the cached version
            return ciImage
        }

        // create a new CIImage
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        let data = Data(scheme.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let ciImage = filter.outputImage {
            // add it to cache and return it
            Friend.qrCodeCache.setObject(ciImage, forKey: scheme as NSString)
            return ciImage
        }
        
        return nil
    }

    /// Returns the friend's name and base58 id encoded in the scheme used for generating QRCode
    fileprivate var qrCodeScheme: String {
        let escapedName = name.replacingOccurrences(of: ";", with: "\\;").replacingOccurrences(of: ":", with: "\\:")
        return "SL:N:" + escapedName + ";I:" + id.base58String + ";;"
    }
    
    // MARK: - QRCode Decoding
    private static let b58Digits = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    
    /// The pattern to use for parsing the QR Code scheme
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
    
    /// Decodes 'scheme' and returns the name and MiniLock id stored in it
    ///
    /// - Parameter scheme: The scheme retrieved from the QR Code
    /// - Returns: name and id encoded in the stream
    static func decodeQRCodeScheme(_ scheme: String) -> (name: String, id: MiniLock.Id)? {
        // match the whole string
        guard let match = qrCodeSchemeRegex.firstMatch(in: scheme,
                                                       options: [],
                                                       range: NSRange(location: 0, length: scheme.characters.count)) else {
                                                        return nil
        }
        
        // make sure no. of matches is as expectd
        guard match.numberOfRanges == 3 else {
            return nil
        }

        // extract name
        let name = (scheme as NSString).substring(with: match.rangeAt(1))
                                        .replacingOccurrences(of: "\\;", with: ";")
                                        .replacingOccurrences(of: "\\:", with: ":")
        
        // extract base58 id string
        let b58 = (scheme as NSString).substring(with: match.rangeAt(2))
        
        // create an id object
        guard let id = MiniLock.Id(fromBase58String: b58) else {
            return nil
        }
        
        
        return (name, id)
    }
    
    init?(fromQRCodeScheme scheme: String) {
        guard let (name, id) = Friend.decodeQRCodeScheme(scheme) else {
            return nil
        }
        
        self.name = name
        self.id = id
    }
}
