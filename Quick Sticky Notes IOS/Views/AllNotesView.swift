import SwiftUI

enum NoteSortOption: String, CaseIterable {
    case modifiedDate = "Modified"
    case createdDate = "Created"
    case title = "Title"
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .frame(width: 50, height: 50)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                
                Text("Loading Notes...")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .onAppear {
                isAnimating = true
            }
        }
    }
}

struct AllNotesView: View {
    @StateObject private var notesManager = NotesManager.shared
    @StateObject private var pinnedService = PinnedNotesService.shared
    @State private var searchText = ""
    @State private var sortOption: NoteSortOption = .modifiedDate
    @State private var sortAscending = false
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Sort Bar
                VStack(spacing: 8) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Sort Options and Note Count
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Note Count
                            HStack {
                                Image(systemName: "doc.text")
                                Text("\(filteredNotes.count) notes")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .foregroundColor(.secondary)
                            .cornerRadius(8)
                            
                            ForEach(NoteSortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    if sortOption == option {
                                        sortAscending.toggle()
                                    } else {
                                        sortOption = option
                                        sortAscending = false
                                    }
                                }) {
                                    HStack {
                                        Text(option.rawValue)
                                        if sortOption == option {
                                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(sortOption == option ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                                    .foregroundColor(sortOption == option ? .accentColor : .primary)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                
                // Notes List
                if notesManager.notes.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredNotes) { note in
                            NavigationLink(destination: NoteDetailView(note: note)) {
                                NoteRowView(note: note, isPinned: pinnedService.isPinned(note))
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    try? notesManager.deleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    pinnedService.togglePin(for: note)
                                } label: {
                                    if pinnedService.isPinned(note) {
                                        Label("Unpin", systemImage: "pin.slash")
                                    } else {
                                        Label("Pin", systemImage: "pin")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        notesManager.forceRefresh()
                    }
                }
            }
            .overlay {
                if notesManager.isLoading {
                    LoadingView()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No Notes")
                .font(.title2)
            Text("Your notes will appear here")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct NoteRowView: View {
    let note: FileNote
    let isPinned: Bool
    
    private var noteColor: Color {
        Color(NoteColor.defaultColors.first { $0.name == note.colorName }?.backgroundColor ?? NoteColor.citrus.backgroundColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.headline)
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            Text(note.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text(note.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .listRowBackground(noteColor.opacity(0.1))
    }
}

#Preview {
    AllNotesView()
} 