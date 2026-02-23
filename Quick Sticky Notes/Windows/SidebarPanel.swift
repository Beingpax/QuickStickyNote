import AppKit
import SwiftUI

// MARK: - Mouse Tracking View

/// NSView subclass that fires callbacks when the mouse enters or exits its bounds.
private class TrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { onMouseEntered?() }
    override func mouseExited(with event: NSEvent)  { onMouseExited?()  }
}

// MARK: - Pill Indicator Window

/// Small permanent handle at the right edge of a screen.
/// One is created per monitor. Sits behind the sidebar panel —
/// hidden when the panel is open, revealed when it slides away.
class PillIndicatorWindow: NSPanel {

    static let pillWindowWidth:  CGFloat = 16
    static let pillWindowHeight: CGFloat = 56

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        isReleasedWhenClosed = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        hasShadow = false
        isOpaque = false
        isMovable = false
        acceptsMouseMovedEvents = true

        let trackingView = TrackingView()
        // Hovering any pill triggers the panel on the screen the cursor is on.
        trackingView.onMouseEntered = { SidebarManager.shared.showPanel() }

        let hostingView = NSHostingView(rootView: PillView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor),
        ])

        contentView = trackingView
    }

    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Sidebar Panel Window

class SidebarPanelWindow: NSPanel {

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        isReleasedWhenClosed = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        isMovable = false
        acceptsMouseMovedEvents = true

        let trackingView = TrackingView()
        trackingView.onMouseEntered = { SidebarManager.shared.showPanel() }
        trackingView.onMouseExited  = { SidebarManager.shared.scheduleHide() }

        let hostingView = NSHostingView(rootView: SidebarPanelView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor),
        ])

        contentView = trackingView
    }

    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }
}

// MARK: - Sidebar Manager

@MainActor
class SidebarManager {
    static let shared = SidebarManager()

    private var pillWindows: [PillIndicatorWindow] = []
    private(set) var panelWindow: SidebarPanelWindow?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var hideWorkItem: DispatchWorkItem?
    private var screenChangeObserver: Any?

    private(set) var isVisible = false
    /// The screen the panel is currently shown on (or last shown on).
    private var activeScreen: NSScreen?

    static let panelWidth: CGFloat = 300

    private let triggerZone: CGFloat = 3
    private let hideDelay:   TimeInterval = 0.4

    private init() {}

    // MARK: Lifecycle

    func start() {
        let panel = SidebarPanelWindow()
        panelWindow = panel

        // Place panel off-screen initially (use first available screen as placeholder).
        if let screen = NSScreen.screens.first {
            movePanelOffScreen(screen)
        }
        panel.orderFront(nil)

        setupPills()
        startMonitoring()
        observeScreenChanges()
    }

    func stop() {
        globalMouseMonitor.map { NSEvent.removeMonitor($0) }
        localMouseMonitor.map  { NSEvent.removeMonitor($0) }
        globalMouseMonitor = nil
        localMouseMonitor  = nil

        screenChangeObserver.map { NotificationCenter.default.removeObserver($0) }
        screenChangeObserver = nil

        panelWindow?.close()
        panelWindow = nil
        closePills()
    }

    // MARK: Pills (one per screen)

    private func setupPills() {
        closePills()
        for screen in NSScreen.screens {
            let pill = PillIndicatorWindow()
            positionPill(pill, on: screen)
            pill.orderFrontRegardless()
            pillWindows.append(pill)
        }
    }

    private func closePills() {
        pillWindows.forEach { $0.close() }
        pillWindows = []
    }

    private func positionPill(_ pill: PillIndicatorWindow, on screen: NSScreen) {
        let w = PillIndicatorWindow.pillWindowWidth
        let h = PillIndicatorWindow.pillWindowHeight
        pill.setFrame(NSRect(
            x: screen.frame.maxX - w,
            y: screen.visibleFrame.midY - h / 2,
            width: w,
            height: h
        ), display: false)
    }

    // MARK: Screen Change Handling

    private func observeScreenChanges() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenConfigChange()
        }
    }

    private func handleScreenConfigChange() {
        // Rebuild pills for the new screen layout.
        setupPills()

        // If the active screen was removed, hide the panel cleanly.
        if let active = activeScreen, !NSScreen.screens.contains(active) {
            isVisible = false
            activeScreen = nil
            if let fallback = NSScreen.screens.first {
                movePanelOffScreen(fallback)
            }
            return
        }

        // If panel is currently visible, keep it positioned correctly.
        if isVisible, let active = activeScreen {
            updatePanelFrame(visible: true, animated: false, on: active)
        }
    }

    // MARK: Mouse Monitoring

    private func startMonitoring() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            DispatchQueue.main.async { self?.checkMousePosition() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.checkMousePosition()
            return event
        }
    }

    private func checkMousePosition() {
        guard let screen = screenUnderCursor() else { return }
        if NSEvent.mouseLocation.x >= screen.frame.maxX - triggerZone {
            showPanel(on: screen)
        }
    }

    /// Returns the screen whose frame contains the current mouse cursor.
    private func screenUnderCursor() -> NSScreen? {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(loc) }
    }

    // MARK: Show / Hide

    func showPanel() {
        // Called from pill hover — resolve the screen from cursor position.
        let screen = screenUnderCursor()
        showPanel(on: screen)
    }

    func showPanel(on screen: NSScreen?) {
        hideWorkItem?.cancel()
        hideWorkItem = nil

        guard let screen = screen ?? screenUnderCursor() ?? NSScreen.screens.first else { return }

        // Already visible on the same screen — nothing to do.
        if isVisible && activeScreen == screen { return }

        // Switching screens: snap panel off the old screen instantly, then animate in on the new one.
        if isVisible, let previous = activeScreen, previous != screen {
            movePanelOffScreen(previous)
        }

        activeScreen = screen
        isVisible = true
        panelWindow?.orderFrontRegardless()
        updatePanelFrame(visible: true, animated: true, on: screen)
    }

    func scheduleHide() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.hidePanel() }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: item)
    }

    func cancelHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    func hidePanel() {
        guard isVisible, let screen = activeScreen else { return }
        isVisible = false
        updatePanelFrame(visible: false, animated: true, on: screen)
    }

    // MARK: Frame Helpers

    private func updatePanelFrame(visible: Bool, animated: Bool, on screen: NSScreen) {
        guard let window = panelWindow else { return }

        let visibleFrame = screen.visibleFrame
        let x: CGFloat = visible
            ? screen.frame.maxX - Self.panelWidth
            : screen.frame.maxX   // Off-screen to the right of this monitor

        let targetFrame = NSRect(
            x: x,
            y: visibleFrame.minY,
            width: Self.panelWidth,
            height: visibleFrame.height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = visible ? 0.25 : 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: visible ? .easeOut : .easeIn)
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: false)
        }
    }

    private func movePanelOffScreen(_ screen: NSScreen) {
        guard let window = panelWindow else { return }
        let visibleFrame = screen.visibleFrame
        window.setFrame(NSRect(
            x: screen.frame.maxX,
            y: visibleFrame.minY,
            width: Self.panelWidth,
            height: visibleFrame.height
        ), display: false)
    }
}
