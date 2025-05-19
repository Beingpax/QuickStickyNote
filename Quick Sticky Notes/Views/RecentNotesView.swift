import SwiftUI

struct RecentNotesView: View {
    @Environment(\.window) private var window
    @StateObject private var recentNotesManager = RecentNotesManager.shared
    @StateObject private var notesManager = NotesManager.shared
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 0) {
            if recentNotesManager.recentNotes.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recentNotesManager.recentNotes, id: \.self) { filePath in
                            if let note = try? FileNote.from(filePath: filePath) {
                                RecentNoteCard(note: note, onOpen: openNote)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Recent Notes")
                .font(.headline)
            Text("Notes you open will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func openNote(_ note: FileNote) {
        // Close the recent notes window
        window?.close()
        
        // Open the note window
        let noteWindow = EditNoteWindow(note: note)
        noteWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct RecentNoteCard: View {
    let note: FileNote
    let onOpen: (FileNote) -> Void
    
    var body: some View {
        Button(action: { onOpen(note) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(note.content.prefix(100))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(note.modifiedAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
} 