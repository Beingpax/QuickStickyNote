import Foundation

@MainActor
class PinnedNotesService: ObservableObject {
    static let shared = PinnedNotesService()
    
    private let defaults = UserDefaults.standard
    private let pinnedNotesKey = "pinnedNotesPaths"
    
    @Published private(set) var pinnedNotePaths: Set<String> = []
    
    private init() {
        // Load pinned notes from UserDefaults
        if let paths = defaults.stringArray(forKey: pinnedNotesKey) {
            pinnedNotePaths = Set(paths)
        }
    }
    
    func isPinned(_ note: FileNote) -> Bool {
        pinnedNotePaths.contains(note.filePath)
    }
    
    func togglePin(for note: FileNote) {
        if isPinned(note) {
            pinnedNotePaths.remove(note.filePath)
        } else {
            pinnedNotePaths.insert(note.filePath)
        }
        savePinnedNotes()
    }
    
    private func savePinnedNotes() {
        defaults.set(Array(pinnedNotePaths), forKey: pinnedNotesKey)
    }
} 