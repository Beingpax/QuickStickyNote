import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Manages the shared state of the current note being edited
class NoteState: ObservableObject {
    @Published var currentNote: FileNote?
    @Published var hasUnsavedChanges: Bool = false
    @Published var hasExternalChanges: Bool = false
    
    private let fileManager = FileOperationManager.shared
    
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    init(note: FileNote? = nil) {
        self.currentNote = note
    }
    
    func reloadFromDisk() async throws -> String? {
        guard let note = currentNote else { return nil }
        
        #if os(iOS)
        await startBackgroundTask()
        #endif
        
        do {
            let content = try fileManager.readFile(at: note.filePath)
            let (parsedContent, _) = YAMLParser.parseNote(content: content)
            
            #if os(iOS)
            await endBackgroundTask()
            #endif
            
            return parsedContent
        } catch {
            #if os(iOS)
            await endBackgroundTask()
            #endif
            throw error
        }
    }
    
    /// Check if the note has been modified externally and handle the changes appropriately
    func checkExternalChanges() async -> Bool {
        guard let note = currentNote, !hasUnsavedChanges else { return false }
        
        #if os(iOS)
        await startBackgroundTask()
        #endif
        
        do {
            let content = try fileManager.readFile(at: note.filePath)
            let (parsedContent, _) = YAMLParser.parseNote(content: content)
            
            if parsedContent != note.content {
                if !hasUnsavedChanges {
                    await MainActor.run {
                        currentNote?.content = parsedContent
                    }
                    return false
                } else {
                    await MainActor.run {
                        self.hasExternalChanges = true
                    }
                    return true
                }
            }
            
            #if os(iOS)
            await endBackgroundTask()
            #endif
            return false
        } catch {
            print("Error checking for external changes: \(error)")
            #if os(iOS)
            await endBackgroundTask()
            #endif
            return false
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

/// A service that centralizes all note saving operations
class NoteSaveService {
    static let shared = NoteSaveService()
    private let fileManager = FileOperationManager.shared
    
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    private init() {}
    
    /// Save a note with updated content while preserving metadata
    func saveNote(_ note: FileNote, newContent: String, colorName: String? = nil) async throws -> FileNote {
        #if os(iOS)
        await startBackgroundTask()
        #endif
        
        do {
            var updatedNote = note
            updatedNote.content = newContent
            updatedNote.modifiedAt = Date()
            if let colorName = colorName {
                updatedNote.colorName = colorName
            }
            try await saveNoteToFile(updatedNote)
            
            #if os(iOS)
            await endBackgroundTask()
            #endif
            
            return updatedNote
        } catch {
            #if os(iOS)
            await endBackgroundTask()
            #endif
            throw error
        }
    }
    
    /// Rename a note without saving its content
    func renameNote(_ note: FileNote, newTitle: String) async throws -> FileNote {
        var updatedNote = note
        try await updatedNote.updateTitle(newTitle)
        return updatedNote
    }
    
    /// Save a note with updated title while preserving content and metadata
    func saveNote(_ note: FileNote, newTitle: String, colorName: String? = nil) async throws -> FileNote {
        var updatedNote = note
        if let colorName = colorName {
            updatedNote.colorName = colorName
        }
        try await updatedNote.updateTitle(newTitle)
        try await saveNoteToFile(updatedNote)
        return updatedNote
    }
    
    /// Save a note with both updated title and content
    func saveNote(_ note: FileNote, newTitle: String, newContent: String, colorName: String? = nil) async throws -> FileNote {
        var updatedNote = note
        updatedNote.content = newContent
        updatedNote.modifiedAt = Date()
        if let colorName = colorName {
            updatedNote.colorName = colorName
        }
        try await updatedNote.updateTitle(newTitle)
        try await saveNoteToFile(updatedNote)
        return updatedNote
    }
    
    /// Create a new note with given title and content
    func createNote(title: String, content: String = "", in directory: URL) async throws -> FileNote {
        // Create a sanitized filename
        let filename = try fileManager.createUniqueFilename(baseName: title, in: directory)
        let filePath = (directory.path as NSString).appendingPathComponent("\(filename).md")
        
        let nextColor = await NotesManager.shared.getNextColor()
        let now = Date()
        var note = FileNote(
            filePath: filePath,
            title: title,
            content: content,
            colorName: nextColor.name,
            createdAt: now,
            modifiedAt: now
        )
        
        try await saveNoteToFile(note)
        return note
    }
    
    /// Add new method for iOS note creation
    func createNewNoteFromiOS(title: String, content: String = "", colorName: String) async throws -> FileNote {
        guard let directory = await NotesManager.shared.notesDirectory else {
            throw FileError.noDirectoryAccess("Notes directory not set")
        }
        
        #if os(iOS)
        // Ensure we have security-scoped access
        if !directory.startAccessingSecurityScopedResource() {
            throw FileError.noDirectoryAccess("Failed to access security-scoped resource")
        }
        defer {
            directory.stopAccessingSecurityScopedResource()
        }
        #endif
        
        do {
            let note = try await createNote(title: title, content: content, in: directory)
            var updatedNote = note
            updatedNote.colorName = colorName
            try await saveNoteToFile(updatedNote)
            
            // Force reload notes
            await NotesManager.shared.forceRefresh()
            
            return updatedNote
        } catch {
            print("Error creating new note: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func saveNoteToFile(_ note: FileNote) async throws {
        #if os(iOS)
        await startBackgroundTask()
        #endif
        
        do {
            let url = URL(fileURLWithPath: note.filePath)
            
            // Get original file dates if file exists
            var originalCreationDate: Date?
            if FileManager.default.fileExists(atPath: note.filePath) {
                let attributes = try FileManager.default.attributesOfItem(atPath: note.filePath)
                originalCreationDate = attributes[.creationDate] as? Date
            }
            
            // Create metadata structure
            let metadata = YAMLParser.NoteMetadata(
                color: note.colorName,
                created: note.createdAt,
                modified: note.modifiedAt,
                additionalMetadata: note.additionalMetadata
            )
            
            // Generate YAML and combine with content
            let yaml = YAMLParser.generateYAML(metadata: metadata)
            // Preserve exact content without adding extra newlines
            let fullContent = yaml + note.content
            
            // Use file coordination for all platforms
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { url in
                do {
                    try fullContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Error writing file: \(error)")
                    // Create a local error instead of directly modifying coordinatorError
                    let nsError = error as NSError
                    DispatchQueue.main.async {
                        coordinatorError = nsError
                    }
                }
            }
            
            if let error = coordinatorError {
                throw error
            }
            
            // Restore creation date after save
            if let creationDate = originalCreationDate {
                try FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: note.filePath)
            }
            
            #if os(iOS)
            await endBackgroundTask()
            #endif
        } catch {
            #if os(iOS)
            await endBackgroundTask()
            #endif
            throw error
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
