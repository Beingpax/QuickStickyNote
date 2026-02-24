import Cocoa
import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin
import ApplicationServices

class PreferencesWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Preferences"
        window.center()
        
        // Set window level and behavior to ensure it appears above other apps
        window.level = .floating
        window.collectionBehavior = [.fullScreenAuxiliary]
        
        let preferencesView = PreferencesView()
        window.contentView = NSHostingView(rootView: preferencesView)
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        // Ensure window becomes key and front-most when shown
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct PreferencesView: View {
    @AppStorage("notesDirectory") private var notesDirectory: String = ""
    @StateObject private var notesManager = NotesManager.shared
    @StateObject private var proManager = ProManager.shared
    @State private var showingResetAlert = false
    @State private var showingUpgradePrompt = false
    @State private var hideDockIcon: Bool = true
    @State private var launchAtLogin: Bool = true
    @State private var showingScratchpadInfo = false
    @State private var hasAccessibilityPermission = AXIsProcessTrusted()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: proManager.isProUser ? "#4ECDC4" : "#9B9B9B").opacity(0.1))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: proManager.isProUser ? "checkmark.seal.fill" : "seal.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(hex: proManager.isProUser ? "#4ECDC4" : "#9B9B9B").gradient)
                    }
                    Text(proManager.isProUser ? "Pro Version" : "Free Version")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 20)
                
                // Settings Sections
                VStack(spacing: 20) {
                    // Pro Status
                    SettingSection(title: "Pro Status", icon: "star.fill", iconColor: Color(hex: "#4ECDC4")) {
                        VStack(alignment: .leading, spacing: 12) {
                            if proManager.isProUser {
                                Text("Pro License: Active")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Pro License: Not Active")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if !proManager.isProUser {
                                Button("Upgrade to Pro") {
                                    showingUpgradePrompt = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            
                            #if DEBUG
                            Button("Toggle Pro") {
                                proManager.toggleProStatus()
                            }
                            #endif
                        }
                    }
                    
                    // Directory Settings
                    SettingSection(title: "Notes Directory", icon: "folder.fill", iconColor: Color(hex: "#4ECDC4")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                TextField("Directory Path", text: .constant(notesDirectory))
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .disabled(true)
                                
                                Button("Choose...") {
                                    chooseDirectory()
                                }
                                .buttonStyle(ModernButtonStyle())
                            }
                            
                            HStack {
                                Button("Open in Finder") {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: notesDirectory))
                                }
                                .buttonStyle(ModernSecondaryButtonStyle())
                                .disabled(notesDirectory.isEmpty)
                                
                                Spacer()
                                
                                Button("Reset Directory", role: .destructive) {
                                    showingResetAlert = true
                                }
                                .buttonStyle(ModernDestructiveButtonStyle())
                                .disabled(notesDirectory.isEmpty)
                            }
                        }
                    }
                    
                    // Keyboard Shortcuts
                    SettingSection(title: "Keyboard Shortcuts", icon: "keyboard.fill", iconColor: Color(hex: "#FF6B6B")) {
                        VStack(alignment: .leading, spacing: 16) {
                            KeyboardShortcuts.Recorder("New Quick Note:", name: .newQuickNote)
                                .controlSize(.large)
                            KeyboardShortcuts.Recorder("Open Notes List:", name: .openNotesList)
                                .controlSize(.large)
                            KeyboardShortcuts.Recorder("Open Recent Notes:", name: .openRecentNotes)
                                .controlSize(.large)
                            KeyboardShortcuts.Recorder("Switch Editor Mode:", name: .switchEditorMode)
                                .controlSize(.large)
                            HStack {
                                KeyboardShortcuts.Recorder("Open Scratchpad:", name: .openScratchpad)
                                    .controlSize(.large)
                                
                                Button(action: {
                                    showingScratchpadInfo = true
                                }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(Color(hex: "#4ECDC4"))
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showingScratchpadInfo) {
                                    InfoPopover(text: "Scratchpad is a dedicated note that opens instantly for quick thoughts and temporary content. Perfect for jotting down quick ideas or temporary information.")
                                }
                            }
                        }
                    }
                    
                    // Dock Icon
                    SettingSection(title: "App Appearance", icon: "macwindow", iconColor: Color(hex: "#FF6B6B")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Hide Dock Icon", isOn: $hideDockIcon)
                                .onChange(of: hideDockIcon) { newValue in
                                    DockIconManager.shared.isDockIconHidden = newValue
                                }
                                .onAppear {
                                    hideDockIcon = DockIconManager.shared.isDockIconHidden
                                }
                                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DockIconChanged"))) { _ in
                                    hideDockIcon = DockIconManager.shared.isDockIconHidden
                                }
                            
                            Toggle("Launch at Login", isOn: $launchAtLogin)
                                .onChange(of: launchAtLogin) { newValue in
                                    LaunchAtLogin.isEnabled = newValue
                                }
                                .onAppear {
                                    launchAtLogin = LaunchAtLogin.isEnabled
                                }
                        }
                    }
                    
                    // Permissions
                    SettingSection(title: "Permissions", icon: "lock.shield.fill", iconColor: Color(hex: "#4ECDC4")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(hasAccessibilityPermission ? Color(hex: "#4ECDC4") : Color(hex: "#FF6B6B"))
                                    .frame(width: 8, height: 8)
                                Text(hasAccessibilityPermission ? "Accessibility: Granted" : "Accessibility: Not Granted")
                                    .foregroundStyle(hasAccessibilityPermission ? Color(hex: "#4ECDC4") : Color(hex: "#FF6B6B"))
                                    .font(.system(size: 14, weight: .medium))
                            }

                            Text("Allows dismissing the sidebar with Escape from any app, even when the sidebar is not focused.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if !hasAccessibilityPermission {
                                Button("Open Accessibility Settings") {
                                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                                }
                                .buttonStyle(ModernSecondaryButtonStyle())
                            }
                        }
                        .onAppear { hasAccessibilityPermission = AXIsProcessTrusted() }
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                            hasAccessibilityPermission = AXIsProcessTrusted()
                        }
                    }

                    #if DEBUG
                    // Advanced
                    SettingSection(title: "Advanced", icon: "gear", iconColor: Color(hex: "#9B9B9B")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: {
                                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                                NSApp.sendAction(#selector(NSWindow.close), to: nil, from: nil)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    NotificationCenter.default.post(name: NSNotification.Name("ShowOnboarding"), object: nil)
                                }
                            }) {
                                Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(ModernSecondaryButtonStyle())
                            
                            Text("Development Testing")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                            
                            Button(action: {
                                proManager.toggleProStatus()
                            }) {
                                Label(proManager.isProUser ? "Deactivate Pro" : "Activate Pro", 
                                      systemImage: proManager.isProUser ? "xmark.circle" : "checkmark.circle")
                            }
                            .buttonStyle(ModernSecondaryButtonStyle())
                            
                            Button(action: {
                                proManager.resetAllPurchases()
                            }) {
                                Label("Reset All Purchases", systemImage: "trash")
                            }
                            .buttonStyle(ModernDestructiveButtonStyle())
                        }
                    }
                    #endif
                }
                
                Text("Note: Changes are saved automatically")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#9B9B9B"))
                    .padding(.top, 8)
            }
            .padding(32)
        }
        .frame(width: 600, height: 500)
        .background(Color(hex: "#1E1E1E"))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView()
        }
        .alert("Reset Notes Directory?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetDirectory()
            }
        } message: {
            Text("This will clear the current directory setting. You'll need to choose a new directory before creating or viewing notes. Existing notes will not be deleted.")
        }
    }
    
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                // First try to set the directory in NotesManager
                notesManager.setNotesDirectory(url)
                
                // Only update UserDefaults if the directory was successfully set
                if notesManager.isDirectoryConfigured {
                    notesDirectory = url.path
                }
            }
        }
    }
    
    private func resetDirectory() {
        notesDirectory = ""
        UserDefaults.standard.removeObject(forKey: "notesDirectory")
        notesManager.resetDirectory()
    }
}

// MARK: - Supporting Views
struct SettingSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Content
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#2D2D2D"))
        .cornerRadius(16)
    }
}

// MARK: - Custom Styles
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(8)
            .background(Color(hex: "#1E1E1E"))
            .cornerRadius(8)
            .foregroundColor(.white)
    }
}


struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "#2D2D2D").opacity(configuration.isPressed ? 0.8 : 1))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

struct ModernDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "#FF6B6B").opacity(0.2))
            .foregroundColor(Color(hex: "#FF6B6B"))
            .cornerRadius(8)
    }
}

// MARK: - Supporting Views
struct InfoPopover: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .padding(12)
            .frame(width: 280)
    }
}

// MARK: - Supporting Styles
struct ModernGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.content
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#222222"))
        .cornerRadius(8)
    }
}
