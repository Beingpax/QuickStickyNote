import Foundation

enum FileError: LocalizedError {
    case invalidFile(String)
    case accessDenied(String)
    case fileReadError
    case diskFull(String)
    case readOnly(String)
    case noDirectoryAccess(String)
    case writePermissionDenied(String)
    case backupFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied(let details):
            return "Unable to access the note: \(details)"
        case .diskFull(let details):
            return "Not enough space to save the note: \(details)"
        case .readOnly(let details):
            return "This note is read-only: \(details)"
        case .noDirectoryAccess(_):
            return "Unable to access the notes folder. Please check your settings and ensure a valid notes directory is selected."
        case .writePermissionDenied(_):
            return "Unable to save the note. Please check if you have write permissions for the notes folder."
        case .backupFailed(let details):
            return "Failed to backup the note: \(details)"
        case .invalidFile(let details):
            return "The note file appears to be invalid: \(details)"
        case .fileReadError:
            return "Unable to read the note. The file might be corrupted or inaccessible."
        }
    }
    
    // Add a title for the alert
    var alertTitle: String {
        switch self {
        case .noDirectoryAccess:
            return "Notes Folder Not Set"
        case .writePermissionDenied:
            return "Permission Error"
        case .diskFull:
            return "Storage Full"
        case .accessDenied:
            return "Access Error"
        case .readOnly:
            return "Read-Only Note"
        case .invalidFile:
            return "Invalid Note"
        case .fileReadError:
            return "Read Error"
        case .backupFailed:
            return "Backup Failed"
        }
    }
} 