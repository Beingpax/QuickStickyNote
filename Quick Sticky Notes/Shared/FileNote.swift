import Foundation

struct FileNote: Identifiable, Hashable {
    let id = UUID()
    var filePath: String
    var title: String
    var content: String
    var colorName: String
    var createdAt: Date
    var modifiedAt: Date
    var additionalMetadata: [String: String]
    private var contentHash: Int // Add content hash for change detection
    
    static func parseTitle(from filename: String) -> String {
        return URL(fileURLWithPath: filename)
            .deletingPathExtension()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    init(filePath: String, title: String, content: String, colorName: String, createdAt: Date, modifiedAt: Date, additionalMetadata: [String: String] = [:]) {
        self.filePath = filePath
        self.title = title
        self.content = content
        self.colorName = colorName
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.additionalMetadata = additionalMetadata
        self.contentHash = content.hashValue
    }
    
    init(url: URL, content: String? = nil) throws {
        let fileManager = FileOperationManager.shared
        let noteContent = try content ?? fileManager.readFile(at: url.path)
        
        // Get file system dates
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileCreationDate = attributes[.creationDate] as? Date
        let fileModificationDate = attributes[.modificationDate] as? Date
        
        // Parse the content and metadata
        let (parsedContent, metadata) = YAMLParser.parseNote(content: noteContent)
        
        // Use file system dates as primary source, fall back to metadata dates, then current date
        let now = Date()
        let createdDate = fileCreationDate ?? metadata.created ?? now
        let modifiedDate = fileModificationDate ?? metadata.modified ?? now
        
        self.init(
            filePath: url.path,
            title: FileNote.parseTitle(from: url.lastPathComponent),
            content: parsedContent,
            colorName: metadata.color,
            createdAt: createdDate,
            modifiedAt: modifiedDate,
            additionalMetadata: metadata.additionalMetadata
        )
    }
    
    static func from(filePath: String) throws -> FileNote? {
        let url = URL(fileURLWithPath: filePath)
        return try FileNote(url: url)
    }
    
    mutating func updateTitle(_ newTitle: String) async throws {
        let fileManager = FileOperationManager.shared
        let currentURL = URL(fileURLWithPath: filePath)
        let sanitizedTitle = FileNote.sanitizeFileName(newTitle.trimmingCharacters(in: .whitespacesAndNewlines))
        let newFileName = sanitizedTitle.isEmpty ? "Untitled.md" : "\(sanitizedTitle).md"
        let newURL = currentURL.deletingLastPathComponent().appendingPathComponent(newFileName)
        
        // Check if we're actually changing the file
        guard currentURL != newURL else { return }
        
        // Get original file dates
        let attributes = try FileManager.default.attributesOfItem(atPath: currentURL.path)
        let originalCreationDate = attributes[.creationDate] as? Date
        
        // If target file exists, create a unique name
        let uniqueTitle = try fileManager.createUniqueFilename(baseName: sanitizedTitle, in: currentURL.deletingLastPathComponent())
        let finalURL = currentURL.deletingLastPathComponent().appendingPathComponent("\(uniqueTitle).md")
        
        // Move the file
        try fileManager.moveFile(from: currentURL.path, to: finalURL.path)
        
        // Preserve creation date after move
        if let creationDate = originalCreationDate {
            try FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: finalURL.path)
        }
        
        // Update properties
        self.title = sanitizedTitle
        self.filePath = finalURL.path
        self.modifiedAt = Date()
    }
    
    mutating func save() async throws {
        try await NoteSaveService.shared.saveNote(self, newTitle: title, newContent: content)
    }
    
    // For Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(filePath)
        hasher.combine(contentHash)
        hasher.combine(modifiedAt)
    }
    
    static func == (lhs: FileNote, rhs: FileNote) -> Bool {
        return lhs.filePath == rhs.filePath &&
               lhs.contentHash == rhs.contentHash &&
               lhs.modifiedAt == rhs.modifiedAt
    }
    
    static func sanitizeFileName(_ filename: String) -> String {
        let illegalCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return filename
            .components(separatedBy: illegalCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 

