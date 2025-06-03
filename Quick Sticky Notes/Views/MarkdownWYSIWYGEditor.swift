import SwiftUI
import AppKit

struct MarkdownWYSIWYGEditor: NSViewRepresentable {
    @Binding var text: String
    var backgroundColor: NSColor
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = backgroundColor
        scrollView.drawsBackground = true
        
        let textView = ClickableTextView() // Use our custom text view
        textView.delegate = context.coordinator
        
        // Set up checkbox click handling
        textView.onCheckboxClick = { range in
            context.coordinator.handleCheckboxToggle(textView: textView, checkboxRange: range)
        }
        
        // Configure text view
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.smartInsertDeleteEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        // Set appearance
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        
        // Set default paragraph style with line spacing
        let defaultParagraphStyle = NSMutableParagraphStyle()
        defaultParagraphStyle.lineSpacing = 16.8 * 0.25  // 0.25em for base font size
        textView.defaultParagraphStyle = defaultParagraphStyle
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 16.8),
            .foregroundColor: NSColor.black.withAlphaComponent(0.8),
            .paragraphStyle: defaultParagraphStyle
        ]
        
        // Configure layout
        textView.autoresizingMask = [.width]
        textView.translatesAutoresizingMaskIntoConstraints = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.frame.width, height: .greatestFiniteMagnitude)
        
        scrollView.documentView = textView
        
        // Set initial text and formatting
        context.coordinator.setupInitialText(textView, text: text)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Update background color
        scrollView.backgroundColor = backgroundColor
        
        // Only update text if it's different from what we have
        if textView.string != text {
            context.coordinator.updateText(textView, newText: text)
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownWYSIWYGEditor
        private var isUpdating = false
        private var formatTimer: Timer?
        
        // Default styling constants
        private let baseFont = NSFont.systemFont(ofSize: 16.8) // 14pt * 1.2 to match markdown theme
        private let defaultTextColor = NSColor.black.withAlphaComponent(0.8)
        private let syntaxColor = NSColor.black.withAlphaComponent(0.3)
        private let headingColor = NSColor.black.withAlphaComponent(0.9)
        
        init(_ parent: MarkdownWYSIWYGEditor) {
            self.parent = parent
        }
        
        deinit {
            formatTimer?.invalidate()
        }
        
        func setupInitialText(_ textView: NSTextView, text: String) {
            isUpdating = true
            textView.string = text
            applyAllFormatting(to: textView)
            isUpdating = false
        }
        
        func updateText(_ textView: NSTextView, newText: String) {
            isUpdating = true
            
            // Save current selection
            let selectedRange = textView.selectedRange()
            
            // Update text
            textView.string = newText
            
            // Apply formatting
            applyAllFormatting(to: textView)
            
            // Restore selection if valid
            let maxLocation = textView.string.count
            if selectedRange.location <= maxLocation {
                let safeLength = min(selectedRange.length, maxLocation - selectedRange.location)
                let safeRange = NSRange(location: selectedRange.location, length: safeLength)
                textView.setSelectedRange(safeRange)
            }
            
            isUpdating = false
        }
        
        // MARK: - NSTextViewDelegate
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !isUpdating else { return }
            
            // Update parent binding
            parent.text = textView.string
            
            // Check if we should apply immediate formatting
            let shouldFormatImmediately = checkForImmediateFormatting(textView)
            
            if shouldFormatImmediately {
                // Apply formatting immediately for completed patterns
                applyAllFormatting(to: textView)
            } else {
                // Debounce formatting for other changes to avoid performance issues while typing
                formatTimer?.invalidate()
                formatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.applyAllFormatting(to: textView)
                    }
                }
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Enter key for list continuation
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return handleListContinuation(in: textView)
            }
            
            // Handle Tab key for list indentation
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                return handleListIndentation(in: textView, indent: true)
            }
            
            // Handle Shift-Tab key for list outdentation
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                return handleListIndentation(in: textView, indent: false)
            }
            
            return false
        }
        
        // MARK: - Immediate Formatting Detection
        
        private func checkForImmediateFormatting(_ textView: NSTextView) -> Bool {
            let selectedRange = textView.selectedRange()
            let string = textView.string
            
            // Check if cursor is at end of text
            guard selectedRange.location == string.count else { return false }
            
            // Find the current line
            let lineRange = (string as NSString).lineRange(for: NSRange(location: selectedRange.location - 1, length: 0))
            let line = (string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)
            
            // Check if we just completed a heading pattern or are typing in a heading
            return checkForCompletedHeadingPattern(line) || isTypingInHeading(line) || checkForCompletedListPattern(line) || isTypingInList(line)
        }
        
        private func checkForCompletedHeadingPattern(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for patterns like "# ", "## ", "### ", etc.
            if trimmed.hasPrefix("#") {
                let hashSequence = trimmed.prefix(while: { $0 == "#" })
                let hashCount = hashSequence.count
                
                // Valid heading levels are 1-6
                guard hashCount >= 1 && hashCount <= 6 else { return false }
                
                let afterHashes = trimmed.dropFirst(hashCount)
                
                // Format immediately if:
                // 1. Just typed space after hashes: "## "
                // 2. Have content after space: "## some text"
                return afterHashes.hasPrefix(" ")
            }
            
            return false
        }
        
        private func checkForCompletedListPattern(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for completed list patterns
            // Unordered: "- ", "* ", "+ " 
            if (trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ")) {
                return true
            }
            
            // Checkbox patterns: "- [ ] ", "- [x] "
            if trimmed.hasPrefix("- [") && (trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")) {
                return true
            }
            
            // Ordered: "1. ", "2. ", etc.
            let orderPattern = #"^\d+\.\s"#
            if trimmed.range(of: orderPattern, options: .regularExpression) != nil {
                return true
            }
            
            return false
        }
        
        private func isTypingInHeading(_ line: String) -> Bool {
            // If we're already in a heading line with content, format immediately
            // This makes typing feel more responsive
            return getHeadingLevel(from: line) != nil
        }
        
        private func isTypingInList(_ line: String) -> Bool {
            // If we're typing in a list item, format immediately for responsiveness
            return MarkdownListFormatter.detectListItem(from: line) != nil
        }
        
        // MARK: - Formatting Logic
        
        private func applyAllFormatting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            
            let fullRange = NSRange(location: 0, length: textStorage.length)
            
            // Start batch editing
            textStorage.beginEditing()
            
            // Create default paragraph style with line spacing to match preview mode
            let defaultParagraphStyle = NSMutableParagraphStyle()
            defaultParagraphStyle.lineSpacing = baseFont.pointSize * 0.25  // 0.25em in points
            
            // Reset all attributes to default with line spacing
            textStorage.setAttributes([
                .font: baseFont,
                .foregroundColor: defaultTextColor,
                .paragraphStyle: defaultParagraphStyle
            ], range: fullRange)
            
            // Apply heading formatting line by line
            applyHeadingFormatting(to: textStorage)
            
            // Apply list formatting (bullets, numbers, checkboxes)
            MarkdownListFormatter.applyListFormatting(to: textStorage)

            // Apply inline formatting (bold, italic)
            MarkdownInlineStyleFormatter.applyInlineFormatting(
                to: textStorage, 
                baseFont: baseFont, 
                syntaxColor: syntaxColor, 
                defaultTextColor: defaultTextColor
            )
            
            // End batch editing
            textStorage.endEditing()
        }
        
        private func applyHeadingFormatting(to textStorage: NSTextStorage) {
            let string = textStorage.string
            let fullRange = NSRange(location: 0, length: string.count)
            
            // Process each line for heading formatting
            string.enumerateSubstrings(in: string.startIndex..<string.endIndex,
                                     options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
                
                let nsRange = NSRange(lineRange, in: string)
                guard nsRange.location != NSNotFound,
                      nsRange.location + nsRange.length <= textStorage.length else { return }
                
                let lineString = String(string[lineRange])
                
                if let headingLevel = self.getHeadingLevel(from: lineString) {
                    self.formatHeadingLine(textStorage: textStorage,
                                    range: nsRange,
                                    level: headingLevel,
                                    lineText: lineString)
                }
            }
        }
        
        private func getHeadingLevel(from line: String) -> Int? {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Must start with # and have 1-6 consecutive #'s
            guard trimmed.hasPrefix("#") else { return nil }
            
            let hashSequence = trimmed.prefix(while: { $0 == "#" })
            let hashCount = hashSequence.count
            
            // Valid heading levels are 1-6
            guard hashCount >= 1 && hashCount <= 6 else { return nil }
            
            // Check if there's a space after hashes (or end of line for empty headings)
            let afterHashes = trimmed.dropFirst(hashCount)
            if afterHashes.isEmpty || afterHashes.hasPrefix(" ") {
                return hashCount
            }
            
            return nil
        }
        
        private func formatHeadingLine(textStorage: NSTextStorage, range: NSRange, level: Int, lineText: String) {
            // Calculate font size based on heading level
            let fontSize = calculateHeadingFontSize(for: level)
            let headingFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)
            
            // Create paragraph style with line spacing for headings
            let headingParagraphStyle = NSMutableParagraphStyle()
            headingParagraphStyle.lineSpacing = headingFont.pointSize * 0.25  // 0.25em in points
            
            // Find where the actual content starts
            let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
            let hashCount = level
            
            // Calculate syntax range (the # symbols + space if present)
            var syntaxLength = hashCount
            if trimmed.count > hashCount && trimmed.dropFirst(hashCount).hasPrefix(" ") {
                syntaxLength += 1 // Include the space
            }
            
            // Apply heading font and paragraph style to entire line first
            textStorage.addAttribute(.font, value: headingFont, range: range)
            textStorage.addAttribute(.paragraphStyle, value: headingParagraphStyle, range: range)
            
            // Style the syntax part (# symbols + space) with dimmed color
            if syntaxLength > 0 && range.length >= syntaxLength {
                let syntaxRange = NSRange(location: range.location, length: syntaxLength)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: syntaxRange)
            }
            
            // Style the content part with prominent color
            if range.length > syntaxLength {
                let contentRange = NSRange(
                    location: range.location + syntaxLength,
                    length: range.length - syntaxLength
                )
                textStorage.addAttribute(.foregroundColor, value: headingColor, range: contentRange)
            }
        }
        
        private func calculateHeadingFontSize(for level: Int) -> CGFloat {
            let baseFontSize = baseFont.pointSize
            
            switch level {
            case 1: return baseFontSize * 1.8  // H1: ~34pt
            case 2: return baseFontSize * 1.5// H2: ~25pt
            case 3: return baseFontSize * 1.3  // H3: ~21pt
            case 4: return baseFontSize * 1.2 // H4: ~18pt
            case 5: return baseFontSize * 1.1  // H5: ~17pt
            case 6: return baseFontSize * 1.0  // H6: ~15pt
            default: return baseFontSize
            }
        }
        
        // MARK: - List Continuation
        
        private func handleListContinuation(in textView: NSTextView) -> Bool {
            let selectedRange = textView.selectedRange()
            let string = textView.string
            
            // Find the current line
            let lineRange = (string as NSString).lineRange(for: selectedRange)
            let currentLine = (string as NSString).substring(with: lineRange)
            
            // Check if we're in a list
            guard let listContinuation = getListContinuation(from: currentLine) else {
                return false // Let default newline behavior happen
            }
            
            // Check if current line is empty list item (just the marker)
            let trimmedLine = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let isEmptyListItem = isEmptyListMarker(trimmedLine)
            
            if isEmptyListItem {
                // Remove the empty list marker and stop the list
                let lineContentRange = NSRange(
                    location: lineRange.location,
                    length: lineRange.length - 1 // Exclude the newline
                )
                
                isUpdating = true
                textView.replaceCharacters(in: lineContentRange, with: "")
                isUpdating = false
                
                // Update parent binding
                parent.text = textView.string
                
                return true // We handled the newline
            } else {
                // Continue the list with next item
                let insertText = "\n" + listContinuation
                
                isUpdating = true
                textView.insertText(insertText, replacementRange: selectedRange)
                isUpdating = false
                
                // Update parent binding
                parent.text = textView.string
                
                // Apply formatting immediately for the new list item
                applyAllFormatting(to: textView)
                
                return true // We handled the newline
            }
        }
        
        private func getListContinuation(from line: String) -> String? {
            // Detect what kind of list this is and return the next item marker
            if let listItem = MarkdownListFormatter.detectListItem(from: line) {
                let leadingSpaces = line.prefix(while: { $0 == " " })
                let indent = String(leadingSpaces)
                
                switch listItem {
                case .unorderedBullet:
                    return indent + "- "
                    
                case .orderedNumber(let currentNumber, _):
                    let nextNumber = currentNumber + 1
                    return indent + "\(nextNumber). "
                    
                case .checklistUnchecked, .checklistChecked:
                    return indent + "- [ ] "
                }
            }
            
            return nil
        }
        
        private func isEmptyListMarker(_ line: String) -> Bool {
            // Check if line contains only list marker without content
            let patterns = [
                "^\\s*-\\s*$",           // Just "- " with optional spaces
                "^\\s*\\*\\s*$",         // Just "* " with optional spaces  
                "^\\s*\\+\\s*$",         // Just "+ " with optional spaces
                "^\\s*\\d+\\.\\s*$"      // Just "1. " with optional spaces
            ]
            
            for pattern in patterns {
                if line.range(of: pattern, options: .regularExpression) != nil {
                    return true
                }
            }
            
            return false
        }
        
        // MARK: - List Indentation
        
        private func handleListIndentation(in textView: NSTextView, indent: Bool) -> Bool {
            let selectedRange = textView.selectedRange()
            let string = textView.string
            
            // Find the current line
            let lineRange = (string as NSString).lineRange(for: selectedRange)
            let currentLine = (string as NSString).substring(with: lineRange)
            
            // Check if we're in a list
            guard MarkdownListFormatter.detectListItem(from: currentLine) != nil else {
                return false // Not in a list, let default tab behavior happen
            }
            
            // Calculate new indentation
            let newLine = updateLineIndentation(currentLine, indent: indent)
            
            // If no change needed, don't handle the command
            guard newLine != currentLine else {
                return false
            }
            
            // Apply the indentation change
            isUpdating = true
            
            // Calculate cursor position adjustment
            let originalCursorOffset = selectedRange.location - lineRange.location
            let indentChange = newLine.count - currentLine.count
            let newCursorPosition = selectedRange.location + indentChange
            
            // Replace the line
            textView.replaceCharacters(in: lineRange, with: newLine)
            
            // Restore cursor position
            let safeCursorPosition = min(newCursorPosition, textView.string.count)
            textView.setSelectedRange(NSRange(location: safeCursorPosition, length: 0))
            
            isUpdating = false
            
            // Update parent binding
            parent.text = textView.string
            
            // Apply formatting immediately
            applyAllFormatting(to: textView)
            
            return true // We handled the tab command
        }
        
        private func updateLineIndentation(_ line: String, indent: Bool) -> String {
            let leadingSpaces = line.prefix(while: { $0 == " " })
            let content = line.dropFirst(leadingSpaces.count)
            
            let currentIndentLevel = leadingSpaces.count
            let indentSize = 2 // 2 spaces per indent level
            
            let newIndentLevel: Int
            if indent {
                newIndentLevel = currentIndentLevel + indentSize
            } else {
                newIndentLevel = max(0, currentIndentLevel - indentSize)
            }
            
            let newIndent = String(repeating: " ", count: newIndentLevel)
            return newIndent + content
        }
        
        func handleCheckboxToggle(textView: NSTextView, checkboxRange: NSRange) {
            let string = textView.string
            let checkboxText = (string as NSString).substring(with: checkboxRange)
            
            // Determine new state
            let newCheckboxText: String
            if checkboxText == "[ ]" {
                newCheckboxText = "[x]"
            } else if checkboxText == "[x]" || checkboxText == "[X]" {
                newCheckboxText = "[ ]"
            } else {
                return // Not a valid checkbox
            }
            
            // Toggle the checkbox state
            isUpdating = true
            
            // Save cursor position
            let selectedRange = textView.selectedRange()
            
            // Replace the checkbox text
            textView.replaceCharacters(in: checkboxRange, with: newCheckboxText)
            
            // Restore cursor position (it shouldn't change for checkbox toggles)
            textView.setSelectedRange(selectedRange)
            
            isUpdating = false
            
            // Update parent binding
            parent.text = textView.string
            
            // Apply formatting immediately to show the visual change
            applyAllFormatting(to: textView)
            
            // Force a redraw to update the custom checkboxes
            textView.needsDisplay = true
        }
    }
}

// Custom NSTextView that handles checkbox clicks and drawing
class ClickableTextView: NSTextView {
    var onCheckboxClick: ((NSRange) -> Void)?
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw the text first
        super.draw(dirtyRect)
        
        // Then draw custom checkboxes and bullets
        drawCustomListElements(in: dirtyRect)
    }
    
    private func drawCustomListElements(in dirtyRect: NSRect) {
        guard let textStorage = textStorage,
              let layoutManager = layoutManager,
              let textContainer = textContainer else { return }
        
        // Draw checkboxes
        let checkboxStates = MarkdownListFormatter.findCheckboxStates(in: textStorage)
        
        for checkboxState in checkboxStates {
            // Get the bounding rectangle for the checkbox range
            let glyphRange = layoutManager.glyphRange(forCharacterRange: checkboxState.range, actualCharacterRange: nil)
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            // Adjust for text container inset
            let adjustedRect = NSRect(
                x: boundingRect.origin.x + textContainerInset.width,
                y: boundingRect.origin.y + textContainerInset.height,
                width: max(boundingRect.width, 16), // Minimum checkbox width
                height: max(boundingRect.height, 16) // Minimum checkbox height
            )
            
            // Only draw if the checkbox is visible in the dirty rect
            if adjustedRect.intersects(dirtyRect) {
                drawNativeCheckbox(in: adjustedRect, isChecked: checkboxState.isChecked)
            }
        }
        
        // Draw bullets
        let bulletStates = MarkdownListFormatter.findBulletStates(in: textStorage)
        
        for bulletState in bulletStates {
            // Get the bounding rectangle for the bullet range
            let glyphRange = layoutManager.glyphRange(forCharacterRange: bulletState.range, actualCharacterRange: nil)
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            // Adjust for text container inset
            let adjustedRect = NSRect(
                x: boundingRect.origin.x + textContainerInset.width,
                y: boundingRect.origin.y + textContainerInset.height,
                width: max(boundingRect.width, 16), // Minimum bullet width
                height: max(boundingRect.height, 16) // Minimum bullet height
            )
            
            // Only draw if the bullet is visible in the dirty rect
            if adjustedRect.intersects(dirtyRect) {
                drawNativeBullet(in: adjustedRect)
            }
        }
    }
    
    private func drawNativeCheckbox(in rect: NSRect, isChecked: Bool) {
        // Create a properly sized checkbox rectangle
        let checkboxSize: CGFloat = 15
        let checkboxRect = NSRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.height - checkboxSize) / 2,
            width: checkboxSize,
            height: checkboxSize
        )

        if isChecked {
            // Checked state: Solid contrasting color with a white checkmark
            NSColor.black.withAlphaComponent(0.85).setFill()
            let fillPath = NSBezierPath(roundedRect: checkboxRect, xRadius: 4, yRadius: 4)
            fillPath.fill()

            // Draw white checkmark
            NSColor.white.setStroke()
            let checkmarkPath = NSBezierPath()
            checkmarkPath.lineWidth = 2.5 // Made slightly thicker
            checkmarkPath.lineCapStyle = .round
            checkmarkPath.lineJoinStyle = .round

            // Create checkmark shape (points adjusted for better visibility)
            let centerX = checkboxRect.midX
            let centerY = checkboxRect.midY
            let checkMarkSize: CGFloat = 8.0 // Adjusted size for clarity

            checkmarkPath.move(to: NSPoint(x: centerX - checkMarkSize * 0.45, y: centerY + checkMarkSize * 0.0))
            checkmarkPath.line(to: NSPoint(x: centerX - checkMarkSize * 0.05, y: centerY + checkMarkSize * 0.4))
            checkmarkPath.line(to: NSPoint(x: centerX + checkMarkSize * 0.5, y: centerY - checkMarkSize * 0.35))
            checkmarkPath.stroke()

        } else {
            // Unchecked state: Subtle fill with a clear border
            NSColor.black.withAlphaComponent(0.08).setFill()
            let backgroundPath = NSBezierPath(roundedRect: checkboxRect, xRadius: 4, yRadius: 4)
            backgroundPath.fill()

            // Border
            NSColor.black.withAlphaComponent(0.4).setStroke() // Slightly more visible border
            let borderPath = NSBezierPath(roundedRect: checkboxRect, xRadius: 4, yRadius: 4)
            borderPath.lineWidth = 2.5
            borderPath.stroke()
        }
    }
    
    private func drawNativeBullet(in rect: NSRect) {
        // Create a bullet point that matches the dark checkbox style
        let bulletSize: CGFloat = 4
        let bulletRect = NSRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.height - bulletSize) / 2,
            width: bulletSize,
            height: bulletSize
        )
        
        // Draw a dark circular bullet
        NSColor.black.withAlphaComponent(0.8).setFill()
        let bulletPath = NSBezierPath(ovalIn: bulletRect)
        bulletPath.fill()
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        // Check if click is specifically on a visual checkbox area
        if let checkboxRange = findVisualCheckboxAt(point: point) {
            onCheckboxClick?(checkboxRange)
            return // Don't call super to prevent text selection
        }
        
        super.mouseDown(with: event)
    }
    
    private func findVisualCheckboxAt(point: NSPoint) -> NSRange? {
        guard let textStorage = textStorage,
              let layoutManager = layoutManager,
              let textContainer = textContainer else { return nil }
        
        let checkboxStates = MarkdownListFormatter.findCheckboxStates(in: textStorage)
        
        for checkboxState in checkboxStates {
            // Get the bounding rectangle for the checkbox range
            let glyphRange = layoutManager.glyphRange(forCharacterRange: checkboxState.range, actualCharacterRange: nil)
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            // Adjust for text container inset
            let adjustedRect = NSRect(
                x: boundingRect.origin.x + textContainerInset.width,
                y: boundingRect.origin.y + textContainerInset.height,
                width: max(boundingRect.width, 16), // Minimum checkbox width
                height: max(boundingRect.height, 16) // Minimum checkbox height
            )
            
            // Calculate the actual visual checkbox rectangle (same as in drawNativeCheckbox)
            let checkboxSize: CGFloat = 14
            let checkboxRect = NSRect(
                x: adjustedRect.origin.x,
                y: adjustedRect.origin.y + (adjustedRect.height - checkboxSize) / 2,
                width: checkboxSize,
                height: checkboxSize
            )
            
            // Add a small padding for easier clicking
            let clickableRect = checkboxRect.insetBy(dx: -2, dy: -2)
            
            // Check if the click point is within this specific checkbox area
            if clickableRect.contains(point) {
                return checkboxState.range
            }
        }
        
        return nil
    }
} 
