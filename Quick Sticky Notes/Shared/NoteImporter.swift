import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum ImportError: Error, CustomStringConvertible {
    case invalidSourceFile
    case copyFailed
    case invalidContent
    case destinationDirectoryNotSet
    case securityScopedAccessDenied
    
    var description: String {
        switch self {
        case .invalidSourceFile:
            return "Source file is invalid or cannot be read"
        case .copyFailed:
            return "Failed to copy file to notes directory"
        case .invalidContent:
            return "File content is invalid or cannot be parsed"
        case .destinationDirectoryNotSet:
            return "Notes directory is not set"
        case .securityScopedAccessDenied:
            return "Access to the file was denied"
        }
    }
}

struct ImportResult {
    let success: Bool
    let note: FileNote?
    let error: ImportError?
}

class NoteImporter {
    private let fileManager = FileManager.default
    
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    // MARK: - Single File Import
    
    func importFile(at sourcePath: String, to destinationDirectory: URL) async -> ImportResult {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        
        #if os(iOS)
        await startBackgroundTask()
        #endif
        
        do {
            #if os(iOS)
            // For iOS, ensure we have security-scoped access
            guard sourceURL.startAccessingSecurityScopedResource() else {
                throw ImportError.securityScopedAccessDenied
            }
            defer { sourceURL.stopAccessingSecurityScopedResource() }
            #endif
            
            // Read source file
            let content = try String(contentsOf: sourceURL, encoding: .utf8)
            
            // Parse content and metadata
            let (title, noteContent, existingMetadata) = parseContent(content, fallbackTitle: sourceURL.deletingPathExtension().lastPathComponent)
            
            // Create unique filename in destination
            let filename = createUniqueFilename(for: title, in: destinationDirectory)
            let destinationURL = destinationDirectory.appendingPathComponent("\(filename).md")
            
            // Create note with proper format
            let now = Date()
            let note = FileNote(
                filePath: destinationURL.path,
                title: title,
                content: noteContent,
                colorName: existingMetadata["color"] ?? "yellow",
                createdAt: parseDate(existingMetadata["created"]) ?? now,
                modifiedAt: parseDate(existingMetadata["modified"]) ?? now
            )
            
            // Save note with merged frontmatter
            try saveNoteWithMetadata(note, existingMetadata: existingMetadata)
            
            #if os(iOS)
            await endBackgroundTask()
            #endif
            
            return ImportResult(success: true, note: note, error: nil)
        } catch {
            print("Import error: \(error.localizedDescription)")
            
            #if os(iOS)
            await endBackgroundTask()
            #endif
            
            if let importError = error as? ImportError {
                return ImportResult(success: false, note: nil, error: importError)
            }
            return ImportResult(success: false, note: nil, error: .invalidContent)
        }
    }
    
    // MARK: - Batch Import
    
    func importFiles(at sourcePaths: [String], to destinationDirectory: URL) async -> [ImportResult] {
        #if os(iOS)
        await startBackgroundTask()
        #endif
        
        var results: [ImportResult] = []
        
        for path in sourcePaths {
            let result = await importFile(at: path, to: destinationDirectory)
            results.append(result)
        }
        
        #if os(iOS)
        await endBackgroundTask()
        #endif
        
        return results
    }
    
    // MARK: - Helper Methods
    
    private func parseContent(_ content: String, fallbackTitle: String) -> (title: String, content: String, metadata: [String: String]) {
        let lines = content.components(separatedBy: .newlines)
        var metadata: [String: String] = [:]
        
        // Check for existing YAML frontmatter
        if content.hasPrefix("---") {
            let parts = content.components(separatedBy: "---\n")
            if parts.count >= 3 {
                // Valid frontmatter found
                let frontmatter = parts[1]
                let noteContent = parts[2...].joined(separator: "---\n").trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Parse all metadata
                let metadataLines = frontmatter.components(separatedBy: .newlines)
                for line in metadataLines {
                    let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespaces)
                        let value = parts[1].trimmingCharacters(in: .whitespaces)
                        metadata[key] = value
                    }
                }
                
                // Get title from metadata or fallback
                let title = metadata["title"] ?? fallbackTitle
                return (title, noteContent, metadata)
            }
        }
        
        // Check for markdown title
        if let firstLine = lines.first, firstLine.hasPrefix("# ") {
            let title = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            let noteContent = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (title, noteContent, metadata)
        }
        
        // No title found, use filename and original content
        return (fallbackTitle, content, metadata)
    }
    
    private func saveNoteWithMetadata(_ note: FileNote, existingMetadata: [String: String]) throws {
        var markdown = "---\n"
        
        // Add our required fields first
        markdown += "title: \(note.title)\n"
        markdown += "color: \(note.colorName)\n"
        
        let dateFormatter = ISO8601DateFormatter()
        markdown += "created: \(dateFormatter.string(from: note.createdAt))\n"
        markdown += "modified: \(dateFormatter.string(from: note.modifiedAt))\n"
        
        // Add all other existing metadata fields (except ones we already handled)
        let skipFields = ["title", "color", "created", "modified"]
        for (key, value) in existingMetadata where !skipFields.contains(key) {
            markdown += "\(key): \(value)\n"
        }
        
        markdown += "---\n\n"
        markdown += note.content
        
        try FileOperationManager.shared.writeFile(at: note.filePath, content: markdown)
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        return ISO8601DateFormatter().date(from: dateString)
    }
    
    private func createUniqueFilename(for title: String, in directory: URL) -> String {
        do {
            return try FileOperationManager.shared.createUniqueFilename(baseName: title, in: directory)
        } catch {
            print("Failed to create unique filename: \(error.localizedDescription)")
            return "Untitled"
        }
    }
    
    #if os(iOS)
    private func startBackgroundTask() async {
        await MainActor.run {
            backgroundTask = UIApplication.shared.beginBackgroundTask {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }
        }
    }
    
    private func endBackgroundTask() async {
        await MainActor.run {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
    }
    #endif
} 