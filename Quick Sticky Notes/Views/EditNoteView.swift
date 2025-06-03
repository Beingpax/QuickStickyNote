import SwiftUI
import Combine
import MarkdownUI
import KeyboardShortcuts
import AppKit

enum EditorMode: String, CaseIterable, Identifiable {
    case wysiwyg = "WYSIWYG"
    case plainText = "Plain Text"
    case preview = "Preview"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .wysiwyg: return "pencil.line"
        case .plainText: return "doc.text"
        case .preview: return "doc.richtext"
        }
    }
    
    func next() -> EditorMode {
        let allCases = EditorMode.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return .wysiwyg }
        let nextIndex = allCases.index(after: currentIndex)
        return allCases.indices.contains(nextIndex) ? allCases[nextIndex] : allCases[0]
    }
}

struct EditNoteView: View {
    @Environment(\.window) private var window
    @StateObject private var notesManager = NotesManager.shared
    @StateObject private var proManager = ProManager.shared
    @ObservedObject var noteState: NoteState
    @State private var isWindowFocused = false
    
    @State private var noteText: String
    @State private var title: String
    @Binding var selectedColor: NoteColor
    @State private var showingColorPicker = false
    @State private var showingDeleteAlert = false
    @State private var colorToDelete: NoteColor?
    @State private var showError = false
    @State private var currentError: FileError?
    @State private var editorMode: EditorMode = .wysiwyg
    @State private var showingExternalChangeAlert = false
    @State private var showingUpgradePrompt = false
    
    // Auto-save debouncer
    @StateObject private var autoSave = DebouncedSave()
    
    // Timer for checking external changes
    private let externalChangeTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    private var allColors: [NoteColor] {
        NoteColor.defaultColors + UserDefaults.standard.getCustomColors()
    }
    
    init(noteState: NoteState, selectedColor: Binding<NoteColor>) {
        self.noteState = noteState
        _noteText = State(initialValue: noteState.currentNote?.content ?? "")
        _title = State(initialValue: noteState.currentNote?.title ?? "")
        _selectedColor = selectedColor
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            TextField("Untitled", text: $title)
                .textFieldStyle(.plain)
                .font(.title2.weight(.medium))
                .foregroundColor(.black.opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .background(Color(selectedColor.backgroundColor))
                .onChange(of: title) { _, newTitle in
                    noteState.hasUnsavedChanges = true
                    triggerAutoSave()
                    window?.title = newTitle.isEmpty ? "Untitled" : newTitle
                }
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

            // Main Content Area
            switch editorMode {
            case .wysiwyg:
                MarkdownWYSIWYGEditor(
                    text: $noteText,
                    backgroundColor: NSColor(selectedColor.backgroundColor)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(Rectangle())
                .padding(.horizontal, 16)
                .background(Color(selectedColor.backgroundColor))
            case .plainText:
                MarkdownTextView(
                    text: $noteText,
                    font: .systemFont(ofSize: 16.8),
                    backgroundColor: Color(selectedColor.backgroundColor)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(Rectangle())
                .padding(.horizontal, 16)
                .background(Color(selectedColor.backgroundColor))
            case .preview:
                ScrollView {
                    VStack(alignment: .leading) {
                        Markdown(noteText)
                            .markdownTheme(.quickStickyNotes)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(selectedColor.backgroundColor))
            }
            
            // Bottom Toolbar
            GeometryReader { geometry in
                HStack(spacing: 12) {
                    // Left Section: Status and Word Count
                    HStack(spacing: 8) {
                        // Save Status
                        if noteState.hasUnsavedChanges {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                                .foregroundColor(.black.opacity(0.6))
                                .rotationEffect(.degrees(360))
                                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: noteState.hasUnsavedChanges)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green.opacity(0.8))
                        }

                        // Word Count
                        Text("\(noteText.split(separator: " ").count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.black.opacity(0.8))
                    }
                    
                    // Color Picker Section
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(allColors) { color in
                                Button(action: {
                                    selectedColor = color
                                }) {
                                    Circle()
                                        .fill(Color(color.backgroundColor))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: 2)
                                                .opacity(color.name == selectedColor.name ? 1 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if color.isCustom {
                                        Button(role: .destructive, action: {
                                            colorToDelete = color
                                            showingDeleteAlert = true
                                        }) {
                                            Label("Delete Color", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            
                            // Add Color Button
                            Button(action: {
                                if proManager.isProUser {
                                    showingColorPicker = true
                                } else {
                                    showingUpgradePrompt = true
                                }
                            }) {
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundColor(.black.opacity(0.6))
                                    )
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showingColorPicker) {
                                ColorPickerView(
                                    isPresented: $showingColorPicker,
                                    selectedColor: $selectedColor
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    Spacer()

                    // Right Section: Editor Mode Switcher
                    EditorModeSwitcher(
                        selectedMode: $editorMode,
                        availableWidth: geometry.size.width
                    )
                }
                .frame(height: 28)
                .padding(.horizontal, 12)
                .background(
                    Color.white
                        .opacity(0.5)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, y: -2)
                )
            }
            .frame(height: 28)
        }
        .frame(minWidth: 400, maxWidth: 900, minHeight: 320, maxHeight: 750)
        .background(Color(selectedColor.backgroundColor))
        .onChange(of: noteText) { _, _ in
            noteState.hasUnsavedChanges = true
            triggerAutoSave()
        }
        .onChange(of: selectedColor) { _, _ in
            noteState.hasUnsavedChanges = true
            triggerAutoSave()
        }
        .onReceive(externalChangeTimer) { _ in
            checkExternalChanges()
        }
        .onAppear {
            // Setup keyboard shortcut once
            KeyboardShortcuts.onKeyDown(for: .switchEditorMode) { [self] in
                editorMode = editorMode.next()
            }
            
            // Setup window focus observer
            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { _ in
                isWindowFocused = true
                KeyboardShortcuts.enable(.switchEditorMode)
            }
            
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { _ in
                isWindowFocused = false
                KeyboardShortcuts.disable(.switchEditorMode)
            }
            
            // Initial state
            if window?.isKeyWindow ?? false {
                isWindowFocused = true
                KeyboardShortcuts.enable(.switchEditorMode)
            } else {
                KeyboardShortcuts.disable(.switchEditorMode)
            }
        }
        .onDisappear {
            // Cleanup notifications and keyboard shortcuts
            NotificationCenter.default.removeObserver(self)
            KeyboardShortcuts.disable(.switchEditorMode)
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
        .alert("Delete Custom Color?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let color = colorToDelete {
                    UserDefaults.standard.deleteCustomColor(color)
                    if selectedColor.name == color.name {
                        selectedColor = .citrus
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this custom color? This action cannot be undone.")
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text(currentError?.alertTitle ?? "Error"),
                message: Text(currentError?.localizedDescription ?? "An unknown error occurred"),
                primaryButton: .default(Text("OK")),
                secondaryButton: .cancel(Text("Help")) {
                    handleErrorHelp()
                }
            )
        }
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView()
        }
    }
    
    private func saveNote(completion: ((Bool) -> Void)? = nil) {
        Task {
            do {
                if let note = noteState.currentNote {
                    // Update existing note with title, content and color
                    let updatedNote = try await NoteSaveService.shared.saveNote(
                        note,
                        newTitle: title.isEmpty ? "Untitled" : title,
                        newContent: noteText,
                        colorName: selectedColor.name
                    )
                    await MainActor.run {
                        noteState.currentNote = updatedNote
                        noteState.hasUnsavedChanges = false
                    }
                } else {
                    // Create new note
                    let newNote = try await notesManager.createNote(
                        title: window?.title ?? "Untitled",
                        content: noteText
                    )
                    await MainActor.run {
                        noteState.currentNote = newNote
                        noteState.hasUnsavedChanges = false
                        // Add to recent notes after creating
                        RecentNotesManager.shared.addRecentNote(filePath: newNote.filePath)
                    }
                }
                completion?(true)
            } catch let error as FileError {
                await MainActor.run {
                    currentError = error
                    showError = true
                    completion?(false)
                }
            } catch {
                await MainActor.run {
                    currentError = .invalidFile(error.localizedDescription)
                    showError = true
                    completion?(false)
                }
            }
        }
    }
    
    private func handleErrorHelp() {
        guard let error = currentError else { return }
        
        switch error {
        case .noDirectoryAccess:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
        case .writePermissionDenied:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
        case .diskFull:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Storage.prefPane"))
        default:
            break
        }
    }
    
    private func triggerAutoSave() {
        autoSave.trigger {
            saveNote()
        }
    }
    
    private func checkExternalChanges() {
        Task {
            // Only check if we have a note and it's not being edited
            guard noteState.currentNote != nil else { return }
            
            if await noteState.checkExternalChanges() {
                // Only show alert if we haven't already
                if !showingExternalChangeAlert {
                    await MainActor.run {
                        showingExternalChangeAlert = true
                    }
                }
            } else {
                // If changes were handled automatically, make sure alert is hidden
                if showingExternalChangeAlert {
                    await MainActor.run {
                        showingExternalChangeAlert = false
                        noteState.hasExternalChanges = false
                    }
                }
            }
        }
    }
}

// Debounced auto-save helper
class DebouncedSave: ObservableObject {
    private var workItem: DispatchWorkItem?
    
    deinit {
        workItem?.cancel()
    }
    
    func trigger(action: @escaping () -> Void) {
        workItem?.cancel()
        
        let newWorkItem = DispatchWorkItem {
            action()
        }
        workItem = newWorkItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: newWorkItem)
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Editor Mode Switcher
private struct EditorModeSwitcher: View {
    @Binding var selectedMode: EditorMode
    let availableWidth: CGFloat
    @State private var hoverMode: EditorMode?
    
    private var showLabels: Bool {
        availableWidth > 500
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(EditorMode.allCases) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11))
                        
                        if showLabels {
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, showLabels ? 8 : 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selectedMode == mode ? Color.black.opacity(0.1) : Color.clear)
                    )
                    .foregroundColor(selectedMode == mode ? .black.opacity(0.85) : .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoverMode = isHovered ? mode : nil
                    }
                }
                .scaleEffect(hoverMode == mode ? 1.05 : 1.0)
            }
        }
    }
}


