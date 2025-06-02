import SwiftUI
import AppKit

class RecentNotesWindow: NSWindow {
    static let frameAutosaveName = "RecentNotesWindowFrame"
    static var lastWindowFrame: NSRect?
    
    init() {
        // First try to get the last used frame from memory
        var frame = RecentNotesWindow.lastWindowFrame
        
        // If no frame in memory, try to get from UserDefaults
        if frame == nil {
            if let savedFrame = UserDefaults.standard.windowFrame(forKey: RecentNotesWindow.frameAutosaveName) {
                frame = NSWindow.contentRect(
                    forFrameRect: savedFrame,
                    styleMask: [.titled, .closable]
                )
            }
        }
        
        // If still no frame, use default
        if frame == nil {
            frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        }
        
        // Initialize window with frame
        super.init(
            contentRect: frame!,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
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
        
        center()
        
        // Set up the content view
        contentView = NSHostingView(
            rootView: RecentNotesView()
                .environment(\.window, self)
        )
        
        // Set delegate to handle window state changes
        delegate = WindowStateDelegate.shared
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
} 