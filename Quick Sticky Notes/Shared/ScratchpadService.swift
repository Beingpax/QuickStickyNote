import Foundation
import AppKit

class ScratchpadService {
    static let shared = ScratchpadService()
    private let notesManager = NotesManager.shared
    private let noteSaveService = NoteSaveService.shared
    private var scratchpadWindow: NSWindow?
    
    private init() {}
    
    func toggleScratchpad() async {
        if let window = scratchpadWindow, window.isVisible {
            await MainActor.run {
                window.close()
                scratchpadWindow = nil
            }
        } else {
            await openScratchpad()
        }
    }
    
    func openScratchpad() async {
        do {
            let scratchpad = try await getScratchpad()
            await MainActor.run {
                let window = EditNoteWindow(note: scratchpad)
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                scratchpadWindow = window
            }
        } catch {
            print("Error opening scratchpad: \(error)")
        }
    }
    
    private func getScratchpad() async throws -> FileNote {
        // Try to find existing scratchpad
        if let existingScratchpad = try await findExistingScratchpad() {
            return existingScratchpad
        }
        
        // Create new scratchpad if not found
        return try await createScratchpad()
    }
    
    private func findExistingScratchpad() async throws -> FileNote? {
        guard let directory = await notesManager.notesDirectory else { return nil }
        
        let scratchpadPath = (directory.path as NSString).appendingPathComponent("My Scratchpad.md")
        if FileManager.default.fileExists(atPath: scratchpadPath) {
            return try await FileNote.from(filePath: scratchpadPath)
        }
        return nil
    }
    
    private func createScratchpad() async throws -> FileNote {
        guard let directory = await notesManager.notesDirectory else {
            throw FileError.noDirectoryAccess("Notes directory not set")
        }
        
        return try await noteSaveService.createNote(
            title: "My Scratchpad",
            content: "Welcome to your Scratchpad!\n\nUse this space for quick notes and temporary content.",
            in: directory
        )
    }
} 
