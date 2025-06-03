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
                    styleMask: [.borderless, .resizable]
                )
            }
        }
        
        // If still no frame, use default
        if frame == nil {
            frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        }
        
        // Initialize window with borderless style for cleaner look
        super.init(
            contentRect: frame!,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties for always on top behavior
        isReleasedWhenClosed = false
        level = .popUpMenu  // Higher than .statusBar used by EditNoteWindow
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        
        // Modern translucent appearance
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        
        // Enable vibrancy and transparency
        titlebarAppearsTransparent = true
        
        // Make it movable by background since there's no titlebar
        isMovableByWindowBackground = true
        
        center()
        
        // Set up the content view with vibrancy effect
        contentView = NSHostingView(
            rootView: RecentNotesView()
                .environment(\.window, self)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        
        // Set delegate to handle window state changes
        delegate = WindowStateDelegate.shared
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
} 