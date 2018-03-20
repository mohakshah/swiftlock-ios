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

    fileprivate struct Constants {
        static let TemporaryLocations: [URL] = [URL(string: "file://" + NSTemporaryDirectory())!,
                                                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Inbox")]
    }

    // MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()

        // register for login and logout notifications
        onLoginCall(#selector(userLoggedIn))
        onLogoutCall(#selector(userLoggedOut))
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(userLoggedInForTheFirstTime),
                                               name: Notification.Name(NotificationNames.UserLoggedInForTheFirstTime),
                                               object: nil)
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
    
    fileprivate var shouldStartWalkthrough = false
    
    @objc fileprivate func userLoggedInForTheFirstTime() {
        shouldStartWalkthrough = true
    }
    
    /// dimisses the presented VC, if it's a LoginVC
    @objc fileprivate func userLoggedIn() {
        // dispatch off to main q
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }

            if strongSelf.presentedViewController is LoginPageViewController {
                strongSelf.dismiss(animated: true) {
                    if strongSelf.shouldStartWalkthrough {
                        strongSelf.shouldStartWalkthrough = false
                        strongSelf.startWalkthrough()
                    }
                    
                }
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
            deleteIfTemporary(url: url)
            return
        }

        if currentFile == nil {
            currentFile = url
        } else {
            // delete the file off the main Q
            deleteIfTemporary(url: url)

            print("Currently working on another file:", currentFile!)
        }
    }

    /// Holds the URL to the file currently being encrypted/decrypted
    /// Setting this to a non-nil value starts the process of (en/de)cryption.
    fileprivate var currentFile: URL? {
        didSet {
            // delete previous file if it was in a temp directory
            if let oldFile = oldValue, FileManager.default.fileExists(atPath: oldFile.path) {
                deleteIfTemporary(url: oldFile)
            }

            guard let url = currentFile  else  {
                return
            }
            
            // if a status sheet is up, dismiss it
            dismissFinalStatusSheet()
            
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

    /// Deletes the file at "url" _if_ it  is inside one of the locations in
    /// HomeViewController.Constants.TemporaryLocations
    ///
    /// - Parameter url: URL of the file to delete
    fileprivate func deleteIfTemporary(url: URL) {
        // do all the work in a background Q
        DispatchQueue.global(qos: .utility).async {
            // check if file is in a temporary location
            if url.isFileInTemporaryLocation {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print("Error deleting previous file (\(url.path)):", error)
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
            showErrorSheet(withTitle: Strings.FileDecryptionFailureTitle, body: error.localizedDescription)
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
                    self?.showErrorSheet(withTitle: Strings.FileDecryptionFailureTitle, body: error.localizedDescription)
                }

                return
            }
            
            // dispatch back to the main q
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }

                // hide progressHUD and update the file size in FileListVC
                strongSelf.progressHUD?.hide(animated: true)
                strongSelf.fileListVC?.tableView?.reloadData()

                // create a string for the body of the FinalStatusSheet
                var body: String
                
                if decryptor.sender == CurrentUser.shared.keyPair?.publicId {
                    body = Strings.FileDecryptionSuccessBodyWhenSelfIsSender
                } else if let name = CurrentUser.shared.userDbManager?.userDb.friends.filter({ $0.id == decryptor.sender }).first?.name {
                    body = Strings.FileDecryptionSuccessBodyPrefix + name
                } else {
                    body = Strings.FileDecryptionSuccessBodyPrefix + decryptor.sender.base58String
                }
                
                // show a FinalStatusSheet
                strongSelf.showSuccessSheet(forFileURL: decryptedFile,
                                            title: Strings.FileDecryptionSuccessTitle,
                                            body: body)
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
            showErrorSheet(withTitle: Strings.FileEncryptionFailureTitle, body: error.localizedDescription)
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
                    self?.showErrorSheet(withTitle: Strings.FileEncryptionFailureTitle, body: error.localizedDescription)
                }

                return
            }
            
            // dispatch back to the main q
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                
                // hide progressHUD, update the file size in FileListVC and show a FinalStatusSheet
                strongSelf.progressHUD?.hide(animated: true)
                strongSelf.fileListVC?.tableView?.reloadData()
                
                var body: String = Strings.FileEncryptionSuccessBodyPrefix + friends.map({ $0.name}).joined(separator: ", ")

                // Let the user know whether they can decrypt the file in the future or not
                if friends.filter({ $0.id == CurrentUser.shared.keyPair?.publicId }).first != nil {
                    body += "\n" + Strings.FileEncryptionSuccessCurrentUserCanDecrypt
                } else {
                    body += "\n" + Strings.FileEncryptionSuccessCurrentUserCanNotDecrypt
                }

                strongSelf.showSuccessSheet(forFileURL: encryptedFile,
                                            title: Strings.FileEncryptionSuccessTitle,
                                            body: body)
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

    // MARK: - Success/Failure Sheets

    /// Holds the FinalStatusSheet currently displayed
    var statusSheetBeingDisplayed: FinalStatusSheet?
    
    /// This is the URL that will be shared when the share button of FinalStatusSheet is tapped
    var latestFileSuccessfullyProcessed: URL?
    
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
        currentFile = nil
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
        let parentDir = self.resolvingSymlinksInPath().deletingLastPathComponent()
        return HomeViewController.Constants.TemporaryLocations.contains(parentDir)
    }
}
