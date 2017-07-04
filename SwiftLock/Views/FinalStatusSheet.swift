//
//  FinalStatusSheet.swift
//  SwiftLock
//
//  Created by Mohak Shah on 02/07/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

/// By default, this view is configured for successful events with a
/// green checkmark at the top and a 'Share' button. Calling the instance
/// method 'convertToErrorView' turns the view into one configured for errors
class FinalStatusSheet: UIView
{
    struct Constants {
        static let DefaultBackgroundTranslucency: CGFloat = 0.5
    }

    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var labelToGuideBodyTextView: UILabel!
    @IBOutlet weak var bodyTextView: UITextView! {
        didSet {
            // remove all inset to make content size same as labelToGuideBodyTextView
            bodyTextView.textContainerInset = UIEdgeInsets.zero
            bodyTextView.textContainer.lineFragmentPadding = 0.0
        }
    }

    @IBOutlet weak var checkMarkImage: UIImageView! {
        didSet {
            checkMarkImage.layer.cornerRadius = checkMarkImage.bounds.width / 2
            checkMarkImage.layer.masksToBounds = true
        }
    }

    @IBOutlet weak var translucencyView: UIView!
    
    /// Replaces the green check mark with an image of a red cross and removes the 'Share' button
    public func convertToErrorView() {
        shareButton?.removeFromSuperview()
        checkMarkImage.image = #imageLiteral(resourceName: "Red Cross")
    }
    
    // MARK: -  convenience variables for updating subviews
    public var backgroundTranslucency: CGFloat = Constants.DefaultBackgroundTranslucency {
        didSet {
            translucencyView.backgroundColor = translucencyView.backgroundColor?.withAlphaComponent(backgroundTranslucency)
        }
    }
    
    public var body: String? {
        didSet {
            labelToGuideBodyTextView.text = body
            bodyTextView.text = body
        }
    }
    
    public var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
}
