# MiniLockCore
[![CI Status](http://img.shields.io/travis/mohakshah/MiniLockCore.svg?style=flat)](https://travis-ci.org/mohakshah/MiniLockCore)
[![Version](https://img.shields.io/cocoapods/v/MiniLockCore.svg?style=flat)](http://cocoapods.org/pods/MiniLockCore)
[![License](https://img.shields.io/cocoapods/l/MiniLockCore.svg?style=flat)](http://cocoapods.org/pods/MiniLockCore)
[![Platform](https://img.shields.io/cocoapods/p/MiniLockCore.svg?style=flat)](http://cocoapods.org/pods/MiniLockCore)

## About

The library is an implementation of miniLock's core functionalities in Swift. It provides a modern Swift API to miniLock tasks such as user key management, file encryption, decryption, etc. There are also methods which allow encrypting data from memory and decrypting data to memory to completely avoid writing plain text to the disk. It was originally written for the [SwiftLock app](https://github.com/mohakshah/swiftlock-ios), but it can be used as a plugin component in any other app wanting to use miniLock's modern and future-proof encryption scheme.

## Requirements

v1.x requires Xcode 9+. For Xcode 8, use the v0.9.x.
Although the code is not written to be iOS dependent, so far, the library has been only tested to work on iOS devices. Testing for macOS, watchOS and tvOS are pending. Any contributions here are welcome.

## Installation

MiniLockCore is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "MiniLockCore", '~> 1.0'
```

## Usage

### Generate a user's keypair:
```swift
import MiniLockCore

let keyPair = MiniLock.KeyPair(fromEmail: email, andPassword: password)!
```

### Encrypt a file:
```swift
do {
    let encryptor = try MiniLock.FileEncryptor(fileURL: urlOfSourceFile,
                                               sender: CurrentUser.keyPair!,
                                               recipients: [recipientId1, recipientId2] )

    let encryptedFileURL = try encryptor.encrypt(destinationDirectory: urlOfDestinationDirectory,
                                                 filename: "foo.miniLock",
                                                 deleteSourceFile: false)
} catch {
    print("Error encrypting:", error)
}
```

## Author

Mohak Shah

## License

MiniLockCore is available under the MIT license. See the LICENSE file for more info.
