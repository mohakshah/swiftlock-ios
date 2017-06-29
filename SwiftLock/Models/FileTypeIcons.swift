//
//  FileTypeIcons.swift
//  Pods
//
//  Created by Mohak Shah on 27/06/17.
//
//

import Foundation
import UIKit

class FileTypeIcons
{
    class func icon(forFileWithExtension extnsn: String) -> UIImage? {
        switch extnsn.lowercased() {
        case "aac":
            return #imageLiteral(resourceName: "aac")
            
        case "ai":
            return #imageLiteral(resourceName: "ai")
            
        case "aiff":
            return #imageLiteral(resourceName: "aiff")
            
        case "asp":
            return #imageLiteral(resourceName: "asp")
            
        case "avi":
            return #imageLiteral(resourceName: "avi")
            
        case "bmp":
            return #imageLiteral(resourceName: "bmp")
            
        case "c":
            return #imageLiteral(resourceName: "c")
            
        case "cpp":
            return #imageLiteral(resourceName: "cpp")
            
        case "css":
            return #imageLiteral(resourceName: "css")
            
        case "dat":
            return #imageLiteral(resourceName: "dat")
            
        case "dmg":
            return #imageLiteral(resourceName: "dmg")
            
        case "doc":
            return #imageLiteral(resourceName: "doc")
            
        case "docx":
            return #imageLiteral(resourceName: "docx")
            
        case "dot":
            return #imageLiteral(resourceName: "dot")
            
        case "dotx":
            return #imageLiteral(resourceName: "dotx")
            
        case "dwg":
            return #imageLiteral(resourceName: "dwg")
            
        case "dxf":
            return #imageLiteral(resourceName: "dxf")
            
        case "eps":
            return #imageLiteral(resourceName: "eps")
            
        case "exe":
            return #imageLiteral(resourceName: "exe")
            
        case "flv":
            return #imageLiteral(resourceName: "flv")
            
        case "gif":
            return #imageLiteral(resourceName: "gif")
            
        case "h":
            return #imageLiteral(resourceName: "h")
            
        case "html":
            return #imageLiteral(resourceName: "html")
            
        case "ics":
            return #imageLiteral(resourceName: "ics")
            
        case "iso":
            return #imageLiteral(resourceName: "iso")
            
        case "java":
            return #imageLiteral(resourceName: "java")
            
        case "jpg":
            return #imageLiteral(resourceName: "jpg")
            
        case "key":
            return #imageLiteral(resourceName: "key")
            
        case "m4v":
            return #imageLiteral(resourceName: "m4v")
            
        case "mid":
            return #imageLiteral(resourceName: "mid")
            
        case "minilock":
            return #imageLiteral(resourceName: "minilock")
            
        case "mov":
            return #imageLiteral(resourceName: "mov")
            
        case "mp3":
            return #imageLiteral(resourceName: "mp3")
            
        case "mp4":
            return #imageLiteral(resourceName: "mp4")
            
        case "mpg":
            return #imageLiteral(resourceName: "mpg")
            
        case "odp":
            return #imageLiteral(resourceName: "odp")
            
        case "ods":
            return #imageLiteral(resourceName: "ods")
            
        case "odt":
            return #imageLiteral(resourceName: "odt")
            
        case "otp":
            return #imageLiteral(resourceName: "otp")
            
        case "ots":
            return #imageLiteral(resourceName: "ots")
            
        case "ott":
            return #imageLiteral(resourceName: "ott")
            
        case "pdf":
            return #imageLiteral(resourceName: "pdf")
            
        case "php":
            return #imageLiteral(resourceName: "php")
            
        case "png":
            return #imageLiteral(resourceName: "png")
            
        case "pps":
            return #imageLiteral(resourceName: "pps")
            
        case "ppt":
            return #imageLiteral(resourceName: "ppt")
            
        case "psd":
            return #imageLiteral(resourceName: "psd")
            
        case "py":
            return #imageLiteral(resourceName: "py")
            
        case "qt":
            return #imageLiteral(resourceName: "qt")
            
        case "rar":
            return #imageLiteral(resourceName: "rar")
            
        case "rb":
            return #imageLiteral(resourceName: "rb")
            
        case "rtf":
            return #imageLiteral(resourceName: "rtf")
            
        case "sql":
            return #imageLiteral(resourceName: "sql")
            
        case "tga":
            return #imageLiteral(resourceName: "tga")
            
        case "tgz":
            return #imageLiteral(resourceName: "tgz")
            
        case "tiff":
            return #imageLiteral(resourceName: "tiff")
            
        case "txt":
            return #imageLiteral(resourceName: "txt")
            
        case "wav":
            return #imageLiteral(resourceName: "wav")
            
        case "xls":
            return #imageLiteral(resourceName: "xls")
            
        case "xlsx":
            return #imageLiteral(resourceName: "xlsx")
            
        case "xml":
            return #imageLiteral(resourceName: "xml")
            
        case "yml":
            return #imageLiteral(resourceName: "yml")
            
        case "zip":
            return #imageLiteral(resourceName: "zip")
            
        default:
            return nil
        }
    }
    
    static var defaultIcon: UIImage {
        return #imageLiteral(resourceName: "dat")
    }
}
