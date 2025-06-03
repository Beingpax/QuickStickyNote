import SwiftUI

struct RecentNotesView: View {
    @Environment(\.window) private var window
    @StateObject private var recentNotesManager = RecentNotesManager.shared
    @StateObject private var notesManager = NotesManager.shared
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        ZStack {
            if recentNotesManager.recentNotes.isEmpty {
                emptyStateView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(recentNotesManager.recentNotes, id: \.self) { filePath in
                            if let note = try? FileNote.from(filePath: filePath) {
                                RecentNoteCard(note: note, onOpen: openNote)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.top, 40) // Extra space for close button
                }
            }
            
            // Close button overlay - floating in top right
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            window?.close()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 26, height: 26)
                            .background(.thinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                Spacer()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 28) {
            Circle()
                .fill(.thinMaterial)
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.secondary)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            
            VStack(spacing: 12) {
                Text("No Recent Notes")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Notes you open will appear here")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func openNote(_ note: FileNote) {
        window?.close()
        let noteWindow = EditNoteWindow(note: note)
        noteWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct RecentNoteCard: View {
    let note: FileNote
    let onOpen: (FileNote) -> Void
    @State private var isHovered = false
    
    private var noteColor: NoteColor {
        // First check default colors
        if let defaultColor = NoteColor.defaultColors.first(where: { $0.name == note.colorName }) {
            return defaultColor
        }
        // Then check custom colors
        if let customColor = UserDefaults.standard.getCustomColors().first(where: { $0.name == note.colorName }) {
            return customColor
        }
        // Fallback to citrus
        return .citrus
    }
    
    var body: some View {
        Button(action: { onOpen(note) }) {
            VStack(alignment: .leading, spacing: 0) {
                // Main content
                VStack(alignment: .leading, spacing: 8) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(note.content.prefix(120))
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.7))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Bottom bar with timestamp
                HStack {
                    Text(note.modifiedAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.black.opacity(0.5))
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.black.opacity(0.4))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(noteColor.backgroundColor))
                    .shadow(
                        color: .black.opacity(isHovered ? 0.1 : 0.06), 
                        radius: isHovered ? 8 : 4, 
                        x: 0, 
                        y: isHovered ? 4 : 2
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
} 
