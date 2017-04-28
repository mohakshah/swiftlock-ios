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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.allowsMultipleSelection = true

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

         self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    fileprivate func updateFileList() {
        if fileList.count < directories.count {
            let missing = [[URL]](repeating: [URL](), count: directories.count - fileList.count)
            fileList.append(contentsOf: missing)
        }
        
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey, .fileSizeKey]

        for i in 0..<directories.count {
            do {
                fileList[i] = try FileManager.default.contentsOfDirectory(at: directories[i],
                                                                          includingPropertiesForKeys: resourceKeys,
                                                                          options: [])
                                                                            .filter { try $0.isRegularFile() }
                                                                                .sorted { $0.creationDate > $1.creationDate}
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
            
            watcher.setEventHandler { [weak weakSelf = self] in
                DispatchQueue.main.async {
                    weakSelf?.updateFileList()
                }
            }
            
            watcher.resume()
            
            directoryWatchers.append(watcher)
        }
    }

    // MARK: - Table view data source

    fileprivate var fileList = [[URL]]()
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return directories.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return directories[section].lastPathComponent
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

        cell.imageView?.image = UIDocumentInteractionController(url: fileList[indexPath.section][indexPath.row]).icons.first

        return cell
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
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { (_, completed, returnedItems, activityError) in
            print("Returned: ", returnedItems)
            activityVC.dismissSelf()
        }

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
