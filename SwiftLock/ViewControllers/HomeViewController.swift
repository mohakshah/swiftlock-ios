//
//  HomeViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 08/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import MiniLockCore
import MBProgressHUD

class HomeViewController: UITabBarController
{
    struct SegueIds {
        static let ToLogin = "Home2Login"
        static let ToFriendPicker = "Home2FriendPicker"
    }

    struct Constants {
        static let TemporaryLocations: [URL] = [URL(string: "file://" + NSTemporaryDirectory())!,
                                                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Inbox")]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // register for login and logout notifications
        onLoginCall(#selector(userLoggedIn))
        onLogoutCall(#selector(userLoggedOut))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !CurrentUser.shared.isLoggedIn {
            performSegue(withIdentifier: SegueIds.ToLogin, sender: self)
        }
    }
    
    @objc fileprivate func userLoggedIn() {
        if let _ = presentedViewController as? LoginViewController {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc fileprivate func userLoggedOut() {
        performSegue(withIdentifier: SegueIds.ToLogin, sender: self)
    }
    
    func handleFile(url: URL) {
        guard CurrentUser.shared.isLoggedIn else {
            presentedViewController?.alert(withTitle: Strings.TryingToOpenFileWhenLoggedOut, message: nil)
            return
        }

        if currentFile == nil {
            currentFile = url
        } else {
            do {
                try FileManager.default.removeItem(at: url)
            } catch (let error) {
                print("Error deleting the source file: ", error)
            }

            print("Currently working on another file:", currentFile!)
        }
    }

    fileprivate var currentFile: URL? {
        didSet {
            guard let url = currentFile  else  {
                return
            }
            
            let fileIsEncrypted: Bool
            do {
                fileIsEncrypted = try MiniLock.isEncryptedFile(url: url)
            } catch (let error) {
                print(error)
                return
            }
            
            if fileIsEncrypted {
                decrypt(url)
            } else {
                let semaphore = DispatchSemaphore(value: 0)
                // if a vc is on top, dismiss it first
                if presentedViewController != nil {
                    presentedViewController?.dismiss(animated: true) { semaphore.signal() }
                } else {
                    semaphore.signal()
                }
                
                // wait for dismissal in a background queue
                DispatchQueue(label: "HomeVC.currentFile.didSet").async { [weak self] in
                    semaphore.wait()
                    
                    DispatchQueue.main.async {
                        // segue to the friend picker, it will call the encrypt funciton
                        self?.performSegue(withIdentifier: SegueIds.ToFriendPicker, sender: nil)
                    }
                }
            }
        }
    }
    
    fileprivate var progressHUD: MBProgressHUD? {
        didSet {
            progressHUD?.removeFromSuperViewOnHide = true
            progressHUD?.mode = .annularDeterminate
        }
    }
    
    fileprivate func decrypt(_ url: URL) {
        print("Decrypting...")
        
        progressHUD = MBProgressHUD.showAdded(to: self.view, animated: true)
        progressHUD!.label.text = Strings.DecryptingMessageInProgressHUD
        
        var decryptor: MiniLock.FileDecryptor
        do {
            decryptor = try MiniLock.FileDecryptor(sourceFile: url, recipientKeys: CurrentUser.shared.keyPair!)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.progressHUD?.hide(animated: true)
                self?.alert(withTitle: Strings.ErrorDecryptingFile, message: error as? String)
                self?.currentFile = nil
            }
            
            return
        }
        
        decryptor.processDelegate = self
        
        // go off the main q
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                self?.currentFile = nil
            }

            var decryptedFile: URL
            do {
                 decryptedFile = try decryptor.decrypt(destinationDirectory: CurrentUser.shared.decryptedDir,
                                                       filename: nil,
                                                       deleteSourceFile: HomeViewController.isFileInTemporaryLocation(url: url))
            } catch {
                DispatchQueue.main.async {
                    self?.progressHUD?.hide(animated: true)
                    self?.alert(withTitle: Strings.ErrorDecryptingFile, message: error as? String)
                }
                return
            }
            
            // dispatch back to the main q
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.progressHUD?.hide(animated: true)
                let activityVC = UIActivityViewController(activityItems: [decryptedFile], applicationActivities: nil)
                activityVC.modalPresentationStyle = .popover
                
                strongSelf.present(activityVC, animated: true, completion: nil)
            }
        }
    }
    
    fileprivate func encrypt(_ url: URL, to friends: [Friend]) {
        progressHUD = MBProgressHUD.showAdded(to: self.view, animated: true)
        progressHUD!.label.text = Strings.EncryptingMessageInProgressHUD

        var encryptor: MiniLock.FileEncryptor
        do {
            encryptor = try MiniLock.FileEncryptor(fileURL: url,
                                                   sender: CurrentUser.shared.keyPair!,
                                                   recipients: friends.map { $0.id } )
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.progressHUD?.hide(animated: true)
                self?.alert(withTitle: Strings.ErrorEncryptingFile, message: error as? String)
                self?.currentFile = nil
            }

            return
        }
        
        encryptor.processDelegate = self
        
        // go off the main q
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                self?.currentFile = nil
            }

            var encryptedFile: URL
            do {
                encryptedFile = try encryptor.encrypt(destinationDirectory: CurrentUser.shared.encryptedDir,
                                                      filename: nil,
                                                      deleteSourceFile: HomeViewController.isFileInTemporaryLocation(url: url))
            } catch {
                DispatchQueue.main.async {
                    self?.progressHUD?.hide(animated: true)
                    self?.alert(withTitle: Strings.ErrorEncryptingFile, message: error as? String)
                }

                return
            }
            
            // dispatch back to the main q
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }

                strongSelf.progressHUD?.hide(animated: true)
                let activityVC = UIActivityViewController(activityItems: [encryptedFile], applicationActivities: nil)
                activityVC.modalPresentationStyle = .popover
                
                strongSelf.present(activityVC, animated: true, completion: nil)
            }
        }
    }
    
    fileprivate class func isFileInTemporaryLocation(url: URL) -> Bool {
        let parentDir = url.deletingLastPathComponent()
        return Constants.TemporaryLocations.contains(parentDir)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == SegueIds.ToFriendPicker,
            let friendPicker = segue.destination.mainVC as? FriendPickerViewController {
            friendPicker.delegate = self
        }
    }
}

extension HomeViewController: FriendPickerDelegate {
    func friendPicker(_ picker: FriendPickerViewController, didPickFriends friends: [Friend]) {
        if presentedViewController?.mainVC == picker {
            dismiss(animated: true, completion: nil)
        }

        guard let url = currentFile else {
            return
        }
        
        encrypt(url, to: friends)
    }
    
    func friendPickerDidCancel(_ picker: FriendPickerViewController) {
        if presentedViewController?.mainVC == picker {
            dismiss(animated: true, completion: nil)
            currentFile = nil
        }
    }
}

extension HomeViewController: MiniLockProcessDelegate {
    func setProgress(to progress: Double, process: MiniLockProcess) {
        DispatchQueue.main.async { [weak self] in
            self?.progressHUD?.progress = Float(progress)
        }
    }
}
