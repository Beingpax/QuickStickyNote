import SwiftUI

struct SettingsView: View {
    @StateObject private var notesManager = NotesManager.shared
    @State private var isShowingDirectoryPicker = false
    @State private var showingResetAlert = false
    
    var body: some View {
        List {
            Section {
                if notesManager.isDirectoryConfigured {
                    HStack {
                        Text("Current Directory")
                        Spacer()
                        Text(notesManager.notesDirectory?.lastPathComponent ?? "")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Button(notesManager.isDirectoryConfigured ? "Change Directory" : "Select Directory") {
                    isShowingDirectoryPicker = true
                }
                
                if notesManager.isDirectoryConfigured {
                    Button("Reset Directory", role: .destructive) {
                        showingResetAlert = true
                    }
                }
                
                if let error = notesManager.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
        }
        .sheet(isPresented: $isShowingDirectoryPicker) {
            NavigationStack {
                DirectoryPickerView { url in
                    notesManager.setNotesDirectory(url)
                    isShowingDirectoryPicker = false
                }
                .navigationTitle("Select Directory")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingDirectoryPicker = false
                        }
                    }
                }
            }
        }
        .alert("Reset Directory?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                notesManager.resetDirectory()
            }
        } message: {
            Text("This will clear the current directory setting. You'll need to select a new directory to store your notes.")
        }
    }
}

#Preview {
    SettingsView()
} 