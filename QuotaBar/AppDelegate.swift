import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var quotaMonitor: QuotaMonitor!
    var settingsWindow: NSWindow?
    var popoverMouseExitTimer: Timer?
    var cancellables = Set<AnyCancellable>()
    private var autoRefreshCancellable: AnyCancellable?
    private var quotaConsumingAutoRefreshCancellable: AnyCancellable?
    private let preferredSettingsContentSize = NSSize(width: 1040, height: 640)
    private let minimumSettingsWindowSize = NSSize(width: 1040, height: 640)
    private let statusPopoverAnchorHeight: CGFloat = 6
    private let statusPopoverTopClearance: CGFloat = 12

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        clearSwiftUISettingsWindowAutosaveFrame()
        quotaMonitor = QuotaMonitor.shared
        setupStatusBar()
        setupPopover()
        startMonitoring()
        showManagedSettingsWindowOnLaunch()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }

        let icon = makeStatusBarIcon()
        icon.isTemplate = true
        button.image = icon
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .labelColor
        button.toolTip = "API Quota"

        // 监听点击
        button.target = self
        button.action = #selector(togglePopover)
    }

    private func makeStatusBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        drawQuotaCellStatusGlyph(in: NSRect(x: 1.0, y: 4.6, width: 16.0, height: 8.8))

        image.unlockFocus()
        image.accessibilityDescription = "API Quota"
        return image
    }

    private func drawQuotaCellStatusGlyph(in rect: NSRect) {
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let body = NSRect(
            x: rect.minX,
            y: rect.minY + rect.height * 0.08,
            width: rect.width * 0.80,
            height: rect.height * 0.84
        )
        let cap = NSRect(
            x: body.maxX + rect.width * 0.050,
            y: body.midY - body.height * 0.24,
            width: rect.width * 0.090,
            height: body.height * 0.48
        )

        let bodyPath = NSBezierPath(roundedRect: body, xRadius: body.height * 0.30, yRadius: body.height * 0.30)
        bodyPath.lineWidth = 1.55
        bodyPath.stroke()

        let capPath = NSBezierPath(roundedRect: cap, xRadius: cap.height * 0.34, yRadius: cap.height * 0.34)
        capPath.fill()
        drawStatusBatteryFill(in: body)
    }

    private func drawStatusBatteryFill(in body: NSRect) {
        let fillArea = body.insetBy(dx: body.width * 0.16, dy: body.height * 0.28)
        let fill = NSRect(
            x: fillArea.minX,
            y: fillArea.minY,
            width: fillArea.width * 0.72,
            height: fillArea.height
        )
        NSBezierPath(
            roundedRect: fill,
            xRadius: fill.height * 0.42,
            yRadius: fill.height * 0.42
        ).fill()
    }

    private func setupPopover() {
        let contentView = MenuContentView(monitor: quotaMonitor)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.frame = NSRect(origin: .zero, size: MenuContentView.menuSize)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = MenuContentView.menuSize
        popover.contentViewController = hostingController
        popover.delegate = self
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button,
              let popover else { return }

        if popover.isShown {
            closeStatusPopover()
        } else {
            showStatusPopover(from: button)
        }
    }

    private func showStatusPopover(from button: NSStatusBarButton) {
        guard let popover else { return }
        popover.show(relativeTo: statusPopoverAnchorRect(for: button), of: button, preferredEdge: .minY)
        configurePopoverWindowAppearance()
        repositionStatusPopoverBelowMenuBar(relativeTo: button)
        DispatchQueue.main.async { [weak self] in
            self?.repositionStatusPopoverBelowMenuBar(relativeTo: button)
        }
        startPopoverMouseExitMonitor()
    }

    private func statusPopoverAnchorRect(for button: NSStatusBarButton) -> NSRect {
        var rect = button.bounds
        rect.origin.y = button.bounds.minY
        rect.size.height = max(1, min(statusPopoverAnchorHeight, button.bounds.height))
        return rect
    }

    private func repositionStatusPopoverBelowMenuBar(relativeTo button: NSStatusBarButton) {
        guard let window = popover?.contentViewController?.view.window else { return }
        let screen = button.window?.screen ?? window.screen ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        let allowedMaxY = visibleFrame.maxY - statusPopoverTopClearance
        var frame = window.frame
        guard frame.maxY > allowedMaxY else { return }

        frame.origin.y -= frame.maxY - allowedMaxY
        window.setFrame(frame, display: true)
    }

    private func configurePopoverWindowAppearance() {
        guard let window = popover?.contentViewController?.view.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func closeStatusPopover() {
        popover?.close()
        stopPopoverMouseExitMonitor()
    }

    private func startPopoverMouseExitMonitor() {
        stopPopoverMouseExitMonitor()

        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            self?.closePopoverIfMouseExited()
        }
        timer.tolerance = 0.10
        RunLoop.main.add(timer, forMode: .common)
        popoverMouseExitTimer = timer
    }

    private func stopPopoverMouseExitMonitor() {
        popoverMouseExitTimer?.invalidate()
        popoverMouseExitTimer = nil
    }

    private func closePopoverIfMouseExited() {
        guard let popover, popover.isShown else {
            stopPopoverMouseExitMonitor()
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let popoverFrame = popover.contentViewController?.view.window?.frame
        let buttonFrame: NSRect? = {
            guard let button = statusItem?.button,
                  let window = button.window else { return nil }
            let windowFrame = button.convert(button.bounds, to: nil)
            return window.convertToScreen(windowFrame)
        }()

        let isInsidePopover = popoverFrame?.insetBy(dx: -10, dy: -10).contains(mouseLocation) == true
        let isInsideButton = buttonFrame?.insetBy(dx: -10, dy: -8).contains(mouseLocation) == true

        if !isInsidePopover && !isInsideButton {
            closeStatusPopover()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopPopoverMouseExitMonitor()
    }

    @MainActor
    private func startMonitoring() {
        configureAutoRefreshTimer()
        AppAppearanceStore.shared.$autoRefreshInterval
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.configureAutoRefreshTimer()
            }
            .store(in: &cancellables)
        configureQuotaConsumingAutoRefreshTimer()
        AppAppearanceStore.shared.$quotaConsumingAutoRefreshInterval
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.configureQuotaConsumingAutoRefreshTimer()
            }
            .store(in: &cancellables)

        // 首次刷新
        quotaMonitor.refreshAll(mode: .automatic)
    }

    @MainActor
    private func configureAutoRefreshTimer() {
        autoRefreshCancellable?.cancel()
        autoRefreshCancellable = nil

        guard let interval = AppAppearanceStore.shared.autoRefreshInterval.timeInterval else {
            return
        }

        autoRefreshCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.quotaMonitor.refreshAll(mode: .automatic)
            }
    }

    @MainActor
    private func configureQuotaConsumingAutoRefreshTimer() {
        quotaConsumingAutoRefreshCancellable?.cancel()
        quotaConsumingAutoRefreshCancellable = nil

        guard let interval = AppAppearanceStore.shared.quotaConsumingAutoRefreshInterval.timeInterval else {
            return
        }

        quotaConsumingAutoRefreshCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.quotaMonitor.refreshQuotaConsumingProviders(mode: .quotaConsumingAutomatic)
            }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openPreferences()
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    @objc func openPreferences() {
        openPreferences(destination: .providers)
    }

    func openPreferencesFromStatusPopover(destination: SettingsDestination) {
        closeStatusPopover()
        DispatchQueue.main.async { [weak self] in
            self?.openPreferences(destination: destination)
        }
    }

    func openPreferences(destination: SettingsDestination) {
        SettingsNavigationStore.shared.select(destination)
        clearSwiftUISettingsWindowAutosaveFrame()

        if settingsWindow == nil {
            closeRestoredSettingsWindows()
            let settingsView = SettingsView(monitor: quotaMonitor)
            let controller = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: controller)
            window.title = "QuotaBar Settings"
            window.identifier = NSUserInterfaceItemIdentifier("QuotaBarMainSettingsWindow")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.tabbingMode = .disallowed
            window.delegate = self
            settingsWindow = window
        }

        if let settingsWindow {
            configureSettingsWindow(settingsWindow)
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let settingsWindow {
            scheduleSettingsWindowPlacementRecovery(settingsWindow)
        }
    }

    private func showManagedSettingsWindowOnLaunch() {
        DispatchQueue.main.async { [weak self] in
            self?.openPreferences()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if let settingsWindow, settingsWindow.isVisible {
            scheduleSettingsWindowPlacementRecovery(settingsWindow)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === settingsWindow else { return }
        scheduleSettingsWindowPlacementRecovery(window)
    }

    private func closeRestoredSettingsWindows() {
        for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled) {
            window.close()
        }
    }

    private func configureSettingsWindow(_ window: NSWindow) {
        window.minSize = minimumSettingsWindowSize
        window.collectionBehavior.insert(.moveToActiveSpace)

        if window.contentView?.bounds.width ?? 0 < preferredSettingsContentSize.width ||
            window.contentView?.bounds.height ?? 0 < preferredSettingsContentSize.height {
            window.setContentSize(preferredSettingsContentSize)
        }

        keepSettingsWindowOnScreen(window)
    }

    private func clearSwiftUISettingsWindowAutosaveFrame() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "NSWindow Frame com_apple_SwiftUI_Settings_window")
        defaults.removeObject(
            forKey: "NSSplitView Subview Frames com_apple_SwiftUI_Settings_window, SidebarNavigationSplitView"
        )
    }

    private func keepSettingsWindowOnScreen(_ window: NSWindow) {
        forceSettingsWindowOntoPreferredScreen(window)
    }

    private func scheduleSettingsWindowPlacementRecovery(_ window: NSWindow) {
        let delays: [TimeInterval] = [0, 0.15, 0.50]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak window] in
                guard let self, let window else { return }
                self.forceSettingsWindowOntoPreferredScreen(window)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func forceSettingsWindowOntoPreferredScreen(_ window: NSWindow) {
        let visibleFrame = preferredSettingsVisibleFrame().insetBy(dx: 24, dy: 24)
        let currentFrame = window.frame

        let targetSize = NSSize(
            width: min(max(currentFrame.width, minimumSettingsWindowSize.width), visibleFrame.width),
            height: min(max(currentFrame.height, minimumSettingsWindowSize.height), visibleFrame.height)
        )
        let centeredFrame = NSRect(
            x: visibleFrame.midX - targetSize.width / 2,
            y: visibleFrame.midY - targetSize.height / 2,
            width: targetSize.width,
            height: targetSize.height
        )
        window.setFrame(clampedFrame(centeredFrame, to: visibleFrame), display: true)
    }

    private func preferredSettingsVisibleFrame() -> NSRect {
        if let primaryScreen = NSScreen.screens.first(where: { screen in
            screen.frame.minX == 0 && screen.frame.minY == 0
        }), primaryScreen.visibleFrame.width > 0, primaryScreen.visibleFrame.height > 0 {
            return primaryScreen.visibleFrame
        }

        if let positiveScreen = NSScreen.screens.first(where: { screen in
            screen.visibleFrame.minX >= 0 && screen.visibleFrame.minY >= 0
        }) {
            return positiveScreen.visibleFrame
        }

        if let mainScreen = NSScreen.main, mainScreen.visibleFrame.width > 0, mainScreen.visibleFrame.height > 0 {
            return mainScreen.visibleFrame
        }

        let activeDisplayBounds = activeDisplayFrames()
        let preferredBounds = activeDisplayBounds.first { frame in
            frame.minX >= 0 && frame.minY >= 0
        }

        if let preferredBounds, preferredBounds.width > 0, preferredBounds.height > 0 {
            return NSRect(
                x: preferredBounds.minX,
                y: preferredBounds.minY,
                width: preferredBounds.width,
                height: max(1, preferredBounds.height - 33)
            )
        }

        return NSRect(x: 0, y: 0, width: 1512, height: 949)
    }

    private func activeDisplayFrames() -> [CGRect] {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return []
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else {
            return []
        }

        return displays
            .prefix(Int(displayCount))
            .map { CGDisplayBounds($0) }
            .filter { $0.width > 0 && $0.height > 0 }
            .sorted { lhs, rhs in
                if lhs.minX == rhs.minX {
                    return lhs.minY > rhs.minY
                }
                return lhs.minX > rhs.minX
            }
    }

    private func clampedFrame(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
        var adjusted = frame
        adjusted.size.width = min(adjusted.width, visibleFrame.width)
        adjusted.size.height = min(adjusted.height, visibleFrame.height)
        adjusted.origin.x = min(max(adjusted.minX, visibleFrame.minX), visibleFrame.maxX - adjusted.width)
        adjusted.origin.y = min(max(adjusted.minY, visibleFrame.minY), visibleFrame.maxY - adjusted.height)
        return adjusted
    }
}
