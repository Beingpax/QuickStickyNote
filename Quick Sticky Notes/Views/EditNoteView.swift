import SwiftUI
import Combine
import MarkdownUI
import KeyboardShortcuts

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
    @State private var isPreviewMode: Bool = false
    @State private var showingUpgradePrompt = false
    @State private var showingLicenseView = false
    @State private var showingExternalChangeAlert = false
    
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
            // Title Field
            TextField("", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .placeholder(when: title.isEmpty) {
                    Text("Untitled")
                        .foregroundColor(.black.opacity(0.6))
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                }
                .onChange(of: title) { _, newValue in
                    noteState.hasUnsavedChanges = true
                    window?.title = newValue.isEmpty ? "Untitled" : newValue
                    triggerAutoSave()
                }
            
            Divider()
                .background(Color.black.opacity(0.2))
                .frame(height: 1)
            
            // Main Content Area
            if isPreviewMode {
                ScrollView {
                    VStack(alignment: .leading) {
                        Markdown(noteText)
                            .markdownTheme(.quickStickyNotes)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(selectedColor.backgroundColor))
            } else {
                MarkdownTextView(
                    text: $noteText,
                    backgroundColor: Color(selectedColor.backgroundColor)
                )
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(Rectangle())
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
            
            // Bottom Toolbar
            HStack(spacing: 16) {
                // Left Section: Status and Word Count
                HStack(spacing: 8) {
                    // Save Status
                    if noteState.hasUnsavedChanges {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(360))
                            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: noteState.hasUnsavedChanges)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }

                    // Word Count
                    Text("\(noteText.split(separator: " ").count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.black.opacity(0.8))
                    
                    // Edit/Preview Toggle Button
                    Button(action: { isPreviewMode.toggle() }) {
                        HStack(spacing: 2) {
                            Image(systemName: isPreviewMode ? "pencil" : "eye")
                                .font(.system(size: 10))
                            Text(isPreviewMode ? "Edit" : "Preview")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.black.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Color Selection Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allColors, id: \.name) { color in
                            Button(action: {
                                if color.name == "citrus" || proManager.canAccessProFeatures {
                                    selectedColor = color
                                } else {
                                    showingUpgradePrompt = true
                                }
                            }) {
                                Circle()
                                    .fill(Color(color.backgroundColor))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: 2)
                                            .opacity(color.name == selectedColor.name ? 1 : 0)
                                    )
                                    .overlay(
                                        color.name != "citrus" && !proManager.canAccessProFeatures ?
                                        Circle()
                                            .fill(Color.black.opacity(0.3))
                                            .overlay(
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.white)
                                            )
                                        : nil
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
                        Button(action: { showingColorPicker = true }) {
                            Circle()
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.secondary)
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Color.white
                    .opacity(0.5)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, y: -2)
            )
        }
        .frame(minWidth: 300, minHeight: 220)
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
            KeyboardShortcuts.onKeyDown(for: .togglePreviewMode) { [self] in
                isPreviewMode.toggle()
            }
            
            // Setup window focus observer
            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { _ in
                isWindowFocused = true
                KeyboardShortcuts.enable(.togglePreviewMode)
            }
            
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { _ in
                isWindowFocused = false
                KeyboardShortcuts.disable(.togglePreviewMode)
            }
            
            // Initial state
            if window?.isKeyWindow ?? false {
                isWindowFocused = true
                KeyboardShortcuts.enable(.togglePreviewMode)
            } else {
                KeyboardShortcuts.disable(.togglePreviewMode)
            }
        }
        .onDisappear {
            // Cleanup notifications and keyboard shortcuts
            NotificationCenter.default.removeObserver(self)
            KeyboardShortcuts.disable(.togglePreviewMode)
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


