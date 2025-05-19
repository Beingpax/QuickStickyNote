import Foundation

struct YAMLParser {
    struct NoteMetadata {
        var color: String
        var created: Date
        var modified: Date
        var additionalMetadata: [String: String]
        
        static func defaultMetadata() -> NoteMetadata {
            return NoteMetadata(
                color: "yellow",
                created: Date(),
                modified: Date(),
                additionalMetadata: [:]
            )
        }
    }
    
    static func parseNote(content: String) -> (content: String, metadata: NoteMetadata) {
        let parts = content.components(separatedBy: "---\n")
        guard parts.count >= 3 else {
            return (content, .defaultMetadata())
        }
        
        let frontMatter = parts[1]
        let noteContent = parts[2...].joined(separator: "---\n")
        
        var metadata = [String: String]()
        let metadataLines = frontMatter.components(separatedBy: .newlines)
        
        for line in metadataLines {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            metadata[key] = value
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let defaultDate = Date()
        
        let color = metadata["color"] ?? "yellow"
        let created = metadata["created"].flatMap(dateFormatter.date(from:)) ?? defaultDate
        let modified = metadata["modified"].flatMap(dateFormatter.date(from:)) ?? defaultDate
        
        // Remove standard fields from additional metadata
        var additionalMetadata = metadata
        ["color", "created", "modified"].forEach { additionalMetadata.removeValue(forKey: $0) }
        
        return (
            noteContent,
            NoteMetadata(
                color: color,
                created: created,
                modified: modified,
                additionalMetadata: additionalMetadata
            )
        )
    }
    
    static func generateYAML(metadata: NoteMetadata) -> String {
        var yaml = "---\n"
        
        // Add standard fields
        yaml += "color: \(metadata.color)\n"
        
        let dateFormatter = ISO8601DateFormatter()
        yaml += "created: \(dateFormatter.string(from: metadata.created))\n"
        yaml += "modified: \(dateFormatter.string(from: metadata.modified))\n"
        
        // Add additional metadata
        for (key, value) in metadata.additionalMetadata.sorted(by: { $0.key < $1.key }) {
            yaml += "\(key): \(value)\n"
        }
        
        yaml += "---\n"
        return yaml
    }
} 