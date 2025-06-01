import SwiftUI
import KeyboardShortcuts

@main
struct QuickStickyNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var notesManager = NotesManager.shared
    
    var body: some Scene {
        Settings {
            PreferencesView()
                .frame(width: 600, height: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var notesListWindowController: NSWindowController?
    var quickNoteWindowController: NSWindowController?
    var onboardingWindowController: NSWindowController?
    var recentNotesWindowController: NSWindowController?
    var upgradePromptWindowController: NSWindowController?
    private let notesManager = NotesManager.shared
    private let recentNotesManager = RecentNotesManager.shared
    private let fileManager = FileManager.default
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Apply dock icon visibility preference
        if UserDefaults.standard.bool(forKey: "hideDockIcon") {
            NSApp.setActivationPolicy(.accessory)
        }
        
        setupMenuBar()
        setupKeyboardShortcuts()
        setupNotificationObservers()
        
        initialize()
    }
    
    private func initialize() {
        if !UserDefaults.standard.bool(forKey: "has_launched_before") {
            UserDefaults.standard.set(true, forKey: "has_launched_before")
        }
        
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        }
    }
    
    private func showOnboarding() {
        // Create frame positioned near cursor - but for onboarding, use full screen
        let window = NSWindow(
            contentRect: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Welcome to Quick Sticky Notes"
        window.center() // Keep center for onboarding as it's a special case
        window.setFrame(NSScreen.main?.visibleFrame ?? window.frame, display: true)
        window.isReleasedWhenClosed = false
        
        window.contentView = NSHostingView(
            rootView: OnboardingView()
                .environment(\.window, window)
                .environmentObject(notesManager)
        )
        
        onboardingWindowController = NSWindowController(window: window)
        onboardingWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // If no windows are visible, show the notes list
            Task { @MainActor in
                await showNotesList()
            }
        }
        return true
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Quick Sticky Notes")
            createMenu()
        }
    }
    
    private func showUpgradePrompt() {
        // If window already exists, bring it to front
        if let windowController = upgradePromptWindowController {
            windowController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false,
            positionNearCursor: true
        )
        window.title = "Upgrade to Pro"
        window.contentView = NSHostingView(rootView: UpgradePromptView())
        window.isReleasedWhenClosed = false
        upgradePromptWindowController = NSWindowController(window: window)
        upgradePromptWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Method to show upgrade prompt when keyboard shortcuts limit is reached
    private func showUpgradePromptForShortcuts() {
        // If window already exists, bring it to front
        if let windowController = upgradePromptWindowController {
            windowController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false,
            positionNearCursor: true
        )
        window.title = "Upgrade to Pro"
        window.contentView = NSHostingView(rootView: UpgradePromptView())
        window.isReleasedWhenClosed = false
        upgradePromptWindowController = NSWindowController(window: window)
        upgradePromptWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupKeyboardShortcuts() {
        // Set up keyboard shortcuts without defaults
        KeyboardShortcuts.onKeyDown(for: .newQuickNote) { [weak self] in
            // Check if we should show the upgrade prompt
            if ProManager.shared.trackShortcutUsage() {
                self?.showUpgradePromptForShortcuts()
            }
            
            // Always execute the action, even for non-pro users
            Task { @MainActor [weak self] in
                await self?.newNote()
            }
        }
        
        KeyboardShortcuts.onKeyDown(for: .openNotesList) { [weak self] in
            // Check if we should show the upgrade prompt
            if ProManager.shared.trackShortcutUsage() {
                self?.showUpgradePromptForShortcuts()
            }
            
            // Always execute the action, even for non-pro users
            Task { @MainActor [weak self] in
                await self?.showNotesList()
            }
        }
        
        KeyboardShortcuts.onKeyDown(for: .openRecentNotes) { [weak self] in
            // Check if we should show the upgrade prompt
            if ProManager.shared.trackShortcutUsage() {
                self?.showUpgradePromptForShortcuts()
            }
            
            // Always execute the action, even for non-pro users
            Task { @MainActor [weak self] in
                await self?.showRecentNotes()
            }
        }
        
        KeyboardShortcuts.onKeyDown(for: .openScratchpad) {
            Task {
                await ScratchpadService.shared.toggleScratchpad()
            }
        }
    }
    
    public func createMenu() {
        let menu = NSMenu()
        
        // Add menu items without default shortcuts
        let newNoteItem = NSMenuItem(title: "New Note", action: #selector(newNote), keyEquivalent: "")
        let recentNotesItem = NSMenuItem(title: "Recent Notes", action: #selector(showRecentNotes), keyEquivalent: "")
        let viewNotesItem = NSMenuItem(title: "View All Notes", action: #selector(showNotesList), keyEquivalent: "")
        let scratchpadItem = NSMenuItem(title: "Toggle Scratchpad", action: #selector(toggleScratchpad), keyEquivalent: "")
        
        menu.addItem(newNoteItem)
        menu.addItem(recentNotesItem)
        menu.addItem(viewNotesItem)
        menu.addItem(scratchpadItem)
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
    
    @objc private func newNote() {
        Task { @MainActor in
            // Activate app first
            NSApp.activate(ignoringOtherApps: true)
            
            // If directory is not configured, show the notes list instead
            if !notesManager.isDirectoryConfigured {
                await showNotesList()
                return
            }
            
            let window = EditNoteWindow()
            NSApp.setActivationPolicy(.regular)
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.accessory)
            quickNoteWindowController = NSWindowController(window: window)
        }
    }
    
    @objc private func showNotesList() {
        Task { @MainActor in
            // Activate app first
            NSApp.activate(ignoringOtherApps: true)
            
            if let windowController = notesListWindowController {
                NSApp.setActivationPolicy(.regular)
                windowController.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                NSApp.setActivationPolicy(.accessory)
                return
            }
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false,
                positionNearCursor: true
            )
            
            window.title = "All Notes"
            
            let notesListView = NotesListView()
                .environment(\.window, window)
            
            window.contentView = NSHostingView(rootView: notesListView)
            
            NSApp.setActivationPolicy(.regular)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.setActivationPolicy(.accessory)
            notesListWindowController = NSWindowController(window: window)
        }
    }
    
    @objc private func showPreferences() {
        let preferencesWindow = PreferencesWindowController()
        preferencesWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showAbout() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false,
            positionNearCursor: true
        )
        
        window.title = "About Quick Sticky Notes"
        window.isMovableByWindowBackground = true
        
        window.contentView = NSHostingView(
            rootView: AboutView()
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "mailto" {
                        NSWorkspace.shared.open(url)
                    }
                    return .handled
                })
        )
        
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showRecentNotes() {
        Task { @MainActor in
            // Activate app first
            NSApp.activate(ignoringOtherApps: true)
            
            // If directory is not configured, show the notes list instead
            if !notesManager.isDirectoryConfigured {
                await showNotesList()
                return
            }
            
            if let windowController = recentNotesWindowController {
                NSApp.setActivationPolicy(.regular)
                windowController.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                NSApp.setActivationPolicy(.accessory)
                return
            }
            
            let window = RecentNotesWindow()
            NSApp.setActivationPolicy(.regular)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.setActivationPolicy(.accessory)
            recentNotesWindowController = NSWindowController(window: window)
        }
    }
    
    @objc private func toggleScratchpad() {
        Task {
            await ScratchpadService.shared.toggleScratchpad()
        }
    }
    
    @objc private func toggleDockIcon() {
        let currentPolicy = NSApp.activationPolicy()
        let newPolicy: NSApplication.ActivationPolicy = (currentPolicy == .regular) ? .accessory : .regular
        
        NSApp.setActivationPolicy(newPolicy)
        
        // Recreate menu to update the menu item title
        createMenu()
        
        // Save the preference
        UserDefaults.standard.set(newPolicy == .accessory, forKey: "hideDockIcon")
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpgradePromptClose),
            name: NSNotification.Name("UpgradePromptDidClose"),
            object: nil
        )
    }
    
    @objc private func handleUpgradePromptClose() {
        upgradePromptWindowController = nil
    }
}
