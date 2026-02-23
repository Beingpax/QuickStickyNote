import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin

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
    private var menuBarManager: MenuBarManager?
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

        // Setup dock icon state
        DockIconManager.shared.setupInitialState()

        // Initialize menu bar manager
        menuBarManager = MenuBarManager(appDelegate: self)
        menuBarManager?.setupMenuBar()

        setupKeyboardShortcuts()
        setupNotificationObservers()

        // Start the right-edge sidebar panel
        SidebarManager.shared.start()

        initialize()
    }
    
    private func initialize() {
        if !UserDefaults.standard.bool(forKey: "has_launched_before") {
            UserDefaults.standard.set(true, forKey: "has_launched_before")
            
            // Set default values for first launch
            DockIconManager.shared.setDefaultIfFirstLaunch()
        }
        
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        }
    }
    
    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Welcome to Quick Sticky Notes"
        window.center()
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
            defer: false
        )
        window.title = "Upgrade to Pro"
        window.center()
        window.contentView = NSHostingView(rootView: UpgradePromptView())
        window.isReleasedWhenClosed = false
        window.level = .floating
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
            defer: false
        )
        window.title = "Upgrade to Pro"
        window.center()
        window.contentView = NSHostingView(rootView: UpgradePromptView())
        window.isReleasedWhenClosed = false
        window.level = .floating
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
    
    @objc func newNote() {
        Task { @MainActor in
            // Activate app first
            NSApp.activate(ignoringOtherApps: true)
            
            // If directory is not configured, show the notes list instead
            if !notesManager.isDirectoryConfigured {
                await showNotesList()
                return
            }
            
            let window = EditNoteWindow()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            quickNoteWindowController = NSWindowController(window: window)
        }
    }
    
    @objc func showNotesList() {
        Task { @MainActor in
            // Activate app first
            NSApp.activate(ignoringOtherApps: true)
            
            if let windowController = notesListWindowController {
                windowController.window?.orderFrontRegardless()
                windowController.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "All Notes"
            window.center()
            
            let notesListView = NotesListView()
                .environment(\.window, window)
            
            window.contentView = NSHostingView(rootView: notesListView)
            
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            notesListWindowController = NSWindowController(window: window)
        }
    }
    
    @objc func showPreferences() {
        let preferencesWindow = PreferencesWindowController()
        preferencesWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showAbout() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "About Quick Sticky Notes"
        window.center()
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
    
    @objc func showRecentNotes() {
        Task { @MainActor in
            // Activate app first
            NSApp.activate(ignoringOtherApps: true)
            
            // If directory is not configured, show the notes list instead
            if !notesManager.isDirectoryConfigured {
                await showNotesList()
                return
            }
            
            if let windowController = recentNotesWindowController {
                windowController.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            let window = RecentNotesWindow()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            recentNotesWindowController = NSWindowController(window: window)
        }
    }
    
    @objc func toggleScratchpad() {
        Task {
            await ScratchpadService.shared.toggleScratchpad()
        }
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
