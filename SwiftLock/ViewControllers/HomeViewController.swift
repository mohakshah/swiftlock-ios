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
import EAIntroView

class HomeViewController: UITabBarController
{
    struct SegueIds {
        static let ToLogin = "Home2Login"
        static let ToFriendPicker = "Home2FriendPicker"
    }

    struct Constants {
        static let TemporaryLocations: [URL] = [URL(string: "file://" + NSTemporaryDirectory())!,
                                                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Inbox")]
        
        static let IntroImageTextPairs: [(UIImage, String)] = [
                                                                (#imageLiteral(resourceName: "Screen 1.jpg"), "Share your id with your friends from the “Friends” tab. Ask them to scan the QR Code or   use the “Share” button to share via Twitter, email, etc."),
                                                                (#imageLiteral(resourceName: "Screen 2.jpg"), "Scan your friends’ QR Codes to send them encrypted files."),
                                                                (#imageLiteral(resourceName: "Screen 3.jpg"), "Tap ‘+’ button on the “Files” tab to pick a photo from your library and encrypt it. Optionally, open files in SwiftLock using the “Share Sheet” from other apps to encrypt those files."),
                                                                (#imageLiteral(resourceName: "Screen 4.jpg"), "Next, select the recipients. These are the people who will be able to decrypt the file. Keep “Me” checked so that you yourself can decrypt the file in the future."),
                                                                (#imageLiteral(resourceName: "Screen 5.jpg"), "Tap on the encrypted file’s name to share it via a medium of your choice."),
                                                                (#imageLiteral(resourceName: "Screen 6.jpg"), "If you receive an encrypted file from your friend, open it in SwiftLock using the “Share Sheet” to decrypt it.")
                                                            ]
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
    
    func startWalkthrough() {
        var introPages = [EAIntroPage]()
        
        for (image, text) in Constants.IntroImageTextPairs {
            let page = EAIntroPage(customViewFromNibNamed: "IntroCustomPageView")!
            guard let introView = page.customView as? IntroCustomPageView else {
                break
            }

            introView.image = image
            introView.text = text
            
            introPages.append(page)
        }

        guard let introView = EAIntroView(frame: view.bounds, andPages: introPages) else {
            print("Failed to initialize EAIntroView")
            return
        }

        introView.backgroundColor = UIColor(red:0.24, green:0.49, blue:0.69, alpha:1.0)
        
        introView.show(in: view)
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
            
            // delete the file off the main Q
            DispatchQueue.global(qos: .utility).async {
                do {
                    if url.isFileInTemporaryLocation {
                        try FileManager.default.removeItem(at: url)
                    }
                } catch (let error) {
                    print("Error deleting the source file: ", error)
                }
            }

            return
        }

        if currentFile == nil {
            currentFile = url
        } else {
            // delete the file off the main Q
            DispatchQueue.global(qos: .utility).async {
                do {
                    if url.isFileInTemporaryLocation {
                        try FileManager.default.removeItem(at: url)
                    }
                } catch (let error) {
                    print("Error deleting the source file: ", error)
                }
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
                } else if let name = CurrentUser.shared.friendsDb?.friends.filter({ $0.id == decryptor.sender }).first?.name {
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

    /// Displays a FinalStatusSheet configured for _successful_ events
    ///
    /// - Parameters:
    ///   - url: URL of the file that was successfully processed. This will be shared when the user taps the 'Share' button
    ///   - title: The title of the sheet
    ///   - body: The body of the sheet
    private func showSuccessSheet(forFileURL url: URL, title: String, body: String) {
        latestFileSuccessfullyProcessed = url

        let successView = initSuccessSheet(withTitle: title, body: body)
        presentSheet(successView)
        
        self.statusSheetBeingDisplayed = successView
    }
    
    /// Displays a FinalStatusSheet configured for _unsuccessful_ events
    ///
    /// - Parameters:
    ///   - title: The title of the sheet
    ///   - body: The body of the sheet
    private func showErrorSheet(withTitle title: String, body: String) {
        let errorSheet = initErrorSheet(withTitle: title, body: body)
        presentSheet(errorSheet)
        
        self.statusSheetBeingDisplayed = errorSheet
    }
    
    /// Returns a FinalStatusSheet configured for _successful_ events
    ///
    /// - Parameters:
    ///   - title: The title of the sheet
    ///   - body: The body of the sheet
    private func initSuccessSheet(withTitle title: String, body: String) -> FinalStatusSheet {
        let successSheet = Bundle.main.loadNibNamed("FinalStatusSheet", owner: nil, options: nil)?.first as! FinalStatusSheet
        
        successSheet.title = title
        successSheet.body = body

        successSheet.okButton.addTarget(self, action: #selector(dismissFinalStatusSheet), for: .touchUpInside)
        successSheet.shareButton.addTarget(self, action: #selector(successViewShareButtonTapped), for: .touchUpInside)
        
        return successSheet
    }
    
    /// Returns a FinalStatusSheet configured for _unsuccessful_ events
    ///
    /// - Parameters:
    ///   - title: The title of the sheet
    ///   - body: The body of the sheet
    private func initErrorSheet(withTitle title: String, body: String) -> FinalStatusSheet {
        let errorSheet = initSuccessSheet(withTitle: title, body: body)
        errorSheet.convertToErrorView()
        
        return errorSheet
    }
    
    /// Presents a FinalStatusSheet with animation adding it to self.view
    ///
    /// - Parameter sheet: The sheet to present
    private func presentSheet(_ sheet: FinalStatusSheet) {
        // position at bottom of the view (outside the screen) initially
        var initialFrame = self.view.bounds
        initialFrame.origin = CGPoint(x: view.bounds.minX, y: view.bounds.maxY)
        sheet.frame = initialFrame
        
        // remove the background translucency during animation
        sheet.backgroundTranslucency = 0.0
        
        self.view.addSubview(sheet)
        
        UIView.animate(withDuration: 0.5,
                       delay: 0.0,
                       usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 0.5,
                       options: .beginFromCurrentState,
                       animations: { sheet.frame = self.view.bounds })
        { _ in
            // make the sheet's background translucent again once the animation is complete
            UIView.animate(withDuration: 0.1, animations: {
                sheet.backgroundTranslucency = FinalStatusSheet.Constants.DefaultBackgroundTranslucency
            })
        }
    }
    
    /// Shares the URL 'latestFileSuccessfullyProcessed' with a share sheet
    @objc private func successViewShareButtonTapped() {
        // dismiss the sheet
        dismissFinalStatusSheet()

        // show a share sheet for the file that was just encrypted
        let activityVC = UIActivityViewController(activityItems: [latestFileSuccessfullyProcessed!], applicationActivities: nil)
        activityVC.modalPresentationStyle = .popover
        
        present(activityVC, animated: true, completion: nil)
    }
    
    /// Dismisses 'statusSheetBeingDisplayed' with animation and removes it  from self.view
    @objc private func dismissFinalStatusSheet() {
        guard let finalStatusSheet = statusSheetBeingDisplayed else {
            return
        }
        
        // remove translucency before dismissing
        finalStatusSheet.backgroundTranslucency = 0.0

        // the final frame starts from the botton of the screen
        var finalFrame = self.view.bounds
        finalFrame.origin = CGPoint(x: view.bounds.minX, y: view.bounds.maxY)
        
        // animate with a spring effect
        UIView.animate(withDuration: 0.5,
                       delay: 0.0,
                       usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 0.5,
                       options: .beginFromCurrentState,
                       animations: { finalStatusSheet.frame = finalFrame })
        { (_) in
            // remove from superview after completion
            finalStatusSheet.removeFromSuperview()
        }
    }
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
