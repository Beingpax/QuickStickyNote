import Cocoa
import SwiftUI

@MainActor
class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private weak var appDelegate: AppDelegate?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenu),
            name: NSNotification.Name("DockIconChanged"),
            object: nil
        )
    }
    
    @objc private func updateMenu() {
        createMenu()
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Quick Sticky Notes")
            createMenu()
        }
    }
    
    func createMenu() {
        let menu = NSMenu()
        
        // Add main functionality menu items
        let newNoteItem = NSMenuItem(title: "New Note", action: #selector(newNote), keyEquivalent: "")
        let recentNotesItem = NSMenuItem(title: "Recent Notes", action: #selector(showRecentNotes), keyEquivalent: "")
        let viewNotesItem = NSMenuItem(title: "View All Notes", action: #selector(showNotesList), keyEquivalent: "")
        let scratchpadItem = NSMenuItem(title: "Toggle Scratchpad", action: #selector(toggleScratchpad), keyEquivalent: "")
        
        menu.addItem(newNoteItem)
        menu.addItem(recentNotesItem)
        menu.addItem(viewNotesItem)
        menu.addItem(scratchpadItem)
        menu.addItem(NSMenuItem.separator())
        
        // Add dock icon toggle
        let isDockHidden = DockIconManager.shared.isDockIconHidden
        let dockToggleTitle = isDockHidden ? "Show Dock Icon" : "Hide Dock Icon"
        let dockToggleItem = NSMenuItem(title: dockToggleTitle, action: #selector(toggleDockIcon), keyEquivalent: "")
        dockToggleItem.target = self
        menu.addItem(dockToggleItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(showPreferences), keyEquivalent: ""))
        
        // Add Support submenu
        let supportMenu = NSMenu()
        supportMenu.addItem(NSMenuItem(title: "About Quick Sticky Notes", action: #selector(showAbout), keyEquivalent: ""))
        let supportMenuItem = NSMenuItem(title: "Support", action: nil, keyEquivalent: "")
        supportMenuItem.submenu = supportMenu
        menu.addItem(supportMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // MARK: - Menu Actions
    
    @objc private func newNote() {
        appDelegate?.newNote()
    }
    
    @objc private func showRecentNotes() {
        appDelegate?.showRecentNotes()
    }
    
    @objc private func showNotesList() {
        appDelegate?.showNotesList()
    }
    
    @objc private func toggleScratchpad() {
        appDelegate?.toggleScratchpad()
    }
    
    @objc private func showPreferences() {
        appDelegate?.showPreferences()
    }
    
    @objc private func showAbout() {
        appDelegate?.showAbout()
    }
    
    @objc private func toggleDockIcon() {
        DockIconManager.shared.isDockIconHidden.toggle()
    }
}
