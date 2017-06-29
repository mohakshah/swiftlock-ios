//
//  Strings.swift
//  SwiftLock
//
//  Created by Mohak Shah on 22/03/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import Foundation

struct Strings {
    static let OK = "O.K."
    static let Delete = "Delete"
    static let InvalidQRCode = "Invalide QR Code"
    static let TryAgain = "Please try again!"
    static let ScanQRCode = "Scan QR Code"
    static let EnterManually = "Enter Manually"
    static let Cancel = "Cancel"
    static let Accept = "Accept"
    
    static let EncryptActivity = "Encrypt"
    static let DecryptActivity = "Decrypt"
    
    static let DecryptingMessageInProgressHUD = "Decrypting File"
    static let EncryptingMessageInProgressHUD = "Encrypting File"
    static let ErrorEncryptingFile = "Error trying to encrypt the file"
    static let ErrorDecryptingFile = "Error trying to decrypt the file"
    
    static let TryingToOpenFileWhenLoggedOut = "You must first log in to encrypt/decrypt a file"
    
    static let IconCredits = "File List icon by Chanut is Industries from flaticons.com." + "\n\n" +
        "Multiple-User icon by Freepik from flaticons.com." + "\n\n" +
        "Settings, Lock and Unlock icon are from https://icons8.com/" + "\n\n" +
        "FileTypeIcons by Roundicons from flaticons.com"
    
    static let PhotoLibrary = "Photo Library"
    static let Camera = "Camera"
    
    static let PhotoLibraryAuthorizationRestrictedTitle = "Error opening the photo library"
    static let PhotoLibraryAuthorizationRestrictedMessage = "Your organization has restricted this app's access to the photo library."
    static let PhotoLibraryAuthorizationDeniedTitle = "Error opening the photo library"
    static let PhotoLibraryAuthorizationDeniedMessage = "To allow this app to open the photo library, go to iPhone's Settings→Privacy→Photos and turn on access to this app."
    
    static let CameraAuthorizationRestrictedTitle = "Error opening the camera"
    static let CameraAuthorizationRestrictedMessage = "Your organization has restricted this app's access to the camera."
    static let CameraAuthorizationDeniedTitle = "Error opening the camera"
    static let CameraAuthorizationDeniedMessage = "To allow this app to open the camera, go to iPhone's Settings→Privacy→Camera and turn on access to this app."
}
