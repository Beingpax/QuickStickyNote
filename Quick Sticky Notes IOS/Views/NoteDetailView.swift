import SwiftUI
import MarkdownUI
import Combine

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notesManager = NotesManager.shared
    @ObservedObject var noteState: NoteState
    
    @State private var noteText: String
    @State private var isPreviewMode = false
    @State private var isNewNote: Bool
    @State private var showingExternalChangeAlert = false
    @State private var localTitle: String = ""
    
    // Timer for checking external changes
    private let externalChangeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Auto-save debouncer
    @StateObject private var autoSave = DebouncedSave()
    @StateObject private var titleSave = DebouncedSave(delay: 0.5)
    
    init(note: FileNote) {
        let state = NoteState(note: note)
        self.noteState = state
        _noteText = State(initialValue: note.content)
        _isNewNote = State(initialValue: note.filePath.isEmpty)
        _localTitle = State(initialValue: note.title)
        
        // Register the note state for tracking
        NotesManager.shared.registerOpenNote(state: state)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isPreviewMode {
                // Preview Mode
                ScrollView {
                    VStack(alignment: .leading) {
                        Markdown(noteText)
                            .markdownTheme(.quickStickyNotesIOS)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
            } else {
                // Edit Mode
                TextEditor(text: $noteText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                    .padding(.horizontal)
            }
            
            // Bottom Toolbar
            VStack(spacing: 8) {
                // Status Bar
                HStack {
                    // Save Status
                    HStack(spacing: 4) {
                        if noteState.hasUnsavedChanges {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        Text("\(noteText.split(separator: " ").count) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Manual Save Button
                    if noteState.hasUnsavedChanges {
                        Button(action: saveIfNeeded) {
                            Text("Save")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    
                    // Preview Toggle
                    Button(action: { isPreviewMode.toggle() }) {
                        Image(systemName: isPreviewMode ? "pencil" : "eye")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Note Title", text: titleBinding)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
        .onChange(of: noteText) { _, newValue in
            noteState.hasUnsavedChanges = true
            triggerAutoSave()
        }
        .onReceive(externalChangeTimer) { _ in
            checkExternalChanges()
        }
        .onAppear {
            setupBackgroundTaskHandling()
        }
        .onDisappear {
            saveIfNeeded()
            notesManager.unregisterOpenNote(state: noteState)
        }
        .alert("External Changes Detected", isPresented: $showingExternalChangeAlert) {
            Button("Keep My Changes") {
                noteState.hasExternalChanges = false
            }
            Button("Load External Changes") {
                Task {
                    if let newContent = try? await noteState.reloadFromDisk() {
                        noteText = newContent
                        noteState.hasUnsavedChanges = false
                    }
                }
            }
        } message: {
            Text("This note has been modified outside of the app. What would you like to do?")
        }
    }
    
    private func setupBackgroundTaskHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            saveIfNeeded()
        }
    }
    
    private func checkExternalChanges() {
        Task {
            if await noteState.checkExternalChanges() {
                showingExternalChangeAlert = true
            }
        }
    }
    
    private func saveIfNeeded() {
        if noteState.hasUnsavedChanges {
            Task {
                await performSave()
            }
        }
    }
    
    private func performSave() async {
        if var updatedNote = noteState.currentNote {
            if isNewNote {
                do {
                    let newNote = try await NoteSaveService.shared.createNewNoteFromiOS(
                        title: localTitle.isEmpty ? "Untitled" : localTitle,
                        content: noteText,
                        colorName: "default" // Use default color
                    )
                    await MainActor.run {
                        noteState.currentNote = newNote
                        isNewNote = false
                        noteState.hasUnsavedChanges = false
                        localTitle = newNote.title // Update local title with the new note's title
                    }
                } catch {
                    print("Error creating new note: \(error)")
                }
            } else {
                do {
                    updatedNote = try await NoteSaveService.shared.saveNote(
                        updatedNote,
                        newTitle: localTitle.isEmpty ? "Untitled" : localTitle,
                        newContent: noteText,
                        colorName: updatedNote.colorName // Keep existing color
                    )
                    await MainActor.run {
                        noteState.currentNote = updatedNote
                        noteState.hasUnsavedChanges = false
                    }
                } catch {
                    print("Error saving note: \(error)")
                }
            }
        }
    }
    
    private func triggerAutoSave() {
        autoSave.trigger {
            await performSave()
        }
    }
    
    private var titleBinding: Binding<String> {
        Binding(
            get: { localTitle },
            set: { newTitle in
                localTitle = newTitle
                titleSave.trigger {
                    guard var updatedNote = noteState.currentNote else { return }
                    do {
                        // First update the title in the note object
                        try await updatedNote.updateTitle(newTitle)
                        
                        // Then save any content changes
                        let savedNote = try await NoteSaveService.shared.saveNote(
                            updatedNote,
                            newContent: noteText,
                            colorName: updatedNote.colorName
                        )
                        
                        await MainActor.run {
                            noteState.currentNote = savedNote
                            noteState.hasUnsavedChanges = false
                        }
                        
                        // Force refresh to update the list
                        await notesManager.forceRefresh()
                    } catch {
                        print("Error updating note title: \(error)")
                    }
                }
            }
        )
    }
}

#Preview {
    NavigationView {
        NoteDetailView(note: FileNote(
            filePath: "",
            title: "Sample Note",
            content: "This is a sample note",
            colorName: "default",
            createdAt: Date(),
            modifiedAt: Date()
        ))
    }
} 