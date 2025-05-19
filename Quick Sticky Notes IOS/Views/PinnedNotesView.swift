import SwiftUI

struct PinnedNotesView: View {
    @StateObject private var notesManager = NotesManager.shared
    @StateObject private var pinnedService = PinnedNotesService.shared
    
    private var pinnedNotes: [FileNote] {
        notesManager.notes.filter { pinnedService.isPinned($0) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if pinnedNotes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "pin.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Pinned Notes")
                            .font(.title2)
                        Text("Pin important notes for quick access")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(pinnedNotes) { note in
                            NavigationLink(destination: NoteDetailView(note: note)) {
                                NoteRowView(note: note, isPinned: true)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    try? notesManager.deleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button(role: .cancel) {
                                    pinnedService.togglePin(for: note)
                                } label: {
                                    Label("Unpin", systemImage: "pin.slash")
                                }
                                .tint(.gray)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        notesManager.forceRefresh()
                    }
                }
            }
        }
    }
}

#Preview {
    PinnedNotesView()
} 