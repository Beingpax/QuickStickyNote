import SwiftUI
import AppKit

class EditNoteWindow: NSPanel {
    private let noteState: NoteState
    private let colorState: ColorState
    private let recentNotesManager = RecentNotesManager.shared
    
    init(note: FileNote? = nil) {
        self.noteState = NoteState(note: note)
        // Initialize colorState from note or default
        let initialColor = note.flatMap { note in
            // First check default colors
            NoteColor.defaultColors.first { $0.name == note.colorName } ??
            // Then check custom colors
            UserDefaults.standard.getCustomColors().first { $0.name == note.colorName }
        } ?? .citrus
        self.colorState = ColorState(initialColor: initialColor)
        
        // Add to recent notes if this is an existing note
        if let note = note {
            recentNotesManager.addRecentNote(filePath: note.filePath)
        }
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 300),
            styleMask: [.nonactivatingPanel, .titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false,
            positionNearCursor: true
        )
        
        // Configure panel properties
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [
            .canJoinAllSpaces, 
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        hidesOnDeactivate = false
        
        minSize = NSSize(width: 300, height: 200)
        
        // Set title for new note
        title = note?.title ?? "New Note"
        
        // Modern window appearance
        let baseNSColor = NSColor(colorState.selectedColor.backgroundColor)
        let titleBarColor = baseNSColor.blended(withFraction: 0.15, of: .black) ?? baseNSColor
        
        backgroundColor = titleBarColor // Use the darker color for the window background
        hasShadow = true
        titlebarAppearsTransparent = true
        titleVisibility = .visible
        
        contentView = NSHostingView(
            rootView: WindowContentView(noteState: self.noteState, colorState: self.colorState)
                .environment(\.window, self)
        )
        
        // Register with NotesManager for external change tracking
        Task { @MainActor in
            NotesManager.shared.registerOpenNote(state: noteState)
        }
    }
    
    deinit {
        Task { @MainActor in
            NotesManager.shared.unregisterOpenNote(state: noteState)
        }
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class ColorState: ObservableObject {
    @Published var selectedColor: NoteColor
    
    init(initialColor: NoteColor) {
        self.selectedColor = initialColor
    }
}

struct WindowContentView: View {
    @StateObject var noteState: NoteState
    @StateObject var colorState: ColorState
    @Environment(\.window) private var window
    @State private var title: String
    @StateObject private var autoSave = DebouncedSave()
    
    init(noteState: NoteState, colorState: ColorState) {
        _noteState = StateObject(wrappedValue: noteState)
        _colorState = StateObject(wrappedValue: colorState)
        _title = State(initialValue: noteState.currentNote?.title ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            EditNoteView(noteState: noteState, selectedColor: $colorState.selectedColor)
        }
        .onChange(of: title) { _, newValue in
            noteState.hasUnsavedChanges = true
            updateWindowTitle()
            triggerAutoSave()
        }
        .onChange(of: colorState.selectedColor) { _, newColor in
            updatePanelBackgroundColor(newColor)
        }
        .overlay(
            Button("Close") {
                window?.close()
            }
            .keyboardShortcut("w", modifiers: .command)
            .opacity(0)
        )
    }
    
    private func updatePanelBackgroundColor(_ noteColor: NoteColor) {
        guard let panel = window as? NSPanel else { return }
        let baseNSColor = NSColor(noteColor.backgroundColor)
        let titleBarColor = baseNSColor.blended(withFraction: 0.15, of: .black) ?? baseNSColor
        panel.backgroundColor = titleBarColor
    }
    
    private func updateWindowTitle() {
        if let note = noteState.currentNote {
            window?.title = note.title.isEmpty ? "Untitled" : note.title
        } else {
            window?.title = title.isEmpty ? "New Note" : title
        }
    }
    
    private func triggerAutoSave() {
        autoSave.trigger {
            saveNote()
        }
    }
    
    private func saveNote() {
        guard let note = noteState.currentNote else { return }
        
        Task {
            do {
                let newTitle = title.isEmpty ? "Untitled" : title
                let updatedNote = try await NoteSaveService.shared.renameNote(note, newTitle: newTitle)
                
                await MainActor.run {
                    noteState.currentNote = updatedNote
                    noteState.hasUnsavedChanges = false
                    updateWindowTitle()
                }
            } catch {
                print("Error saving note: \(error)")
            }
        }
    }
} 
