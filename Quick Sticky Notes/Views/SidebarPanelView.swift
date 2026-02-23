import SwiftUI
import AppKit

// MARK: - Sidebar Panel View

struct SidebarPanelView: View {
    @StateObject private var notesManager = NotesManager.shared
    @State private var searchText = ""
    @State private var sortBy: SortBy = .modified

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
        VStack(spacing: 0) {
            headerBar
            searchBar
            sortBar
            Divider()
                .opacity(0.5)
            notesList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(.regularMaterial)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
    }

    // MARK: Header

    private var headerBar: some View {
        HStack(spacing: 0) {
            Text("Notes")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: newNote) {
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

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            TextField("Search \(notesManager.notes.count) notes…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
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

    // MARK: Sort Bar

    private var sortBar: some View {
        HStack(spacing: 4) {
            Text("Sort:")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Picker("Sort", selection: $sortBy) {
                ForEach(SortBy.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
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

    // MARK: Notes List

    @ViewBuilder
    private var notesList: some View {
        if notesManager.isLoading {
            VStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Loading…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if !notesManager.isDirectoryConfigured {
            VStack(spacing: 10) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("No notes folder selected")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if displayedNotes.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(searchText.isEmpty ? "No notes yet" : "No results")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(displayedNotes, id: \.filePath) { note in
                        SidebarNoteRow(note: note) {
                            openNote(note)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Actions

    private func openNote(_ note: FileNote) {
        let window = EditNoteWindow(note: note)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func newNote() {
        guard notesManager.isDirectoryConfigured else { return }
        let window = EditNoteWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
                // Color indicator
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(noteColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: noteColor.opacity(0.5), radius: 2, x: 0, y: 1)

                // Title
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
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Pill Indicator View

/// The small visual handle shown at the right edge when the sidebar is hidden.
struct PillView: View {
    var body: some View {
        Capsule()
            .fill(.secondary.opacity(0.35))
            .frame(width: 5, height: 36)
            .shadow(color: .black.opacity(0.15), radius: 3, x: -1, y: 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

