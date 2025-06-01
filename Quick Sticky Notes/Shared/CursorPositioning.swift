import Foundation
import AppKit

extension NSWindow {
    /// Positions the window near the cursor with smart screen boundary detection
    func positionNearCursor(offset: CGPoint = CGPoint(x: 20, y: -20)) {
        let cursorPosition = NSEvent.mouseLocation
        let targetPosition = CGPoint(
            x: cursorPosition.x + offset.x,
            y: cursorPosition.y + offset.y
        )
        
        // Find the screen containing the cursor
        let screen = NSScreen.screens.first { $0.frame.contains(cursorPosition) } ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        
        // Ensure window stays on screen
        let finalPosition = CGPoint(
            x: max(screenFrame.minX, min(targetPosition.x, screenFrame.maxX - frame.width)),
            y: max(screenFrame.minY, min(targetPosition.y, screenFrame.maxY - frame.height))
        )
        
        setFrameOrigin(finalPosition)
    }
    
    /// Creates and positions a window near the cursor in one step
    convenience init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool,
        positionNearCursor: Bool = true
    ) {
        // Use a temporary rect for initialization
        self.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        
        if positionNearCursor {
            self.positionNearCursor()
        }
    }
} 