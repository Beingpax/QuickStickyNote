import Foundation

class RecentNotesManager: ObservableObject {
    static let shared = RecentNotesManager()
    private let maxRecentNotes = 10
    private let userDefaultsKey = "recentNotes"
    
    @Published private(set) var recentNotes: [String] = []
    
    init() {
        loadRecentNotes()
    }
    
    private func loadRecentNotes() {
        recentNotes = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }
    
    private func saveRecentNotes() {
        UserDefaults.standard.set(recentNotes, forKey: userDefaultsKey)
    }
    
    func addRecentNote(filePath: String) {
        // Remove if already exists to avoid duplicates
        recentNotes.removeAll { $0 == filePath }
        
        // Add to the beginning
        recentNotes.insert(filePath, at: 0)
        
        // Keep only the most recent notes
        if recentNotes.count > maxRecentNotes {
            recentNotes = Array(recentNotes.prefix(maxRecentNotes))
        }
        
        saveRecentNotes()
    }
    
    func removeRecentNote(filePath: String) {
        recentNotes.removeAll { $0 == filePath }
        saveRecentNotes()
    }
    
    func clearRecentNotes() {
        recentNotes.removeAll()
        saveRecentNotes()
    }
} 