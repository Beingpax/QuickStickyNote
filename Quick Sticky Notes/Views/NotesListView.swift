import SwiftUI
import UniformTypeIdentifiers

// Sort options for notes
enum NoteSortOption: String, CaseIterable {
    case modifiedDate = "Last Modified"
    case createdDate = "Date Created"
    case title = "Title"
    
    var systemImage: String {
        switch self {
        case .modifiedDate: return "clock.arrow.circlepath"
        case .createdDate: return "calendar.badge.plus"
        case .title: return "textformat.size"
        }
    }
}

struct ModernSortButton: View {
    let option: NoteSortOption
    let isSelected: Bool
    let isAscending: Bool
    let action: () -> Void
    @Environment(\.sizeCategory) var sizeCategory
    
    private var labelText: String {
        switch option {
        case .modifiedDate: return "Modified Date"
        case .createdDate: return "Created Date"
        case .title: return isAscending ? "A to Z" : "Z to A"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                // Icon
                Image(systemName: option.systemImage)
                    .font(.system(size: 12, weight: .medium))
                
                // Label (only shows when space available)
                Text(labelText)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .layoutPriority(1)
                
                // Sort direction indicator
                if isSelected {
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minWidth: 36, idealWidth: 120)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .help(option.rawValue)
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                
                Text("Loading Notes...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            .cornerRadius(8)
        }
    }
}

struct NotesListView: View {
    @Environment(\.window) private var window
    @StateObject private var notesManager = NotesManager.shared
    @AppStorage("notesDirectory") private var notesDirectory: String = ""
    
    // View States
    @State private var searchText = ""
    @State private var gridColumns = 3
    @State private var noteToDelete: FileNote?
    @State private var showingDeleteAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var sortOption: NoteSortOption = .modifiedDate
    @State private var sortAscending = false
    @State private var showingResetDirectoryAlert = false
    
    // Computed Properties
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: gridColumns)
    }
    
    private var filteredNotes: [FileNote] {
        var notes = notesManager.notes
        
        // Apply search filter
        if !searchText.isEmpty {
            notes = notes.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        notes.sort { note1, note2 in
            let ascending = sortAscending ? 1 : -1
            switch sortOption {
            case .modifiedDate:
                return note1.modifiedAt.compare(note2.modifiedAt) == (sortAscending ? .orderedAscending : .orderedDescending)
            case .createdDate:
                return note1.createdAt.compare(note2.createdAt) == (sortAscending ? .orderedAscending : .orderedDescending)
            case .title:
                return (note1.title.localizedCompare(note2.title) == .orderedAscending) == sortAscending
            }
        }
        
        return notes
    }
    
    // Date Formatter
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern Toolbar
            toolbarView
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(hex: "#1E1E1E"))
            
            if notesManager.isLoading {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#2A2A2A"))
                            .frame(width: 80, height: 80)
                        
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(.circular)
                            .controlSize(.large)
                    }
                    
                    Text("Loading Notes...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#9B9B9B"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#1E1E1E"))
            } else if notesManager.notes.isEmpty {
                emptyStateView
            } else {
                // Content with improved styling
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredNotes) { note in
                            NoteCardView(
                                note: note,
                                dateFormatter: Self.dateFormatter,
                                onDelete: {
                                    noteToDelete = note
                                    showingDeleteAlert = true
                                }
                            )
                            .onTapGesture {
                                openNote(note)
                            }
                            .contextMenu {
                                Button("Delete") {
                                    noteToDelete = note
                                    showingDeleteAlert = true
                                }
                                Button("Refresh") {
                                    notesManager.forceRefresh()
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .background(Color(hex: "#1E1E1E"))
                .refreshable {
                    await refreshNotes()
                }
            }
            
            if let progress = notesManager.importProgress {
                importProgressView(progress)
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .preferredColorScheme(.dark)
        .alert("Delete Note?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    deleteNote(note)
                }
            }
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Reset Notes Directory?", isPresented: $showingResetDirectoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetDirectory()
            }
        } message: {
            Text("This will clear the current directory setting. You'll need to choose a new directory before creating or viewing notes. Existing notes will not be deleted.")
        }
    }
    
    private func deleteNote(_ note: FileNote) {
        do {
            try notesManager.deleteNote(note)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func openNote(_ note: FileNote) {
        // First close the notes list window
        if let listWindow = self.window {
            listWindow.close()
            
            // Then open the note window
            DispatchQueue.main.async {
                let window = EditNoteWindow(note: note)
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Directory Selector Button
            DirectorySelectorButton(
                notesDirectory: $notesDirectory,
                notesManager: notesManager,
                showingResetAlert: $showingResetDirectoryAlert
            )
            .frame(maxWidth: 200)
            
            // Modern Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "#9B9B9B"))
                    .font(.system(size: 13))
                TextField("Search", text: $searchText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "#9B9B9B"))
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(8)
            .background(Color(hex: "#2D2D2D"))
            .cornerRadius(8)
            .frame(maxWidth: .infinity)
            
            // Compact Sorting Controls
            HStack(spacing: 4) {
                ForEach(NoteSortOption.allCases, id: \.self) { option in
                    ModernSortButton(
                        option: option,
                        isSelected: sortOption == option,
                        isAscending: sortAscending,
                        action: {
                            if sortOption == option {
                                sortAscending.toggle()
                            } else {
                                sortOption = option
                                sortAscending = false
                            }
                        }
                    )
                }
            }
            .frame(minWidth: 120, maxWidth: 400)  // Allow flexible width for labels
            
            // Note Counter
            Group {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                    Text(searchText.isEmpty ? "\(notesManager.notes.count)" : "\(filteredNotes.count)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color(hex: "#9B9B9B"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#2D2D2D"))
                .cornerRadius(6)
            }
            
            Spacer()
            
            // Import Button
            Button(action: showImportPicker) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import")
                        .lineLimit(1)
                }
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(ModernButtonStyle(isCompact: true))
            
            // Grid Controls
            HStack(spacing: 0) {
                ForEach([2, 3, 4], id: \.self) { count in
                    Button(action: { withAnimation { gridColumns = count }}) {
                        Image(systemName: "square.grid.\(count)x2.fill")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(ModernGridButtonStyle(isSelected: gridColumns == count))
                }
            }
            .background(Color(hex: "#2D2D2D"))
            .cornerRadius(8)
        }
        .frame(maxHeight: 40)  // Increased height for better touch targets
    }
    
    private func importProgressView(_ progress: NotesManager.ImportProgress) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("Importing files...")
                Spacer()
                Text("\(progress.completed)/\(progress.total)")
            }
            
            HStack(spacing: 8) {
                if progress.successful > 0 {
                    Label("\(progress.successful) succeeded", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                if progress.failed > 0 {
                    Label("\(progress.failed) failed", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func showImportPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType.plainText,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "txt")!
        ]
        
        if panel.runModal() == .OK {
            let paths = panel.urls.map { $0.path }
            Task {
                await notesManager.importFiles(from: paths)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#2A2A2A"))
                    .frame(width: 80, height: 80)
                
                Image(systemName: notesManager.isDirectoryConfigured ? "note.text" : "folder.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "#9B9B9B"))
            }
            
            VStack(spacing: 12) {
                Text(notesManager.isDirectoryConfigured ? "No Notes Yet" : "Welcome to Quick Sticky Notes")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                if notesManager.isDirectoryConfigured {
                    Text("Create your first note using menu bar option or command you set earlier.")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#9B9B9B"))
                        .multilineTextAlignment(.center)
                } else {
                    Text("Choose a directory to store your notes.\nYour notes will be saved as markdown files that you can use with other apps.")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#9B9B9B"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            if notesManager.isDirectoryConfigured {
                Button(action: showImportPicker) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Notes")
                    }
                    .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(ModernButtonStyle())
            } else {
                Button(action: chooseDirectory) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Choose Notes Directory")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(ModernButtonStyle())
                
                Button(action: showPreferences) {
                    Text("Open Preferences")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(ModernSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#1E1E1E"))
    }
    
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory to store your notes"
        panel.prompt = "Set Directory"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                notesManager.setNotesDirectory(url)
                if notesManager.isDirectoryConfigured {
                    notesDirectory = url.path
                }
            }
        }
    }
    
    private func resetDirectory() {
        notesDirectory = ""
        UserDefaults.standard.removeObject(forKey: "notesDirectory")
        notesManager.resetDirectory()
    }
    
    private func refreshNotes() async {
        await MainActor.run {
            notesManager.forceRefresh()
        }
    }
    
    private func showPreferences() {
        let preferencesWindow = PreferencesWindowController()
        preferencesWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Modern Button Styles
struct ModernButtonStyle: ButtonStyle {
    var isCompact: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, isCompact ? 8 : 14)
            .padding(.vertical, isCompact ? 4 : 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#FF6B6B").opacity(configuration.isPressed ? 0.8 : 1))
            )
            .foregroundColor(.white)
    }
}

struct ModernGridButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isSelected ? Color(hex: "#FF6B6B") : Color(hex: "#9B9B9B"))
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: "#FF6B6B").opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Note Card View
struct NoteCardView: View {
    let note: FileNote
    let dateFormatter: DateFormatter
    var onDelete: () -> Void
    
    @State private var isHovered = false
    
    private var noteColor: NoteColor {
        // First check default colors, then custom colors
        NoteColor.defaultColors.first { $0.name == note.colorName } ??
        UserDefaults.standard.getCustomColors().first { $0.name == note.colorName } ??
        .citrus
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                Spacer()
                
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            
            // Content
            Text(note.content)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.8))
                .lineLimit(6)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
            
            // Footer
            HStack {
                Text(dateFormatter.string(from: note.modifiedAt))
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.6))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220)
        .drawingGroup() // Stabilize rendering
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(noteColor.backgroundColor))
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.15 : 0.1),
                    radius: isHovered ? 12 : 8,
                    y: isHovered ? 4 : 2
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Directory Selector Button
struct DirectorySelectorButton: View {
    @Binding var notesDirectory: String
    @ObservedObject var notesManager: NotesManager
    @Binding var showingResetAlert: Bool
    @State private var showingDirectoryPicker = false
    
    private var displayPath: String {
        let url = URL(fileURLWithPath: notesDirectory)
        return url.lastPathComponent
    }
    
    var body: some View {
        Menu {
            Button(action: {}) {
                Text(notesDirectory)
                    .truncationMode(.middle)
            }
            .disabled(true)
            
            Divider()
            
            Button(action: chooseDirectory) {
                Label("Change Directory...", systemImage: "folder.badge.plus")
            }
            
            Button(action: openInFinder) {
                Label("Open in Finder", systemImage: "folder")
            }
            .disabled(notesDirectory.isEmpty)
            
            Divider()
            
            Button(role: .destructive, action: { showingResetAlert = true }) {
                Label("Reset Directory", systemImage: "arrow.counterclockwise")
            }
            .disabled(notesDirectory.isEmpty)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                Text(displayPath)
                    .lineLimit(1)
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: 200)
    }
    
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory to store your notes"
        panel.prompt = "Set Directory"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                notesManager.setNotesDirectory(url)
                if notesManager.isDirectoryConfigured {
                    notesDirectory = url.path
                }
            }
        }
    }
    
    private func openInFinder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: notesDirectory))
    }
}
