//
//  HomeViewController+StatusSheet.swift
//  SwiftLock
//
//  Created by Mohak Shah on 04/03/18.
//  Copyright © 2018 Mohak Shah. All rights reserved.
//

import Foundation
import UIKit

// Success/Failure Sheets related methods
extension HomeViewController
{
    /// Displays a FinalStatusSheet configured for _successful_ events
    ///
    /// - Parameters:
    ///   - url: URL of the file that was successfully processed. This will be shared when the user taps the 'Share' button
    ///   - title: The title of the sheet
    ///   - body: The body of the sheet
    func showSuccessSheet(forFileURL url: URL, title: String, body: String) {
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
    func showErrorSheet(withTitle title: String, body: String) {
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
    @objc func dismissFinalStatusSheet() {
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
