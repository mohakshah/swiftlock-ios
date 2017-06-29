//
//  FileListViewController.swift
//  SwiftLock
//
//  Created by Mohak Shah on 09/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

import UIKit

class FileListViewController: UITableViewController
{
    // MARK: - Model
    var directories = [URL]() {
        didSet {
            setupDirectoryWatchers()
            updateFileList()
        }
    }
    
    /// sub-classes can override this var to add custom activities to the share sheet
    var customActivitiesForShareSheet: [UIActivity]? {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.allowsMultipleSelection = true

        self.navigationItem.leftBarButtonItem = self.editButtonItem
    }

    fileprivate func updateFileList() {
        fileList.removeAll(keepingCapacity: true)
        
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey, .fileSizeKey]

        for i in 0..<directories.count {
            do {
                fileList.append(try FileManager.default.contentsOfDirectory(at: directories[i],
                                                                          includingPropertiesForKeys: resourceKeys,
                                                                          options: [])
                                                                            .filter { try $0.isRegularFile() }
                                                                                .sorted { $0.creationDate > $1.creationDate})
            } catch (let error) {
                print(error)
                fileList[i].removeAll()
            }
        }
        
        tableView.reloadData()
    }
    
    fileprivate var directoryWatchers = [DispatchSourceFileSystemObject]()
    
    fileprivate func setupDirectoryWatchers() {
        for watcher in directoryWatchers {
            watcher.cancel()
        }
        
        directoryWatchers.removeAll()

        for dir in directories {
            let fd = dir.withUnsafeFileSystemRepresentation { (filenamePointer) -> Int32 in
                return vfw_open(filenamePointer, O_EVTONLY)
            }
            
            guard fd != 0 else {
                return
            }
            
            let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
                                                                     eventMask: DispatchSource.FileSystemEvent.write,
                                                                     queue: DispatchQueue.global(qos: .utility))
            
            watcher.setEventHandler { [weak self] in
                DispatchQueue.main.async {
                    self?.updateFileList()
                }
            }
            
            watcher.setCancelHandler() {
                close(fd)
            }
            
            watcher.resume()
            
            directoryWatchers.append(watcher)
        }
    }

    // MARK: - Table view data source

    fileprivate var fileList = [[URL]]()
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fileList.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if fileList[section].isEmpty {
            return nil
        } else {
            return directories[section].lastPathComponent.uppercased()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textAlignment = .center
            headerView.textLabel?.textColor = .darkGray
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileList[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FileCell", for: indexPath)

        // Configure the cell...
        cell.textLabel?.text = fileList[indexPath.section][indexPath.row].lastPathComponent
        cell.detailTextLabel?.text = fileList[indexPath.section][indexPath.row].fileSize
        
        cell.backgroundColor = tableView.backgroundColor
        
        cell.imageView?.image = image(forFile: fileList[indexPath.section][indexPath.row])

        return cell
    }
    
    
    /// Returns an image appropriate to be the icon of `file`
    /// Sub-classes can override to use custom icons
    ///
    /// - Parameter file: URL of the file for which the icon is to be generated
    /// - Returns: UIImage to use as icon or nil if none could be found
    func image(forFile file: URL) -> UIImage? {
        return UIDocumentInteractionController(url: file).icons.first
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            do {
                try FileManager.default.removeItem(at: fileList[indexPath.section][indexPath.row])
            } catch (let error) {
                alert(withTitle: "Error deleting file.", message: error.localizedDescription)
                return
            }

            tableView.beginUpdates()
            fileList[indexPath.section].remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.endUpdates()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let fileURL = fileList[indexPath.section][indexPath.row]
        let activityVC = UIActivityViewController(activityItems: [fileURL],
                                                  applicationActivities: customActivitiesForShareSheet)

        present(activityVC, animated: true, completion: nil)
        
        activityVC.modalPresentationStyle = .popover
    }
    
    

}

fileprivate extension URL {
    func isRegularFile() throws -> Bool {
        return try self.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile ?? false
    }
    
    var creationDate: Date {
        return (try? self.resourceValues(forKeys: [.creationDateKey]).creationDate) as? Date ?? Date(timeIntervalSince1970: 0.0)
    }
    
    var fileSize: String {
        guard let fileSize = (try? self.resourceValues(forKeys: [.fileSizeKey]).fileSize) as? Int else {
            return "Unknown"
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}
