import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 14)
    var backgroundColor: NSColor
    
    init(text: Binding<String>, font: NSFont = .systemFont(ofSize: 14), backgroundColor: Color) {
        self._text = text
        self.font = font
        self.backgroundColor = NSColor(backgroundColor)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        // Create scroll view container
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = backgroundColor
        scrollView.drawsBackground = true
        
        // Create text view
        let textView = NSTextView()
        textView.delegate = context.coordinator
        
        // Basic setup
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.smartInsertDeleteEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        
        // Set default font and appearance
        textView.font = font
        textView.textColor = .black
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        
        // Add line spacing to match preview mode (0.25em relative line spacing)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = font.pointSize * 0.25  // 0.25em in points
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        
        // Configure text view for scroll view
        textView.autoresizingMask = [.width]
        textView.translatesAutoresizingMaskIntoConstraints = true
        
        // Add text view to scroll view
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Only update if the text has changed externally
        if textView.string != text {
            // Save the current selection range and scroll position
            let selectedRanges = textView.selectedRanges
            let visibleRect = scrollView.contentView.bounds
            
            // Update the text
            textView.string = text
            
            // Restore selection if possible
            if let primaryRange = selectedRanges.first?.rangeValue,
               primaryRange.location + primaryRange.length <= text.count {
                textView.selectedRanges = selectedRanges
                
                // Restore scroll position
                scrollView.contentView.scrollToVisible(visibleRect)
            }
        }
        
        // Update background color
        scrollView.backgroundColor = backgroundColor
        scrollView.drawsBackground = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        
        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

extension String {
    var length: Int {
        return self.utf16.count
    }
} 
