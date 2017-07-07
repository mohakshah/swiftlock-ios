//
//  Globals.swift
//  MiniLockCore
//
//  Created by Mohak Shah on 26/03/17.
//
//

import Foundation

public class GlobalUtils
{
    
    
    /// Creates a _unique_ file with `extnsn` extension in `directory` using mkstemps
    ///
    /// - Parameters:
    ///   - extnsn: Extension of the file or nil if the file should not have any extension
    ///   - directory: Path of the parent directory or nil to use NSTemporaryDirectory()
    /// - Returns: (fileDescriptor: Int32, filePath: [CChar])
    ///             Note: The fileDescriptor points to the new file open for reading and writing.
    ///             In case of error fileDescriptor will be -1
    public class func createUniqueFile(withExtension extnsn: String?, in directory: URL?) -> (Int32, [CChar]) {
        guard let template = mkstempsTemplate(withFileExtension: extnsn, in: directory?.path ?? NSTemporaryDirectory()) else {
            return (-1, [CChar]())
        }
        
        let extensionLength: Int32
        if let extnsn = extnsn {
            extensionLength = Int32(extnsn.utf8.count + 1)
        } else {
            extensionLength = 0
        }

        let fd = mkstemps(UnsafeMutablePointer(mutating: template), extensionLength)
        if (fd == -1) {
            let errorMessage = "mkstemp failed for the following reason: ".cString(using: .utf8)!
            perror(errorMessage)
            print("Template used: ")
            puts(template)
        }

        return (fd, template)
    }

    /// Generates a template suitable to use with mktemp() function family. (Entropy = 62 ^ 10)
    ///
    /// - Parameters:
    ///   - fileExtension: Extension to use in template or nil for no template (Use only with mkstemps)
    ///   - directory: Path of the parent directory
    /// - Returns: The template usable with mktemp() function family or nil in case of any errors
    fileprivate class func mkstempsTemplate(withFileExtension fileExtension: String?, in directory: String) -> [Int8]? {
        guard let directoryURL = URL(string: "file://" + directory) else {
            return nil
        }

        var template = directoryURL.appendingPathComponent("XXXXXXXXXX", isDirectory: false) as NSURL
        
        if let extnsn = fileExtension, !extnsn.isEmpty {
            if let newTemplate = template.appendingPathExtension(extnsn) as NSURL? {
                template = newTemplate
            } else {
                return nil
            }
        }

        let fsRepresentation = [Int8](repeating: 0, count: Int(PATH_MAX))
        let success = template.getFileSystemRepresentation(UnsafeMutablePointer(mutating: fsRepresentation), maxLength: Int(PATH_MAX))
        if !success {
            return nil
        }

        return fsRepresentation
    }

    /// Creates a new file in 'dir' of name 'name'. If a file wih that name
    /// exists already, it tries to use a different name by appending copy 1, copy 2, copy 3, etc.
    ///
    /// - Parameters:
    ///   - dir: Directory inside which the file is to be placed
    ///   - name: Preferred name of the file
    /// - Returns: URL to the file finally created
    /// - Throws: MiniLock.Errors.couldNotCreateFile if FileManager failes to create the file
    class func createNewFile(inDirectory dir: URL, withName name: String) throws -> URL {
        let initialPath = dir.appendingPathComponent(name)
        var fullPath = initialPath
        var copyIndex = 1
        
        while FileManager.default.fileExists(atPath: fullPath.path) {
            fullPath = initialPath.deletingLastPathComponent().appendingPathComponent(newName(for: initialPath, withIndex: copyIndex))
            copyIndex += 1
        }
        
        let createdSuccessfully = FileManager.default.createFile(atPath: fullPath.path, contents: nil, attributes: nil)
        
        if !createdSuccessfully {
            throw MiniLock.Errors.couldNotCreateFile
        }
        
        return fullPath
    }

    class func newName(for oldFilename: URL, withIndex index: Int) -> String {
        var ext = ""
        if !oldFilename.pathExtension.isEmpty {
            ext = "." + oldFilename.pathExtension
        }

        let nameWithoutExt = oldFilename.deletingPathExtension().lastPathComponent
        
        return nameWithoutExt + " copy" + (index > 1 ? " \(index)" : "") + ext
    }
}
