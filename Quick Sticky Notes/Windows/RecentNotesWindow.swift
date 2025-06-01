import SwiftUI
import AppKit

class RecentNotesWindow: NSWindow {
    
    init() {
        // Initialize window with cursor positioning
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false,
            positionNearCursor: true
        )
        
        // Configure window properties
        title = "Recent Notes"
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
        
        // Set up the content view
        contentView = NSHostingView(
            rootView: RecentNotesView()
                .environment(\.window, self)
        )
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
} 