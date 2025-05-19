import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

class FileOperationManager {
    static let shared = FileOperationManager()
    private let fileManager = FileManager.default
    
    #if os(iOS)
    private var securityScopedBookmarks: [URL: Data] = [:]
    #endif
    
    private init() {}
    
    // MARK: - File Operations
    
    func readFile(at path: String) throws -> String {
        guard fileManager.fileExists(atPath: path) else {
            throw FileError.invalidFile("File does not exist")
        }
        
        let url = URL(fileURLWithPath: path)
        
        #if os(iOS)
        // Start accessing security-scoped resource if available
        if let bookmark = securityScopedBookmarks[url] {
            var isStale = false
            let secureURL = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            if secureURL.startAccessingSecurityScopedResource() {
                defer { secureURL.stopAccessingSecurityScopedResource() }
                return try String(contentsOf: secureURL, encoding: .utf8)
            }
        }
        #endif
        
        // Use file coordination for both platforms
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var fileContents = ""
        
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinatorError) { url in
            do {
                fileContents = try String(contentsOf: url, encoding: .utf8)
            } catch {
                print("Error reading file: \(error)")
                let nsError = error as NSError
                DispatchQueue.main.async {
                    coordinatorError = nsError
                }
            }
        }
        
        if let error = coordinatorError {
            throw error
        }
        
        return fileContents
    }
    
    func writeFile(at path: String, content: String) throws {
        do {
            let url = URL(fileURLWithPath: path)
            
            // Get original file dates if file exists
            var originalCreationDate: Date?
            if fileManager.fileExists(atPath: path) {
                let attributes = try fileManager.attributesOfItem(atPath: path)
                originalCreationDate = attributes[.creationDate] as? Date
            }
            
            // Use file coordination for both platforms
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { url in
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Error writing file: \(error)")
                    let nsError = error as NSError
                    DispatchQueue.main.async {
                        coordinatorError = nsError
                    }
                }
            }
            
            if let error = coordinatorError {
                throw error
            }
            
            // Restore creation date if it existed
            if let creationDate = originalCreationDate {
                try fileManager.setAttributes([.creationDate: creationDate], ofItemAtPath: path)
            }
        } catch {
            throw FileError.accessDenied("Failed to write file: \(error.localizedDescription)")
        }
    }
    
    func moveFile(from sourcePath: String, to destinationPath: String) throws {
        do {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destinationURL = URL(fileURLWithPath: destinationPath)
            
            // Get original file dates
            let attributes = try fileManager.attributesOfItem(atPath: sourcePath)
            let originalCreationDate = attributes[.creationDate] as? Date
            
            // Use file coordination for moving files
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            
            coordinator.coordinate(writingItemAt: sourceURL, options: .forMoving, writingItemAt: destinationURL, options: .forReplacing, error: &coordinatorError) { (srcURL, destURL) in
                do {
                    try fileManager.moveItem(at: srcURL, to: destURL)
                } catch {
                    print("Error moving file: \(error)")
                    let nsError = error as NSError
                    DispatchQueue.main.async {
                        coordinatorError = nsError
                    }
                }
            }
            
            if let error = coordinatorError {
                throw error
            }
            
            // Restore creation date after move
            if let creationDate = originalCreationDate {
                try fileManager.setAttributes([.creationDate: creationDate], ofItemAtPath: destinationPath)
            }
        } catch {
            throw FileError.accessDenied("Failed to move file: \(error.localizedDescription)")
        }
    }
    
    func deleteFile(at path: String) throws {
        guard fileManager.fileExists(atPath: path) else { return }
        
        let url = URL(fileURLWithPath: path)
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { url in
            do {
                try fileManager.removeItem(at: url)
            } catch {
                print("Error deleting file: \(error)")
                let nsError = error as NSError
                DispatchQueue.main.async {
                    coordinatorError = nsError
                }
            }
        }
        
        if let error = coordinatorError {
            throw error
        }
    }
    
    func verifyDirectoryAccess(at url: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            // Try to create directory if it doesn't exist
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                return
            } catch {
                throw FileError.noDirectoryAccess("Directory doesn't exist and couldn't be created: \(error.localizedDescription)")
            }
        }
        
        guard isDirectory.boolValue else {
            throw FileError.noDirectoryAccess("Path exists but is not a directory")
        }
        
        #if os(iOS)
        // For iOS, check if we have security-scoped access
        if let bookmark = securityScopedBookmarks[url] {
            var isStale = false
            let secureURL = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            guard secureURL.startAccessingSecurityScopedResource() else {
                throw FileError.writePermissionDenied("No security-scoped access to directory")
            }
            secureURL.stopAccessingSecurityScopedResource()
            return
        }
        #endif
        
        // Check write permissions by attempting to create a test file
        let testFile = url.appendingPathComponent(".write_test")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
        } catch {
            throw FileError.writePermissionDenied("No write permission: \(error.localizedDescription)")
        }
    }
    
    func createUniqueFilename(baseName: String, in directory: URL) throws -> String {
        var sanitizedName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitizedName.isEmpty {
            sanitizedName = "Untitled"
        }
        
        // Replace illegal characters with empty string while preserving spaces
        let illegalCharacters = "\\/:*?\"<>|"
        sanitizedName = sanitizedName.map { char in
            illegalCharacters.contains(char) ? "" : String(char)
        }.joined()
        
        // If the file doesn't exist, use the name as is
        let baseURL = directory.appendingPathComponent(sanitizedName + ".md")
        if !fileManager.fileExists(atPath: baseURL.path) {
            return sanitizedName
        }
        
        // Otherwise, append a number until we find a unique name
        var counter = 1
        var uniqueName: String
        var uniqueURL: URL
        
        repeat {
            uniqueName = "\(sanitizedName) \(counter)"
            uniqueURL = directory.appendingPathComponent(uniqueName + ".md")
            counter += 1
        } while fileManager.fileExists(atPath: uniqueURL.path)
        
        return uniqueName
    }
    
    #if os(iOS)
    func saveSecurityScopedBookmark(for url: URL) throws {
        let bookmark = try url.bookmarkData(options: .minimalBookmark,
                                          includingResourceValuesForKeys: nil,
                                          relativeTo: nil)
        securityScopedBookmarks[url] = bookmark
    }
    
    func clearSecurityScopedBookmark(for url: URL) {
        securityScopedBookmarks.removeValue(forKey: url)
    }
    #endif
} 