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

    // MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()

        // register for login and logout notifications
        onLoginCall(#selector(userLoggedIn))
        onLogoutCall(#selector(userLoggedOut))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // segue to loginVC if no one's logged in
        if !CurrentUser.shared.isLoggedIn {
            performSegue(withIdentifier: SegueIds.ToLogin, sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // set self as the delegate of FriendPickerViewController
        if segue.identifier == SegueIds.ToFriendPicker,
            let friendPicker = segue.destination.mainVC as? FriendPickerViewController {
            friendPicker.delegate = self
        }
    }
    
    // The progressHUD to display during (en/de)cryption process
    fileprivate var progressHUD: MBProgressHUD? {
        didSet {
            // setup the progressHUD
            progressHUD?.removeFromSuperViewOnHide = true
            progressHUD?.mode = .annularDeterminate
        }
    }
    
    // MARK: - Login/Logout event handling
    
    /// dimisses the presented VC, if it's a LoginVC
    @objc fileprivate func userLoggedIn() {
        // dispatch off to main q
        DispatchQueue.main.async { [weak self] in
            if self?.presentedViewController is LoginViewController {
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    /// segues to the loginVC
    @objc fileprivate func userLoggedOut() {
        // dispatch off to main q
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: SegueIds.ToLogin, sender: self)
        }
    }
    
    // MARK: - Encryption/Decryption

    /// If 'currentFile' is presently nil, sets it to 'url'. Otherwise __deletes__ the file at 'url'
    /// Call this method to encrypt/decrypt a file
    ///
    /// - Parameter url: URL of the file to encrypt/decrypt
    func handleFile(url: URL) {
        guard CurrentUser.shared.isLoggedIn else {
            presentedViewController?.alert(withTitle: Strings.TryingToOpenFileWhenLoggedOut, message: nil)
            return
        }

        if currentFile == nil {
            currentFile = url
        } else {
            do {
                if url.isFileInTemporaryLocation {
                    try FileManager.default.removeItem(at: url)
                }
            } catch (let error) {
                print("Error deleting the source file: ", error)
            }

            print("Currently working on another file:", currentFile!)
        }
    }

    /// Holds the URL to the file currently being encrypted/decrypted
    /// Setting this to a non-nil value starts the process of (en/de)cryption.
    fileprivate var currentFile: URL? {
        didSet {
            guard let url = currentFile  else  {
                return
            }
            
            // check whether file is encrypted or not
            let fileIsEncrypted: Bool
            do {
                fileIsEncrypted = try MiniLock.isEncryptedFile(url: url)
            } catch (let error) {
                print(error)
                return
            }
            
            if fileIsEncrypted {
                // decrypt the encrypted file
                decrypt(url)
            } else {
                // wait for the dismissal of a presented VC (typically a share sheet) using a semaphore
                let semaphore = DispatchSemaphore(value: 0)
                if presentedViewController != nil {
                    presentedViewController?.dismiss(animated: true) { semaphore.signal() }
                } else {
                    // no VC on top, we are good to go!
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
    
    /// Starts decrypting the file at 'url'
    ///
    /// - Parameter url: URL of the file to decrypt
    fileprivate func decrypt(_ url: URL) {
        // setup a progressHUD
        progressHUD = MBProgressHUD.showAdded(to: self.view, animated: true)
        progressHUD!.label.text = Strings.DecryptingMessageInProgressHUD
        
        // initialize and configure a MiniLock.FileDecryptor object
        let decryptor: MiniLock.FileDecryptor
        do {
            decryptor = try MiniLock.FileDecryptor(sourceFile: url, recipientKeys: CurrentUser.shared.keyPair!)
        } catch {
            // handle init errors
            progressHUD?.hide(animated: true)
            alert(withTitle: Strings.ErrorDecryptingFile, message: error as? String)
            currentFile = nil

            return
        }
        
        decryptor.processDelegate = self
        
        // go off the main q
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // set currentFile to nil before returning
            defer {
                self?.currentFile = nil
            }

            // start decrypting the file
            let decryptedFile: URL
            do {
                 decryptedFile = try decryptor.decrypt(destinationDirectory: CurrentUser.shared.decryptedDir,
                                                       filename: nil,
                                                       deleteSourceFile: url.isFileInTemporaryLocation)
            } catch {
                // hide progressHUD and alert the user
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
                strongSelf.fileListVC?.tableView?.reloadData()          // updates the file size in FileListVC
                
                // show a share sheet for the file that was just decrypted
                let activityVC = UIActivityViewController(activityItems: [decryptedFile], applicationActivities: nil)
                activityVC.modalPresentationStyle = .popover
                
                strongSelf.present(activityVC, animated: true, completion: nil)
            }
        }
    }
    
    /// Starts encrypting the file at 'url'
    ///
    /// - Parameters:
    ///   - url: URL of the file to encrypt
    ///   - friends: recipients to whom the file should be encrypted
    fileprivate func encrypt(_ url: URL, to friends: [Friend]) {
        // setup a progressHUD
        progressHUD = MBProgressHUD.showAdded(to: self.view, animated: true)
        progressHUD!.label.text = Strings.EncryptingMessageInProgressHUD

        // initialize and setup a MiniLock.FileEncryptor object
        let encryptor: MiniLock.FileEncryptor
        do {
            encryptor = try MiniLock.FileEncryptor(fileURL: url,
                                                   sender: CurrentUser.shared.keyPair!,
                                                   recipients: friends.map { $0.id } )
        } catch {
            // handle init errors
            progressHUD?.hide(animated: true)
            alert(withTitle: Strings.ErrorEncryptingFile, message: error as? String)
            currentFile = nil

            return
        }
        
        encryptor.processDelegate = self
        
        // go off the main q
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // set currentFile to nil before returning
            defer {
                self?.currentFile = nil
            }

            // start encrypting the file
            let encryptedFile: URL
            do {
                encryptedFile = try encryptor.encrypt(destinationDirectory: CurrentUser.shared.encryptedDir,
                                                      filename: nil,
                                                      deleteSourceFile: url.isFileInTemporaryLocation)
            } catch {
                // dispatch back to the main Q
                DispatchQueue.main.async {
                    // hide progressHUD and alert the user
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
                strongSelf.fileListVC?.tableView?.reloadData()          // updates the file size in FileListVC
                
                // show a share sheet for the file that was just encrypted
                let activityVC = UIActivityViewController(activityItems: [encryptedFile], applicationActivities: nil)
                activityVC.modalPresentationStyle = .popover
                
                strongSelf.present(activityVC, animated: true, completion: nil)
            }
        }
    }
    
    /// This will be the first SLFileListViewController in self's list of vcs
    /// In case there isn't even one of those, its value will be nil
    lazy var fileListVC: SLFileListViewController? = {
        if let viewControllers = self.viewControllers {
            for vc in viewControllers {
                if let fileListVC = vc.mainVC as? SLFileListViewController {
                    return fileListVC
                }
            }
        }
        
        return nil
    }()
}

// MARK: - FriendPickerDelegate
extension HomeViewController: FriendPickerDelegate {
    func friendPicker(_ picker: FriendPickerViewController, didPickFriends friends: [Friend]) {
        dismiss(animated: true, completion: nil)
        
        // encrypt 'currentFile' with 'friends' as the recipients
        guard let url = currentFile else {
            return
        }
        
        encrypt(url, to: friends)
    }
    
    func friendPickerDidCancel(_ picker: FriendPickerViewController) {
        dismiss(animated: true, completion: nil)

        if let url = currentFile {
            // delete currentFile if it is in a temp directory
            if url.isFileInTemporaryLocation {
                try? FileManager.default.removeItem(at: url)
            }

            currentFile = nil
        }
    }
}

// MARK: - MiniLockProcessDelegate
extension HomeViewController: MiniLockProcessDelegate {
    func setProgress(to progress: Double, process: MiniLockProcess) {
        // update the progressHUD
        DispatchQueue.main.async { [weak self] in
            self?.progressHUD?.progress = Float(progress)
        }
    }
}

// MARK: - Misc.
extension URL {
    /// true if the url's direct parent is one of the directories `HomeViewController.Constants.TemporaryLocations`
    var isFileInTemporaryLocation: Bool {
        let parentDir = self.deletingLastPathComponent()
        return HomeViewController.Constants.TemporaryLocations.contains(parentDir)
    }
}
