import Cocoa

class DockIconManager {
    static let shared = DockIconManager()
    
    private init() {}
    
    var isDockIconHidden: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "hideDockIcon")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hideDockIcon")
            updateDockIconVisibility()
        }
    }
    
    func updateDockIconVisibility() {
        let policy: NSApplication.ActivationPolicy = isDockIconHidden ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
        
        // Notify that dock icon state changed
        NotificationCenter.default.post(name: NSNotification.Name("DockIconChanged"), object: nil)
    }
    
    func setupInitialState() {
        // Set default to hidden on first launch
        if !UserDefaults.standard.bool(forKey: "has_launched_before") {
            UserDefaults.standard.set(true, forKey: "hideDockIcon")
        }
        updateDockIconVisibility()
    }
    
    func setDefaultIfFirstLaunch() {
        // This method can be called from AppDelegate to ensure defaults are set
        if !UserDefaults.standard.bool(forKey: "has_launched_before") {
            UserDefaults.standard.set(true, forKey: "hideDockIcon")
        }
    }
}
