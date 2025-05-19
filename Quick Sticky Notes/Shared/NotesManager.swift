import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

#if os(macOS)
// File presenter for coordinated file access
class FileCoordinationManager: NSObject, NSFilePresenter {
    var presentedItemURL: URL?
    var presentedItemOperationQueue: OperationQueue
    var onDirectoryChange: (() -> Void)?
    
    init(url: URL) {
        self.presentedItemURL = url
        self.presentedItemOperationQueue = OperationQueue()
        self.presentedItemOperationQueue.qualityOfService = .userInitiated
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }
    
    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }
    
    // Called when a directory or its contents changes
    func presentedSubitemDidChange(at url: URL) {
        // Filter to only markdown files
        if url.pathExtension.lowercased() == "md" {
            DispatchQueue.main.async { [weak self] in
                self?.onDirectoryChange?()
            }
        }
    }
    
    // Called when a directory itself changes
    func presentedItemDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.onDirectoryChange?()
        }
    }
    
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
    
    func stopMonitoring() {
        NSFileCoordinator.removeFilePresenter(self)
    }
}
#endif

@MainActor
class NotesManager: ObservableObject {
    static let shared = NotesManager()
    
    private let fileManager = FileManager.default
    private let importer = NoteImporter()
    @Published private(set) var notesDirectory: URL?
    
    #if os(macOS)
    private var fileCoordinator: FileCoordinationManager?
    #else
    private var directoryMonitor: DirectoryMonitorManager?
    #endif
    
    @Published private(set) var isLoading = false
    @Published private(set) var notes: [FileNote] = []
    @Published var error: String?
    @Published var importProgress: ImportProgress?
    @Published private(set) var isDirectoryConfigured: Bool = false
    
    // Track if initial load is complete
    private var initialLoadComplete = false
    
    // Add a dictionary to track open note states
    private var openNoteStates: [String: NoteState] = [:]
    
    struct ImportProgress {
        let total: Int
        var completed: Int
        var successful: Int
        var failed: Int
    }
    
    // Add color cycling support
    private static var lastUsedColorIndex: Int = -1
    
    func getNextColor() -> NoteColor {
        let colors = NoteColor.defaultColors
        Self.lastUsedColorIndex = (Self.lastUsedColorIndex + 1) % colors.count
        return colors[Self.lastUsedColorIndex]
    }
    
    private init() {
        print("NotesManager: Initializing...")
        setupDefaultDirectory()
        
        #if os(iOS)
        // Setup background task handling for iOS
        setupBackgroundTaskHandling()
        #endif
    }
    
    private func setupDefaultDirectory() {
        print("NotesManager: Setting up default directory...")
        
        // First try to get security-scoped bookmark data
        if let bookmarkData = UserDefaults.standard.data(forKey: "notesDirectoryBookmark") {
            print("NotesManager: Found saved directory bookmark")
            var isStale = false
            do {
                #if os(macOS)
                let url = try URL(resolvingBookmarkData: bookmarkData,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)
                #else
                let url = try URL(resolvingBookmarkData: bookmarkData,
                                options: [],
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)
                #endif
                
                if url.startAccessingSecurityScopedResource() {
                    print("NotesManager: Successfully accessed bookmarked directory: \(url.path)")
                    try FileOperationManager.shared.verifyDirectoryAccess(at: url)
                    notesDirectory = url
                    createNotesDirectoryIfNeeded()
                    setupFileWatcher()
                    loadNotes()
                    isDirectoryConfigured = true
                    
                    // Update bookmark if it's stale
                    if isStale {
                        print("NotesManager: Updating stale bookmark")
                        saveSecurityScopedBookmark(for: url)
                    }
                    return
                }
            } catch {
                print("NotesManager: ERROR - Failed to resolve bookmark: \(error.localizedDescription)")
                UserDefaults.standard.removeObject(forKey: "notesDirectoryBookmark")
            }
        }
        
        setupDefaultQuickNotesDirectory()
    }
    
    private func setupDefaultQuickNotesDirectory() {
        print("NotesManager: No directory configured")
        isDirectoryConfigured = false
        error = "Please select a directory to store your notes"
        notesDirectory = nil
    }
    
    func resetDirectory() {
        print("NotesManager: Resetting directory configuration")
        #if os(macOS)
        fileCoordinator = nil
        #else
        directoryMonitor?.stopMonitoring()
        directoryMonitor = nil
        #endif
        
        notesDirectory = nil
        isDirectoryConfigured = false
        notes = []
        
        // Clear settings
        UserDefaults.standard.removeObject(forKey: "notesDirectoryBookmark")
        UserDefaults.standard.removeObject(forKey: "notesDirectory")
    }
    
    func setNotesDirectory(_ url: URL) {
        do {
            // Start accessing the security-scoped resource first
            if !url.startAccessingSecurityScopedResource() {
                throw FileError.noDirectoryAccess("Failed to access security-scoped resource")
            }
            
            // Verify directory access
            try FileOperationManager.shared.verifyDirectoryAccess(at: url)
            
            // If we get here, we have proper access
            notesDirectory = url
            
            // Save security-scoped bookmark first
            saveSecurityScopedBookmark(for: url)
            
            // Then save the path as fallback
            UserDefaults.standard.set(url.path, forKey: "notesDirectory")
            
            // Setup remaining components
            createNotesDirectoryIfNeeded()
            setupFileWatcher()
            loadNotes()
            isDirectoryConfigured = true
            print("NotesManager: Successfully configured directory")
        } catch {
            // Stop accessing if we started
            url.stopAccessingSecurityScopedResource()
            
            self.error = error.localizedDescription
            print("NotesManager: ERROR - \(error.localizedDescription)")
            isDirectoryConfigured = false
            
            // Clear invalid settings
            UserDefaults.standard.removeObject(forKey: "notesDirectoryBookmark")
            UserDefaults.standard.removeObject(forKey: "notesDirectory")
            notesDirectory = nil
        }
    }
    
    private func createNotesDirectoryIfNeeded() {
        guard let directory = notesDirectory else {
            print("NotesManager: ERROR - No directory set for creation")
            return
        }
        
        print("NotesManager: Checking if directory exists at: \(directory.path)")
        
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                print("NotesManager: Directory doesn't exist, creating...")
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                print("NotesManager: Successfully created directory at: \(directory.path)")
            } catch {
                print("NotesManager: ERROR creating directory: \(error.localizedDescription)")
                self.error = "Failed to create notes directory: \(error.localizedDescription)"
            }
        } else {
            print("NotesManager: Directory already exists")
        }
    }
    
    #if os(iOS)
    private func setupIOSDefaultDirectory() {
        // Use the app's Documents directory for iOS
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let notesDir = documentsDirectory.appendingPathComponent("Quick Sticky Notes")
            do {
                try FileOperationManager.shared.verifyDirectoryAccess(at: notesDir)
                notesDirectory = notesDir
                createNotesDirectoryIfNeeded()
                setupFileWatcher()
                loadNotes()
                isDirectoryConfigured = true
                
                // Save the directory for future use
                saveSecurityScopedBookmark(for: notesDir)
            } catch {
                print("NotesManager: ERROR - Failed to setup iOS default directory: \(error.localizedDescription)")
                setupDefaultQuickNotesDirectory()
            }
        }
    }
    
    private func setupBackgroundTaskHandling() {
        // Register for background task completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidEnterBackground() {
        // Save any pending changes when entering background
        Task {
            await saveAllPendingChanges()
        }
    }
    #else
    private func setupMacOSDefaultDirectory() {
        // Try the saved path as fallback
        if let savedPath = UserDefaults.standard.string(forKey: "notesDirectory") {
            let url = URL(fileURLWithPath: savedPath)
            do {
                try FileOperationManager.shared.verifyDirectoryAccess(at: url)
                notesDirectory = url
                createNotesDirectoryIfNeeded()
                setupFileWatcher()
                loadNotes()
                isDirectoryConfigured = true
                saveSecurityScopedBookmark(for: url)
            } catch {
                print("NotesManager: ERROR - Failed to access saved directory: \(error.localizedDescription)")
                setupDefaultQuickNotesDirectory()
            }
        } else {
            setupDefaultQuickNotesDirectory()
        }
    }
    #endif
    
    private func setupFileWatcher() {
        guard let directory = notesDirectory else {
            print("NotesManager: ERROR - No directory to watch")
            return
        }
        
        #if os(macOS)
        setupMacOSFileWatcher(for: directory)
        #else
        setupIOSFileWatcher(for: directory)
        #endif
    }
    
    #if os(macOS)
    private func setupMacOSFileWatcher(for directory: URL) {
        // Stop existing file watcher if any
        fileCoordinator?.stopMonitoring()
        
        // Create new file coordinator
        fileCoordinator = FileCoordinationManager(url: directory)
        fileCoordinator?.onDirectoryChange = { [weak self] in
            Task { @MainActor in
                await self?.reloadNotes()
            }
        }
        
        print("NotesManager: Started file coordination for directory: \(directory.path)")
    }
    #else
    private func setupIOSFileWatcher(for directory: URL) {
        directoryMonitor = DirectoryMonitorManager(url: directory)
        directoryMonitor?.onDirectoryChange = { [weak self] in
            Task { @MainActor in
                await self?.reloadNotes()
            }
        }
        directoryMonitor?.startMonitoring()
    }
    #endif
    
    @MainActor
    private func reloadNotes() async {
        guard !isLoading else { 
            print("NotesManager: Skipping reload - already loading")
            return 
        }
        
        guard let directory = notesDirectory else {
            print("NotesManager: ERROR - No directory set for reloading notes")
            return
        }
        
        #if os(iOS)
        // Ensure we have security-scoped access for iOS
        guard directory.startAccessingSecurityScopedResource() else {
            print("NotesManager: ERROR - Failed to access security-scoped resource")
            return
        }
        defer {
            directory.stopAccessingSecurityScopedResource()
        }
        #endif
        
        print("NotesManager: Starting notes reload")
        // Only show loading state if this is the initial load
        if !initialLoadComplete {
            isLoading = true
        }
        let oldNotes = notes
        
        do {
            let newNotes = try await loadNotesFromDisk()
            
            // Compare notes and update if there are changes
            let hasChanges = newNotes.count != oldNotes.count || 
                           zip(newNotes, oldNotes).contains { $0 != $1 }
            
            if hasChanges {
                print("NotesManager: Changes detected, updating notes list")
                notes = newNotes
            } else {
                print("NotesManager: No changes detected in notes")
            }
            
            // Mark initial load as complete
            initialLoadComplete = true
        } catch {
            print("NotesManager: ERROR reloading notes - \(error.localizedDescription)")
            self.error = "Failed to reload notes: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func loadNotesFromDisk() async throws -> [FileNote] {
        guard let directory = notesDirectory else {
            throw FileError.noDirectoryAccess("No directory set for loading notes")
        }
        
        #if os(iOS)
        // Ensure we have security-scoped access for iOS
        guard directory.startAccessingSecurityScopedResource() else {
            throw FileError.noDirectoryAccess("Failed to access security-scoped resource")
        }
        defer {
            directory.stopAccessingSecurityScopedResource()
        }
        #endif
        
        return try await Task.detached(priority: .userInitiated) { [directory, fileManager] in
            var notes: [FileNote] = []
            
            // Use FileManager's enumerator to recursively scan directories
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw FileError.noDirectoryAccess("Failed to create directory enumerator")
            }
            
            for case let fileURL as URL in enumerator {
                // Skip non-markdown files
                guard fileURL.pathExtension.lowercased() == "md" else { continue }
                
                do {
                    // Check if it's a regular file
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    guard resourceValues.isRegularFile == true else { continue }
                    
                    // Load the note
                    if let note = try? await FileNote.from(filePath: fileURL.path) {
                        notes.append(note)
                    }
                } catch {
                    print("NotesManager: Error processing file at \(fileURL.path): \(error.localizedDescription)")
                    continue
                }
            }
            
            // Sort by modification date
            return notes.sorted { $0.modifiedAt > $1.modifiedAt }
        }.value
    }
    
    private func loadNotes() {
        guard !isLoading else { return }
        guard let directory = notesDirectory else {
            print("NotesManager: ERROR - No directory set for loading notes")
            return
        }
        
        // Only show loading state if this is the initial load
        if !initialLoadComplete {
            isLoading = true
        }
        
        Task {
            do {
                let loadedNotes = try await loadNotesFromDisk()
                
                // Update published properties on main thread
                await MainActor.run {
                    self.notes = loadedNotes
                    self.isLoading = false
                    self.initialLoadComplete = true
                }
            } catch {
                await MainActor.run {
                    print("NotesManager: ERROR loading notes: \(error.localizedDescription)")
                    self.error = "Failed to load notes: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func createNote(title: String, content: String = "") async throws -> FileNote {
        guard let directory = notesDirectory else {
            throw FileError.noDirectoryAccess("No directory set")
        }
        
        let note = try await NoteSaveService.shared.createNote(title: title, content: content, in: directory)
        loadNotes()  // Reload to update the list
        return note
    }
    
    func deleteNote(_ note: FileNote) throws {
        try FileOperationManager.shared.deleteFile(at: note.filePath)
        loadNotes()  // Reload to update the list
    }
    
    // MARK: - Import Methods
    
    @MainActor
    func importFiles(from paths: [String]) async {
        guard let directory = notesDirectory else {
            error = ImportError.destinationDirectoryNotSet.description
            return
        }
        
        importProgress = ImportProgress(total: paths.count, completed: 0, successful: 0, failed: 0)
        
        let results = await importer.importFiles(at: paths, to: directory)
        
        // Update progress and stats
        var successful = 0
        var failed = 0
        
        for result in results {
            if result.success {
                successful += 1
            } else {
                failed += 1
            }
        }
        
        importProgress = ImportProgress(
            total: paths.count,
            completed: paths.count,
            successful: successful,
            failed: failed
        )
        
        // Reload notes to include newly imported ones
        loadNotes()
    }
    
    @MainActor
    func importFile(from path: String) async -> ImportResult {
        guard let directory = notesDirectory else {
            return ImportResult(
                success: false,
                note: nil,
                error: .destinationDirectoryNotSet
            )
        }
        
        let result = await importer.importFile(at: path, to: directory)
        
        if result.success {
            loadNotes()
        }
        
        return result
    }
    
    private func saveSecurityScopedBookmark(for url: URL) {
        do {
            #if os(macOS)
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #else
            let bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #endif
            UserDefaults.standard.set(bookmark, forKey: "notesDirectoryBookmark")
        } catch {
            print("NotesManager: ERROR - Failed to create security-scoped bookmark: \(error.localizedDescription)")
        }
    }
    
    #if os(iOS)
    private func saveAllPendingChanges() async {
        // Implement saving pending changes when app goes to background
        for state in openNoteStates.values {
            if state.hasUnsavedChanges {
                // Save the note
                if let note = state.currentNote {
                    try? await NoteSaveService.shared.saveNote(note, newContent: note.content)
                }
            }
        }
    }
    #endif
    
    deinit {
        // Stop accessing security-scoped resource
        Task { @MainActor in
            notesDirectory?.stopAccessingSecurityScopedResource()
        }
    }
    
    // Add a public method to force refresh
    @MainActor
    func forceRefresh() {
        Task {
            await reloadNotes()
        }
    }
    
    func registerOpenNote(state: NoteState) {
        guard let note = state.currentNote else { return }
        openNoteStates[note.filePath] = state
    }
    
    func unregisterOpenNote(state: NoteState) {
        guard let note = state.currentNote else { return }
        openNoteStates.removeValue(forKey: note.filePath)
    }
} 

