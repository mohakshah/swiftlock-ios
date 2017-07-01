//
//  SLFileListViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 30/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit
import Photos
import MobileCoreServices
import MiniLockCore

/// Custom FileListVC that lists the files in the currently logged in user's encryted and decrypted directories.
class SLFileListViewController: FileListViewController {
    struct Constants {
        static let JPEGQuality: CGFloat = 0.8
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // register for login and logout notifications
        onLoginCall(#selector(userLoggedIn))
        onLogoutCall(#selector(userLoggedOut))
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(presentFileSourceList))
    }
    
    @objc fileprivate func userLoggedIn() {
        // List contents of user's Encrypted and Decrypted Directories
        self.directories = [CurrentUser.shared.decryptedDir, CurrentUser.shared.encryptedDir]
    }
    
    @objc fileprivate func userLoggedOut() {
        // List no directories
        self.directories = []
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.tabBarItem.title = "Files"
    }
    
    override func image(forFile file: URL) -> UIImage? {
        // provide custom file type icons
        return FileTypeIcons.icon(forFileWithExtension: file.pathExtension) ?? FileTypeIcons.defaultIcon
    }
    
    // add encryption and decryption options to the share sheet
    fileprivate let cryptoActivities: [UIActivity] = [EncryptActivity(), DecryptActivity()]
    override var customActivitiesForShareSheet: [UIActivity]? {
        return cryptoActivities
    }
    
    // MARK: - Gallery Options
    
    @objc fileprivate func presentFileSourceList() {
        present(fileSourceList, animated: true, completion: nil)
    }
    
    /// Shows the user various sources from where they can import a file
    fileprivate lazy var fileSourceList: UIAlertController = {
        var alertVC = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // photo library action if available
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let action = UIAlertAction(title: Strings.PhotoLibrary, style: UIAlertActionStyle.default) { [weak self] _ in
                self?.showPhotoLibrary()
            }
            
            alertVC.addAction(action)
        }
        
        // camera action if available
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let action = UIAlertAction(title: Strings.Camera, style: UIAlertActionStyle.default) { [weak self] _ in
                self?.showCamera()
            }
            
            alertVC.addAction(action)
        }

        // dismiss action
        let action = UIAlertAction(title: Strings.Cancel, style: UIAlertActionStyle.cancel, handler: nil)
        alertVC.addAction(action)
        
        
        
        return alertVC
    }()
    
    /// Displays the user's photo library. Asks for authorization first, if that's required
    fileprivate func showPhotoLibrary() {
        // check and handle the authorization status
        switch PHPhotoLibrary.authorizationStatus() {
        case .denied:
            alert(withTitle: Strings.PhotoLibraryAuthorizationDeniedTitle, message: Strings.PhotoLibraryAuthorizationDeniedMessage)
            return
            
        case .restricted:
            alert(withTitle: Strings.PhotoLibraryAuthorizationRestrictedTitle, message: Strings.PhotoLibraryAuthorizationRestrictedMessage)
            return
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] (status) in
                if status == .authorized {
                    self?.showPhotoLibrary()
                }
            }
            
            return
            
        case .authorized:
            break
        }

        // if we got this far, then we should have the authorization

        // setup the imagePicker
        imagePicker.sourceType = .photoLibrary
        imagePicker.modalPresentationStyle = .popover
        
        present(imagePicker, animated: true, completion: nil)
        
        // setup the popover presentation
        if let ppc = imagePicker.popoverPresentationController {
            ppc.permittedArrowDirections = .any
            ppc.barButtonItem = self.navigationItem.rightBarButtonItem
        }
    }
    
    /// Displays the user's camera. Asks for authorization first, if that's required
    fileprivate func showCamera() {
        // check and handle the authorization status
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .denied:
            alert(withTitle: Strings.PhotoLibraryAuthorizationDeniedTitle, message: Strings.PhotoLibraryAuthorizationDeniedMessage)
            return
            
        case .restricted:
            alert(withTitle: Strings.PhotoLibraryAuthorizationRestrictedTitle, message: Strings.PhotoLibraryAuthorizationRestrictedMessage)
            return
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { [weak self] (success) in
                if success {
                    self?.showCamera()
                }
            }
            
            return
            
        case .authorized:
            break
        }
        
        // if we got this far, then we should have the authorization
        
        // setup the imagePicker
        imagePicker.sourceType = .camera
        imagePicker.modalPresentationStyle = .fullScreen
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    // The UIImagePickerController to display user's photo library and camera
    lazy var imagePicker: UIImagePickerController = {
        let imagePicker = UIImagePickerController()
        
        // configure imagePicker
        imagePicker.mediaTypes = [kUTTypeImage as String]
        imagePicker.allowsEditing = false
        imagePicker.delegate = self
        
        return imagePicker
    }()
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate
extension SLFileListViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        // dismiss imagePicker
        dismiss(animated: true) {
            // get the image user selected
            guard let selectedImage = info[UIImagePickerControllerOriginalImage] as? UIImage else {
                return
            }
            
            // convert it to JPEG
            guard let jpegData = UIImageJPEGRepresentation(selectedImage, Constants.JPEGQuality) else {
                print("Error converting the selected image to JPEG")
                return
            }

            // get fd and path of a unique temp file
            let (tempFD, tempPath) = GlobalUtils.createUniqueFile(withExtension: "jpg", in: nil)
            guard tempFD != -1 else {
                // report error
                return
            }
            
            // write the jpeg data to a temp file
            let tempHandle = FileHandle(fileDescriptor: tempFD, closeOnDealloc: true)
            tempHandle.write(jpegData)
            tempHandle.closeFile()
            
            // create url object from tempPath
            guard let tempURL = URL(string: "file://" + String(cString: tempPath)) else {
                print("Could not convert tempPath to URL object!")
                return
            }
            
            // let AppDelegate handle the file now
            _ = AppDelegate.openFile(url: tempURL)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}
