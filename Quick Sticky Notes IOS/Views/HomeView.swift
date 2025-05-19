import SwiftUI

struct HomeView: View {
    @StateObject private var notesManager = NotesManager.shared
    
    var body: some View {
        NavigationStack {
            TabView {
                AllNotesView()
                    .tabItem {
                        Label("All Notes", systemImage: "doc.text.fill")
                    }
                
                PinnedNotesView()
                    .tabItem {
                        Label("Pinned", systemImage: "pin.fill")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .navigationTitle("Quick Sticky Notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createNewNote) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
        }
    }
    
    private func createNewNote() {
        // Create a new empty note
        let newNote = FileNote(
            filePath: "", // Will be set when saved
            title: "",
            content: "",
            colorName: "citrus",
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        // Present the detail view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            let detailView = NoteDetailView(note: newNote)
            let hostingController = UIHostingController(rootView: detailView)
            let navigationController = UINavigationController(rootViewController: hostingController)
            rootViewController.present(navigationController, animated: true)
        }
    }
}

#Preview {
    HomeView()
} 