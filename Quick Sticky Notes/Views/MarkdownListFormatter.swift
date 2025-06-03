import SwiftUI
import AppKit

// MARK: - Custom Attribute Keys
extension NSAttributedString.Key {
    static let checkboxState = NSAttributedString.Key("checkboxState")
    static let bulletState = NSAttributedString.Key("bulletState")
}

// MARK: - Checkbox State
struct CheckboxState {
    let isChecked: Bool
    let indentLevel: Int
    let range: NSRange
    
    init(isChecked: Bool, indentLevel: Int, range: NSRange) {
        self.isChecked = isChecked
        self.indentLevel = indentLevel
        self.range = range
    }
}

// MARK: - Bullet State
struct BulletState {
    let indentLevel: Int
    let range: NSRange
    
    init(indentLevel: Int, range: NSRange) {
        self.indentLevel = indentLevel
        self.range = range
    }
}

class MarkdownListFormatter {
    
    // MARK: - List Detection and Formatting
    
    static func applyListFormatting(to textStorage: NSTextStorage) {
        let string = textStorage.string
        
        // Process each line for list formatting
        string.enumerateSubstrings(in: string.startIndex..<string.endIndex,
                                 options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            
            let nsRange = NSRange(lineRange, in: string)
            guard nsRange.location != NSNotFound,
                  nsRange.location + nsRange.length <= textStorage.length else { return }
            
            let lineString = String(string[lineRange])
            
            if let listItem = detectListItem(from: lineString) {
                formatListLine(textStorage: textStorage,
                             range: nsRange,
                             listItem: listItem,
                             lineText: lineString)
            }
        }
    }
    
    // MARK: - List Item Detection
    
    enum ListItemType {
        case unorderedBullet(indentLevel: Int)
        case orderedNumber(number: Int, indentLevel: Int)
        case checklistUnchecked(indentLevel: Int)
        case checklistChecked(indentLevel: Int)
    }
    
    static func detectListItem(from line: String) -> ListItemType? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let indentLevel = leadingSpaces / 2 // Every 2 spaces = 1 indent level
        
        // Check for checklist items first (most specific)
        if let checklistType = detectChecklistItem(trimmed, indentLevel: indentLevel) {
            return checklistType
        }
        
        // Check for ordered list items
        if let orderedType = detectOrderedListItem(trimmed, indentLevel: indentLevel) {
            return orderedType
        }
        
        // Check for unordered list items
        if let unorderedType = detectUnorderedListItem(trimmed, indentLevel: indentLevel) {
            return unorderedType
        }
        
        return nil
    }
    
    private static func detectOrderedListItem(_ line: String, indentLevel: Int) -> ListItemType? {
        // Pattern: "1. ", "2. ", etc.
        let pattern = #"^(\d+)\.\s"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: line.count)
        
        if let match = regex.firstMatch(in: line, range: range) {
            let numberRange = Range(match.range(at: 1), in: line)!
            if let number = Int(String(line[numberRange])) {
                return .orderedNumber(number: number, indentLevel: indentLevel)
            }
        }
        return nil
    }
    
    private static func detectUnorderedListItem(_ line: String, indentLevel: Int) -> ListItemType? {
        // Pattern: "- ", "* ", "+ "
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return .unorderedBullet(indentLevel: indentLevel)
        }
        return nil
    }
    
    private static func detectChecklistItem(_ line: String, indentLevel: Int) -> ListItemType? {
        // Pattern: "- [ ] " or "- [x] " or "- [X] "
        if line.hasPrefix("- [") && line.count >= 4 {
            let checkboxContent = line.dropFirst(3).prefix(1)
            if line.dropFirst(4).hasPrefix("] ") || (line.count == 4 && line.hasSuffix("]")) {
                switch checkboxContent {
                case " ":
                    return .checklistUnchecked(indentLevel: indentLevel)
                case "x", "X":
                    return .checklistChecked(indentLevel: indentLevel)
                default:
                    return nil
                }
            }
        }
        return nil
    }
    
    // MARK: - Visual Formatting
    
    private static func formatListLine(textStorage: NSTextStorage, 
                                     range: NSRange, 
                                     listItem: ListItemType, 
                                     lineText: String) {
        
        // Apply indentation and styling WITHOUT replacing the original text
        let indentLevel = getIndentLevel(from: listItem)
        let leftMargin: CGFloat = CGFloat(indentLevel) * 16 // Reduced from 20pt to 16pt per indent level
        
        // Create paragraph style with adjusted indentation and line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = leftMargin
        paragraphStyle.headIndent = leftMargin
        // Add line spacing to match the preview mode and other editors (0.25em)
        paragraphStyle.lineSpacing = 16.8 * 0.25  // Using base font size for consistency
        
        // Apply paragraph style to entire line
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        
        // Handle checkbox vs regular list styling
        switch listItem {
        case .checklistUnchecked, .checklistChecked:
            // Style checkbox items specially
            styleCheckboxLine(textStorage: textStorage, range: range, listItem: listItem, lineText: lineText)
            
        case .unorderedBullet:
            // Style bullet items with custom visual bullets
            styleBulletLine(textStorage: textStorage, range: range, listItem: listItem, lineText: lineText)
            
        default:
            // Style regular list items (ordered lists)
            let syntaxLength = getSyntaxLength(for: listItem, in: lineText)
            if syntaxLength > 0 && range.length >= syntaxLength {
                let syntaxRange = NSRange(location: range.location, length: syntaxLength)
                applyListMarkerStyling(textStorage: textStorage, range: syntaxRange, listItem: listItem)
            }
            
            // Style the content part with normal color
            if range.length > syntaxLength {
                let contentRange = NSRange(
                    location: range.location + syntaxLength,
                    length: range.length - syntaxLength
                )
                textStorage.addAttribute(.foregroundColor, 
                                       value: NSColor.black.withAlphaComponent(0.8), 
                                       range: contentRange)
            }
        }
    }
    
    private static func styleCheckboxLine(textStorage: NSTextStorage, range: NSRange, listItem: ListItemType, lineText: String) {
        // Find the checkbox pattern in the line: "- [ ] " or "- [x] "
        let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("- [") && trimmed.count >= 6 {
            let leadingSpaces = lineText.prefix(while: { $0 == " " }).count
            let indentLevel = leadingSpaces / 2
            
            // Calculate ranges for different parts
            let dashRange = NSRange(location: range.location + leadingSpaces, length: 2) // "- "
            let checkboxRange = NSRange(location: range.location + leadingSpaces + 2, length: 3) // "[ ]" or "[x]"
            let spaceAfterCheckboxRange = NSRange(location: range.location + leadingSpaces + 5, length: 1) // " "
            
            // Determine if checkbox is checked
            let isChecked: Bool
            switch listItem {
            case .checklistChecked:
                isChecked = true
            default:
                isChecked = false
            }
            
            // Hide the markdown syntax by making it transparent
            if dashRange.location + dashRange.length <= textStorage.length {
                textStorage.addAttribute(.foregroundColor, 
                                       value: NSColor.clear, 
                                       range: dashRange)
            }
            
            if checkboxRange.location + checkboxRange.length <= textStorage.length {
                textStorage.addAttribute(.foregroundColor, 
                                       value: NSColor.clear, 
                                       range: checkboxRange)
                
                // Add our custom checkbox attribute for drawing
                let checkboxState = CheckboxState(isChecked: isChecked, indentLevel: indentLevel, range: checkboxRange)
                textStorage.addAttribute(.checkboxState, 
                                       value: checkboxState, 
                                       range: checkboxRange)
            }
            
            if spaceAfterCheckboxRange.location + spaceAfterCheckboxRange.length <= textStorage.length {
                textStorage.addAttribute(.foregroundColor, 
                                       value: NSColor.clear, 
                                       range: spaceAfterCheckboxRange)
            }
            
            // Style the content part
            if range.length > leadingSpaces + 6 {
                let contentRange = NSRange(
                    location: range.location + leadingSpaces + 6,
                    length: range.length - leadingSpaces - 6
                )
                
                let contentColor = isChecked ? NSColor.black.withAlphaComponent(0.5) : NSColor.black.withAlphaComponent(0.8)
                
                textStorage.addAttribute(.foregroundColor, value: contentColor, range: contentRange)
                
                // Add strikethrough for checked items
                if isChecked {
                    textStorage.addAttribute(.strikethroughStyle, 
                                           value: NSUnderlineStyle.single.rawValue, 
                                           range: contentRange)
                }
            }
        }
    }
    
    private static func styleBulletLine(textStorage: NSTextStorage, range: NSRange, listItem: ListItemType, lineText: String) {
        let leadingSpaces = lineText.prefix(while: { $0 == " " }).count
        let indentLevel = leadingSpaces / 2
        
        // Calculate ranges for different parts
        let bulletRange = NSRange(location: range.location + leadingSpaces, length: 2) // "- " or "* " or "+ "
        
        // Hide the markdown bullet syntax by making it transparent
        if bulletRange.location + bulletRange.length <= textStorage.length {
            textStorage.addAttribute(.foregroundColor, 
                                   value: NSColor.clear, 
                                   range: bulletRange)
            
            // Add our custom bullet attribute for drawing
            let bulletState = BulletState(indentLevel: indentLevel, range: bulletRange)
            textStorage.addAttribute(.bulletState, 
                                   value: bulletState, 
                                   range: bulletRange)
        }
        
        // Style the content part with normal color
        if range.length > leadingSpaces + 2 {
            let contentRange = NSRange(
                location: range.location + leadingSpaces + 2,
                length: range.length - leadingSpaces - 2
            )
            textStorage.addAttribute(.foregroundColor, 
                                   value: NSColor.black.withAlphaComponent(0.8), 
                                   range: contentRange)
        }
    }
    
    private static func applyListMarkerStyling(textStorage: NSTextStorage, range: NSRange, listItem: ListItemType) {
        switch listItem {
        case .unorderedBullet:
            // Simple styling for bullet points (dashes)
            textStorage.addAttribute(.font, 
                                   value: NSFont.systemFont(ofSize: 14, weight: .medium), 
                                   range: range)
            textStorage.addAttribute(.foregroundColor, 
                                   value: NSColor.black.withAlphaComponent(0.6), 
                                   range: range)
            
        case .orderedNumber:
            // Simple styling for numbered lists
            textStorage.addAttribute(.font, 
                                   value: NSFont.systemFont(ofSize: 14, weight: .medium), 
                                   range: range)
            textStorage.addAttribute(.foregroundColor, 
                                   value: NSColor.black.withAlphaComponent(0.6), 
                                   range: range)
            
        case .checklistUnchecked:
            // Replace checkbox syntax with visual checkbox character
            applyCheckboxStyling(textStorage: textStorage, range: range, checked: false)
            
        case .checklistChecked:
            // Replace checkbox syntax with visual checkbox character
            applyCheckboxStyling(textStorage: textStorage, range: range, checked: true)
        }
    }
    
    private static func applyCheckboxStyling(textStorage: NSTextStorage, range: NSRange, checked: Bool) {
        // This method is no longer used - keeping for compatibility
    }
    
    private static func getSyntaxLength(for listItem: ListItemType, in lineText: String) -> Int {
        let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch listItem {
        case .unorderedBullet:
            // "- " = 2 characters
            return 2
            
        case .orderedNumber(let number, _):
            // "1. " = 3 characters, "10. " = 4 characters, etc.
            let numberText = "\(number). "
            return numberText.count
            
        case .checklistUnchecked, .checklistChecked:
            // "- [ ] " or "- [x] " = 6 characters
            return 6
        }
    }
    
    private static func getIndentLevel(from listItem: ListItemType) -> Int {
        switch listItem {
        case .unorderedBullet(let indentLevel),
             .orderedNumber(_, let indentLevel),
             .checklistUnchecked(let indentLevel),
             .checklistChecked(let indentLevel):
            return indentLevel
        }
    }
    
    // MARK: - Checkbox Utilities
    
    /// Find all checkbox states in the given text storage
    static func findCheckboxStates(in textStorage: NSTextStorage) -> [CheckboxState] {
        var checkboxStates: [CheckboxState] = []
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        textStorage.enumerateAttribute(.checkboxState, in: fullRange, options: []) { value, range, _ in
            if let checkboxState = value as? CheckboxState {
                checkboxStates.append(checkboxState)
            }
        }
        
        return checkboxStates
    }
    
    /// Find all bullet states in the given text storage
    static func findBulletStates(in textStorage: NSTextStorage) -> [BulletState] {
        var bulletStates: [BulletState] = []
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        textStorage.enumerateAttribute(.bulletState, in: fullRange, options: []) { value, range, _ in
            if let bulletState = value as? BulletState {
                bulletStates.append(bulletState)
            }
        }
        
        return bulletStates
    }
    
    /// Find checkbox state at a specific character index
    static func findCheckboxState(at index: Int, in textStorage: NSTextStorage) -> CheckboxState? {
        guard index < textStorage.length else { return nil }
        
        // Check if there's a checkbox attribute at this location
        if let checkboxState = textStorage.attribute(.checkboxState, at: index, effectiveRange: nil) as? CheckboxState {
            return checkboxState
        }
        
        // If not directly on checkbox, check if we're on the same line as a checkbox
        let string = textStorage.string
        let lineRange = (string as NSString).lineRange(for: NSRange(location: index, length: 0))
        
        // Search within the line for checkbox attributes
        var foundCheckboxState: CheckboxState?
        textStorage.enumerateAttribute(.checkboxState, in: lineRange, options: []) { value, range, stop in
            if let checkboxState = value as? CheckboxState {
                foundCheckboxState = checkboxState
                stop.pointee = true
            }
        }
        
        return foundCheckboxState
    }
} 