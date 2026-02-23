import SwiftUI
import AppKit

// MARK: - Sidebar Panel View

struct SidebarPanelView: View {
    @StateObject private var notesManager = NotesManager.shared
    @State private var searchText  = ""
    @State private var sortBy: SortBy = .modified
    @State private var selectedNote: FileNote? = nil

    enum SortBy: String, CaseIterable {
        case modified = "Modified"
        case created  = "Created"
        case title    = "Name"
    }

    private var displayedNotes: [FileNote] {
        let base = searchText.isEmpty
            ? notesManager.notes
            : notesManager.notes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
              }
        switch sortBy {
        case .modified: return base.sorted { $0.modifiedAt > $1.modifiedAt }
        case .created:  return base.sorted { $0.createdAt  > $1.createdAt  }
        case .title:    return base.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        }
    }

    var body: some View {
        ZStack {
            if let note = selectedNote {
                SidebarNoteDetailView(note: note, onBack: navigateBack)
                    .transition(.opacity)
            } else {
                listView
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 12, bottomLeadingRadius: 12,
                bottomTrailingRadius: 0, topTrailingRadius: 0,
                style: .continuous
            )
            .fill(.regularMaterial)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 12, bottomLeadingRadius: 12,
                bottomTrailingRadius: 0, topTrailingRadius: 0,
                style: .continuous
            )
        )
    }

    // MARK: - List View

    private var listView: some View {
        VStack(spacing: 0) {
            headerBar
            searchBar
            sortBar
            Divider().opacity(0.5)
            notesList
        }
    }

    private var headerBar: some View {
        HStack(spacing: 0) {
            Text("Notes")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Button(action: createAndOpenNote) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New Note")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            TextField("Search \(notesManager.notes.count) notes…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var sortBar: some View {
        HStack(spacing: 4) {
            Text("Sort:")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Picker("Sort", selection: $sortBy) {
                ForEach(SortBy.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .font(.system(size: 11))
            .labelsHidden()
            .fixedSize()
            Spacer()
            Group {
                if !searchText.isEmpty {
                    Text("\(displayedNotes.count) of \(notesManager.notes.count)")
                } else {
                    Text("\(notesManager.notes.count) notes")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var notesList: some View {
        if notesManager.isLoading {
            VStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Loading…").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !notesManager.isDirectoryConfigured {
            VStack(spacing: 10) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 30)).foregroundStyle(.secondary)
                Text("No notes folder selected")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayedNotes.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                    .font(.system(size: 28)).foregroundStyle(.secondary)
                Text(searchText.isEmpty ? "No notes yet" : "No results")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(displayedNotes, id: \.filePath) { note in
                        SidebarNoteRow(note: note) { openNote(note) }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Navigation

    private func openNote(_ note: FileNote) {
        SidebarManager.shared.isInDetailMode = true
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedNote = note
        }
    }

    private func navigateBack() {
        SidebarManager.shared.isInDetailMode = false
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedNote = nil
        }
    }

    private func createAndOpenNote() {
        guard notesManager.isDirectoryConfigured else { return }
        Task { @MainActor in
            do {
                let note = try await notesManager.createNote(title: "Untitled", content: "")
                openNote(note)
            } catch {
                print("Failed to create note: \(error)")
            }
        }
    }
}

// MARK: - Note Detail View

struct SidebarNoteDetailView: View {
    let onBack: () -> Void

    @State private var currentNote: FileNote
    @State private var title:       String
    @State private var content:     String
    @State private var isSaving:         Bool = false
    @State private var showColorPicker:  Bool = false
    @State private var contentSaveTask: Task<Void, Never>? = nil
    @State private var titleSaveTask:   Task<Void, Never>? = nil

    private var noteColor: Color {
        resolveColor(for: currentNote.colorName)
    }

    init(note: FileNote, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _currentNote = State(initialValue: note)
        _title       = State(initialValue: note.title)
        _content     = State(initialValue: note.content)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            titleRow
            Divider().opacity(0.5)
            editor
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .sidebarNavigateBack)) { _ in
            onBack()
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Notes")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            if isSaving {
                ProgressView().scaleEffect(0.55).frame(width: 16, height: 16)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: Title Row (color dot + title field)

    private var titleRow: some View {
        HStack(spacing: 8) {
            Button { showColorPicker.toggle() } label: {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(noteColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: noteColor.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                colorPickerPopover
            }

            TextField("Untitled", text: $title)
                .font(.system(size: 15, weight: .semibold))
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
                .onChange(of: title) { _, _ in scheduleRename() }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private var colorPickerPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            let custom = UserDefaults.standard.getCustomColors()
            HStack(spacing: 8) {
                ForEach(NoteColor.defaultColors) { color in
                    colorSwatch(color)
                }
            }
            if !custom.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    ForEach(custom) { color in
                        colorSwatch(color)
                    }
                }
            }
        }
        .padding(12)
    }

    private func colorSwatch(_ color: NoteColor) -> some View {
        let isSelected = currentNote.colorName == color.name
        return Circle()
            .fill(Color(color.backgroundColor))
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .strokeBorder(
                        isSelected ? Color.primary.opacity(0.6) : Color.primary.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .overlay(
                isSelected
                    ? Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.7))
                    : nil
            )
            .onTapGesture {
                changeColor(to: color)
                showColorPicker = false
            }
    }

    // MARK: Editor

    private var editor: some View {
        TextEditor(text: $content)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .background(.clear)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .onChange(of: content) { _, _ in scheduleContentSave() }
    }

    // MARK: Save / Rename / Color

    private func scheduleContentSave() {
        contentSaveTask?.cancel()
        contentSaveTask = Task {
            do { try await Task.sleep(nanoseconds: 800_000_000) } catch { return }
            guard !Task.isCancelled else { return }
            await MainActor.run { isSaving = true }
            do {
                let updated = try await NoteSaveService.shared.saveNote(currentNote, newContent: content)
                await MainActor.run { currentNote = updated }
            } catch { print("Content save error: \(error)") }
            await MainActor.run { isSaving = false }
        }
    }

    private func scheduleRename() {
        titleSaveTask?.cancel()
        titleSaveTask = Task {
            do { try await Task.sleep(nanoseconds: 800_000_000) } catch { return }
            guard !Task.isCancelled else { return }
            let newTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newTitle.isEmpty else { return }
            await MainActor.run { isSaving = true }
            do {
                let updated = try await NoteSaveService.shared.renameNote(currentNote, newTitle: newTitle)
                await MainActor.run { currentNote = updated }
            } catch { print("Rename error: \(error)") }
            await MainActor.run { isSaving = false }
        }
    }

    private func changeColor(to color: NoteColor) {
        currentNote.colorName = color.name
        contentSaveTask?.cancel()
        contentSaveTask = Task {
            await MainActor.run { isSaving = true }
            do {
                let updated = try await NoteSaveService.shared.saveNote(
                    currentNote, newContent: content, colorName: color.name
                )
                await MainActor.run { currentNote = updated }
            } catch { print("Color save error: \(error)") }
            await MainActor.run { isSaving = false }
        }
    }

    // MARK: Helpers

    private func resolveColor(for name: String) -> Color {
        if let c = NoteColor.defaultColors.first(where: { $0.name == name }) { return Color(c.backgroundColor) }
        if let c = UserDefaults.standard.getCustomColors().first(where: { $0.name == name }) { return Color(c.backgroundColor) }
        return Color(NoteColor.citrus.backgroundColor)
    }
}

// MARK: - Sidebar Note Row

struct SidebarNoteRow: View {
    let note: FileNote
    let onTap: () -> Void
    @State private var isHovered = false

    private var noteColor: Color {
        if let c = NoteColor.defaultColors.first(where: { $0.name == note.colorName }) {
            return Color(c.backgroundColor)
        }
        if let c = UserDefaults.standard.getCustomColors().first(where: { $0.name == note.colorName }) {
            return Color(c.backgroundColor)
        }
        return Color(NoteColor.citrus.backgroundColor)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(noteColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: noteColor.opacity(0.5), radius: 2, x: 0, y: 1)

                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            )
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) { isHovered = hovering }
        }
    }
}

// MARK: - Pill Indicator View

struct PillView: View {
    var body: some View {
        Capsule()
            .fill(.secondary.opacity(0.35))
            .frame(width: 5, height: 36)
            .shadow(color: .black.opacity(0.15), radius: 3, x: -1, y: 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
