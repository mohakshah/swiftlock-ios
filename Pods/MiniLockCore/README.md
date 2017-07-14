# MiniLockCore

[![Version](https://img.shields.io/cocoapods/v/MiniLockCore.svg?style=flat)](http://cocoapods.org/pods/MiniLockCore)
[![License](https://img.shields.io/cocoapods/l/MiniLockCore.svg?style=flat)](http://cocoapods.org/pods/MiniLockCore)
[![Platform](https://img.shields.io/cocoapods/p/MiniLockCore.svg?style=flat)](http://cocoapods.org/pods/MiniLockCore)

## About

The library is a swift implementation of miniLock's core functionalities. It was originally written for the SwiftLock app, but can be used as a plugin system in any other app wanting to use the modern and future-proof encryption scheme of miniLock.

## Requirements

So far, the library has been only tested to work on iOS devices. Testing for macOS, watchOS and tvOS are pending. Any contributions here are welcome.

## Installation

MiniLockCore is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "MiniLockCore", '~> 0.9'
```

## Usage

### Generating a user's keypair:

```swift
import MiniLockCore

let keyPair = MiniLock.KeyPair(fromEmail: email, andPassword: password)!
```
### Encrypt a file

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
