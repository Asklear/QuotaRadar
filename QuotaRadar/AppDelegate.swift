import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var statusPanel: NSPanel?
    var statusPanelHostingController: NSHostingController<MenuContentView>?
    var quotaMonitor: QuotaMonitor!
    var settingsWindow: NSWindow?
    var popoverMouseExitTimer: Timer?
    var statusPanelClickMonitor: Any?
    var statusPanelGlobalClickMonitor: Any?
    weak var statusPanelSettingsOverlayButton: StatusPanelSettingsOverlayButton?
    var cancellables = Set<AnyCancellable>()
    private var autoRefreshCancellable: AnyCancellable?
    private var quotaConsumingAutoRefreshCancellable: AnyCancellable?
    private let settingsWindowFrameDefaultsKey = "QuotaRadarSettingsWindowFrame"
    private var isApplyingSettingsWindowPlacement = false
    private let preferredSettingsContentSize = NSSize(width: 1120, height: 640)
    private let minimumSettingsWindowSize = NSSize(width: 900, height: 600)
    private let statusPanelGap: CGFloat = 6
    private let statusPanelScreenInset: CGFloat = 10
    private let statusPanelOuterPadding: CGFloat = 18

    private var statusPanelSize: CGSize {
        CGSize(
            width: MenuContentView.menuSize.width + statusPanelOuterPadding * 2,
            height: MenuContentView.menuSize.height + statusPanelOuterPadding * 2
        )
    }

    private var statusPanelContentFrame: NSRect {
        NSRect(
            x: statusPanelOuterPadding,
            y: statusPanelOuterPadding,
            width: MenuContentView.menuSize.width,
            height: MenuContentView.menuSize.height
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LegacyConfigurationMigrator.migrateUserDefaultsIfNeeded()
        NSApp.setActivationPolicy(.regular)
        clearSwiftUISettingsWindowAutosaveFrame()
        quotaMonitor = QuotaMonitor.shared
        setupStatusBar()
        setupStatusPanel()
        startMonitoring()
        startLanguageMonitoring()
        showManagedSettingsWindowOnLaunch()
        GitHubReleaseUpdater.shared.checkForUpdatesIfNeededOnLaunch()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }

        let icon = makeStatusBarIcon()
        icon.isTemplate = true
        button.image = icon
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = nil
        button.toolTip = L10n.t(.apiQuotaTitle)

        // 监听点击
        button.target = self
        button.action = #selector(togglePopover)
    }

    private func makeStatusBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        drawQuotaRadarStatusGlyph(in: NSRect(x: 2.0, y: 2.2, width: 14.0, height: 14.0))

        image.unlockFocus()
        image.accessibilityDescription = L10n.t(.apiQuotaTitle)
        return image
    }

    private func drawQuotaRadarStatusGlyph(in rect: NSRect) {
        let tilePath = NSBezierPath(
            roundedRect: rect,
            xRadius: rect.width * 0.24,
            yRadius: rect.height * 0.24
        )
        NSColor.black.setFill()
        tilePath.fill()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear

        drawStatusIconInnerScreen(in: rect)

        let center = NSPoint(
            x: rect.minX + rect.width * 0.40,
            y: rect.minY + rect.height * 0.42
        )
        drawRadarPulseArc(center: center, radius: rect.width * 0.24, startAngle: 18, endAngle: 122, lineWidth: 1.15)
        drawRadarPulseArc(center: center, radius: rect.width * 0.39, startAngle: 18, endAngle: 124, lineWidth: 1.15)

        let sweep = NSBezierPath()
        sweep.move(to: center)
        sweep.line(to: NSPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY - rect.height * 0.24))
        sweep.lineWidth = 1.25
        sweep.lineCapStyle = .round
        sweep.stroke()

        let centerMarkerRect = NSRect(
            x: center.x - rect.width * 0.085,
            y: center.y - rect.height * 0.085,
            width: rect.width * 0.17,
            height: rect.height * 0.17
        )
        NSBezierPath(ovalIn: centerMarkerRect).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawStatusIconInnerScreen(in rect: NSRect) {
        let screenRect = rect.insetBy(dx: rect.width * 0.17, dy: rect.height * 0.17)
        let screenPath = NSBezierPath(
            roundedRect: screenRect,
            xRadius: rect.width * 0.13,
            yRadius: rect.height * 0.13
        )
        screenPath.lineWidth = 1.05
        screenPath.stroke()
    }

    private func drawRadarPulseArc(center: NSPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, lineWidth: CGFloat) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle)
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.stroke()
    }

    private func setupStatusPanel() {
        let contentView = MenuContentView(monitor: quotaMonitor)
        let hostingController = NSHostingController(rootView: contentView)
        let containerView = StatusPanelContainerView(frame: NSRect(origin: .zero, size: statusPanelSize))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        hostingController.view.frame = statusPanelContentFrame
        hostingController.view.autoresizingMask = []
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.addSubview(hostingController.view)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: statusPanelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = containerView
        panel.setContentSize(statusPanelSize)
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.level = .statusBar
        configureStatusPanelWindowAppearance(window: panel)
        installStatusPanelSettingsOverlay(on: containerView)

        statusPanelHostingController = hostingController
        statusPanel = panel
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if statusPanel?.isVisible == true {
            closeStatusPopover()
        } else {
            showStatusPanel(relativeTo: button)
        }
    }

    private func showStatusPanel(relativeTo button: NSStatusBarButton) {
        guard let panel = statusPanel else { return }

        AIQuoteStore.shared.advance()
        let frame = frameForStatusPanel(relativeTo: button)
        panel.setFrame(frame, display: true)
        configureStatusPanelWindowAppearance(window: panel)
        panel.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.statusPanel else { return }
            panel.setFrame(self.frameForStatusPanel(relativeTo: button), display: true)
        }
        startPopoverMouseExitMonitor()
    }

    private func frameForStatusPanel(relativeTo button: NSStatusBarButton) -> NSRect {
        let buttonFrame: NSRect
        if let window = button.window {
            let buttonFrameInWindow = button.convert(button.bounds, to: nil)
            buttonFrame = window.convertToScreen(buttonFrameInWindow)
        } else {
            buttonFrame = NSRect(origin: NSEvent.mouseLocation, size: .zero)
        }

        let screen = screenContainingStatusButton(buttonFrame)
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1512, height: 949)
        let size = statusPanelSize
        let minX = visibleFrame.minX + statusPanelScreenInset
        let maxX = visibleFrame.maxX - size.width - statusPanelScreenInset
        let preferredX = buttonFrame.midX - MenuContentView.menuSize.width / 2 - statusPanelOuterPadding
        let x = min(max(preferredX, minX), maxX)
        let preferredY = buttonFrame.minY - statusPanelGap - MenuContentView.menuSize.height - statusPanelOuterPadding
        let maxY = visibleFrame.maxY - statusPanelScreenInset - MenuContentView.menuSize.height - statusPanelOuterPadding
        let minY = visibleFrame.minY + statusPanelScreenInset - statusPanelOuterPadding
        let y = min(max(preferredY, minY), maxY)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func screenContainingStatusButton(_ buttonFrame: NSRect) -> NSScreen? {
        let buttonCenter = NSPoint(x: buttonFrame.midX, y: buttonFrame.midY)
        if let containingScreen = NSScreen.screens.first(where: { $0.frame.contains(buttonCenter) }) {
            return containingScreen
        }

        return NSScreen.screens.min { lhs, rhs in
            squaredDistance(from: buttonCenter, to: lhs.frame) < squaredDistance(from: buttonCenter, to: rhs.frame)
        } ?? NSScreen.main
    }

    private func squaredDistance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let deltaX = point.x - clampedX
        let deltaY = point.y - clampedY
        return deltaX * deltaX + deltaY * deltaY
    }

    private func configureStatusPanelWindowAppearance(window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func installStatusPanelSettingsOverlay(on contentView: NSView) {
        let button = StatusPanelSettingsOverlayButton(frame: statusHeaderSettingsHitRect(in: contentView))
        button.toolTip = L10n.t(.settingsTab)
        button.setAccessibilityLabel(L10n.t(.settingsTab))
        button.actionHandler = { [weak self] in
            self?.openPreferencesFromStatusPopover(destination: .settings)
        }
        statusPanelSettingsOverlayButton = button
        contentView.addSubview(button, positioned: .above, relativeTo: nil)
    }

    private func closeStatusPopover() {
        statusPanel?.orderOut(nil)
        stopPopoverMouseExitMonitor()
        stopStatusPanelClickMonitor()
    }

    private func startPopoverMouseExitMonitor() {
        stopPopoverMouseExitMonitor()
        startStatusPanelClickMonitor()

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

    private func startStatusPanelClickMonitor() {
        stopStatusPanelClickMonitor()

        statusPanelClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self,
                  let panel = self.statusPanel,
                  let contentView = panel.contentView,
                  panel.isVisible,
                  event.window === panel else {
                return event
            }

            let pointInContent = contentView.convert(event.locationInWindow, from: nil)
            if self.handleStatusPanelSettingsClick(at: pointInContent, in: contentView) {
                return nil
            }

            return event
        }

        statusPanelGlobalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self,
                  let panel = self.statusPanel,
                  panel.isVisible else {
                return
            }

            let screenPoint = NSEvent.mouseLocation
            guard panel.frame.contains(screenPoint),
                  let contentView = panel.contentView else {
                return
            }

            let pointInWindow = panel.convertPoint(fromScreen: screenPoint)
            let pointInContent = contentView.convert(pointInWindow, from: nil)
            _ = self.handleStatusPanelSettingsClick(at: pointInContent, in: contentView)
        }
    }

    private func stopStatusPanelClickMonitor() {
        if let statusPanelClickMonitor {
            NSEvent.removeMonitor(statusPanelClickMonitor)
            self.statusPanelClickMonitor = nil
        }
        if let statusPanelGlobalClickMonitor {
            NSEvent.removeMonitor(statusPanelGlobalClickMonitor)
            self.statusPanelGlobalClickMonitor = nil
        }
    }

    @discardableResult
    private func handleStatusPanelSettingsClick(at pointInContent: NSPoint, in contentView: NSView) -> Bool {
        guard statusPanel?.isVisible == true,
              statusHeaderSettingsHitRect(in: contentView).contains(pointInContent) else {
            return false
        }

        openPreferencesFromStatusPopover(destination: .settings)
        return true
    }

    private func statusHeaderSettingsHitRect(in contentView: NSView) -> NSRect {
        let size = statusPanelSize
        let visualTopRect = NSRect(
            x: statusPanelContentFrame.maxX - 68,
            y: statusPanelContentFrame.minY + 10,
            width: 54,
            height: 48
        )

        if contentView.isFlipped {
            return visualTopRect
        }

        return NSRect(
            x: visualTopRect.minX,
            y: size.height - visualTopRect.maxY,
            width: visualTopRect.width,
            height: visualTopRect.height
        )
    }

    private func closePopoverIfMouseExited() {
        guard let panel = statusPanel, panel.isVisible else {
            stopPopoverMouseExitMonitor()
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let panelFrame = panel.frame
        let buttonFrame: NSRect? = {
            guard let button = statusItem?.button,
                  let window = button.window else { return nil }
            let windowFrame = button.convert(button.bounds, to: nil)
            return window.convertToScreen(windowFrame)
        }()

        let isInsidePopover = panelFrame.insetBy(dx: -10, dy: -10).contains(mouseLocation)
        let isInsideButton = buttonFrame?.insetBy(dx: -10, dy: -8).contains(mouseLocation) == true

        if !isInsidePopover && !isInsideButton {
            closeStatusPopover()
        }
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
    }

    private func startLanguageMonitoring() {
        AppLanguageStore.shared.$language
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateLocalizedStatusBarStrings()
            }
            .store(in: &cancellables)
    }

    private func updateLocalizedStatusBarStrings() {
        if let button = statusItem?.button {
            button.toolTip = L10n.t(.apiQuotaTitle)
            button.image?.accessibilityDescription = L10n.t(.apiQuotaTitle)
        }

        statusPanelSettingsOverlayButton?.toolTip = L10n.t(.settingsTab)
        statusPanelSettingsOverlayButton?.setAccessibilityLabel(L10n.t(.settingsTab))
        settingsWindow?.title = L10n.t(.settingsWindowTitle)
    }

    @MainActor
    private func configureAutoRefreshTimer() {
        autoRefreshCancellable?.cancel()
        autoRefreshCancellable = nil

        guard let interval = AppAppearanceStore.shared.autoRefreshInterval.timeInterval else {
            return
        }

        refreshDueAutomaticProviders(interval: interval)

        autoRefreshCancellable = Timer.publish(every: automaticRefreshDueCheckInterval(for: interval), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshDueAutomaticProviders(interval: interval)
            }
    }

    @MainActor
    private func configureQuotaConsumingAutoRefreshTimer() {
        quotaConsumingAutoRefreshCancellable?.cancel()
        quotaConsumingAutoRefreshCancellable = nil

        guard let interval = AppAppearanceStore.shared.quotaConsumingAutoRefreshInterval.timeInterval else {
            return
        }

        refreshDueQuotaConsumingProviders(interval: interval)

        quotaConsumingAutoRefreshCancellable = Timer.publish(every: automaticRefreshDueCheckInterval(for: interval), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshDueQuotaConsumingProviders(interval: interval)
            }
    }

    private func automaticRefreshDueCheckInterval(for interval: TimeInterval) -> TimeInterval {
        min(interval, 15 * 60)
    }

    @MainActor
    private func refreshDueAutomaticProviders(interval: TimeInterval) {
        quotaMonitor.refreshProvidersDueForAutomaticRefresh(interval: interval, consumesSearchQuota: false, mode: .automatic)
    }

    @MainActor
    private func refreshDueQuotaConsumingProviders(interval: TimeInterval) {
        quotaMonitor.refreshProvidersDueForAutomaticRefresh(interval: interval, consumesSearchQuota: true, mode: .quotaConsumingAutomatic)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag, let settingsWindow, settingsWindow.isVisible {
            bringExistingSettingsWindowToFront(settingsWindow)
            return false
        }
        openPreferences()
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    @objc func openPreferences() {
        openPreferences(destination: .providers)
    }

    private func bringExistingSettingsWindowToFront(_ settingsWindow: NSWindow) {
        configureSettingsWindow(settingsWindow)
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        scheduleSettingsWindowPlacementRecovery(settingsWindow)
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

        let isCreatingSettingsWindow = settingsWindow == nil
        if settingsWindow == nil {
            closeRestoredSettingsWindows()
            let settingsView = SettingsView(monitor: quotaMonitor)
            let controller = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: controller)
            window.title = L10n.t(.settingsWindowTitle)
            window.identifier = NSUserInterfaceItemIdentifier("QuotaRadarMainSettingsWindow")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.tabbingMode = .disallowed
            window.delegate = self
            settingsWindow = window
        }

        if let settingsWindow {
            configureSettingsWindow(settingsWindow, restoreSavedFrameIfNeeded: isCreatingSettingsWindow)
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

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === settingsWindow else { return }
        saveSettingsWindowFrame(window)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === settingsWindow else { return }
        saveSettingsWindowFrame(window)
    }

    private func closeRestoredSettingsWindows() {
        for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled) {
            window.close()
        }
    }

    private func configureSettingsWindow(_ window: NSWindow) {
        configureSettingsWindow(window, restoreSavedFrameIfNeeded: false)
    }

    private func configureSettingsWindow(_ window: NSWindow, restoreSavedFrameIfNeeded: Bool) {
        window.minSize = minimumSettingsWindowSize
        window.contentMinSize = minimumSettingsWindowSize
        window.collectionBehavior.insert(.moveToActiveSpace)

        if window.contentView?.bounds.width ?? 0 < preferredSettingsContentSize.width ||
            window.contentView?.bounds.height ?? 0 < preferredSettingsContentSize.height {
            window.setContentSize(preferredSettingsContentSize)
        }

        restoreOrRepairSettingsWindowPlacement(window, restoreSavedFrameIfNeeded: restoreSavedFrameIfNeeded)
    }

    private func clearSwiftUISettingsWindowAutosaveFrame() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "NSWindow Frame com_apple_SwiftUI_Settings_window")
        defaults.removeObject(
            forKey: "NSSplitView Subview Frames com_apple_SwiftUI_Settings_window, SidebarNavigationSplitView"
        )
    }

    private func keepSettingsWindowOnScreen(_ window: NSWindow) {
        repairSettingsWindowPlacementIfNeeded(window)
    }

    private func scheduleSettingsWindowPlacementRecovery(_ window: NSWindow) {
        let delays: [TimeInterval] = [0, 0.15, 0.50]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak window] in
                guard let self, let window else { return }
                self.repairSettingsWindowPlacementIfNeeded(window)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func restoreOrRepairSettingsWindowPlacement(_ window: NSWindow, restoreSavedFrameIfNeeded: Bool) {
        if restoreSavedFrameIfNeeded,
           let savedFrame = savedSettingsWindowFrame(),
           settingsWindowFrameIsUsable(savedFrame) {
            setSettingsWindowFrame(savedFrame, for: window)
            return
        }

        repairSettingsWindowPlacementIfNeeded(window)
    }

    private func repairSettingsWindowPlacementIfNeeded(_ window: NSWindow) {
        guard !settingsWindowFrameIsUsable(window.frame) else {
            saveSettingsWindowFrame(window)
            return
        }

        placeSettingsWindowNearCurrentInteraction(window)
    }

    private func placeSettingsWindowNearCurrentInteraction(_ window: NSWindow) {
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
        setSettingsWindowFrame(clampedFrame(centeredFrame, to: visibleFrame), for: window)
    }

    private func preferredSettingsVisibleFrame() -> NSRect {
        let currentPoint = NSEvent.mouseLocation
        if let interactionScreen = NSScreen.screens.first(where: { screen in
            screen.frame.contains(currentPoint)
        }), interactionScreen.visibleFrame.width > 0, interactionScreen.visibleFrame.height > 0 {
            return interactionScreen.visibleFrame
        }

        if let button = statusItem?.button,
           let window = button.window {
            let buttonFrameInWindow = button.convert(button.bounds, to: nil)
            let buttonFrame = window.convertToScreen(buttonFrameInWindow)
            if let statusScreen = screenContainingStatusButton(buttonFrame),
               statusScreen.visibleFrame.width > 0,
               statusScreen.visibleFrame.height > 0 {
                return statusScreen.visibleFrame
            }
        }

        if let keyWindowScreen = NSApp.keyWindow?.screen,
           keyWindowScreen.visibleFrame.width > 0,
           keyWindowScreen.visibleFrame.height > 0 {
            return keyWindowScreen.visibleFrame
        }

        if let mainScreen = NSScreen.main, mainScreen.visibleFrame.width > 0, mainScreen.visibleFrame.height > 0 {
            return mainScreen.visibleFrame
        }

        let activeDisplayBounds = activeDisplayFrames()

        if let preferredBounds = activeDisplayBounds.first, preferredBounds.width > 0, preferredBounds.height > 0 {
            return NSRect(
                x: preferredBounds.minX,
                y: preferredBounds.minY,
                width: preferredBounds.width,
                height: max(1, preferredBounds.height - 33)
            )
        }

        return NSRect(x: 0, y: 0, width: 1512, height: 949)
    }

    private func savedSettingsWindowFrame() -> NSRect? {
        guard let value = UserDefaults.standard.string(forKey: settingsWindowFrameDefaultsKey),
              !value.isEmpty else {
            return nil
        }

        let frame = NSRectFromString(value)
        guard frame.width > 0, frame.height > 0 else {
            return nil
        }
        return frame
    }

    private func saveSettingsWindowFrame(_ window: NSWindow) {
        guard !isApplyingSettingsWindowPlacement,
              window === settingsWindow,
              settingsWindowFrameIsUsable(window.frame) else {
            return
        }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: settingsWindowFrameDefaultsKey)
    }

    private func settingsWindowFrameIsUsable(_ frame: NSRect) -> Bool {
        guard frame.width >= minimumSettingsWindowSize.width * 0.5,
              frame.height >= minimumSettingsWindowSize.height * 0.5 else {
            return false
        }

        return NSScreen.screens.contains { screen in
            let visibleFrame = screen.visibleFrame
            let intersection = frame.intersection(visibleFrame)
            let minimumVisibleWidth = min(240, frame.width * 0.25)
            let minimumVisibleHeight = min(160, frame.height * 0.25)
            return intersection.width >= minimumVisibleWidth && intersection.height >= minimumVisibleHeight
        }
    }

    private func setSettingsWindowFrame(_ frame: NSRect, for window: NSWindow) {
        let targetVisibleFrame = visibleFrameForSettingsWindowFrame(frame)?.insetBy(dx: 24, dy: 24)
            ?? preferredSettingsVisibleFrame().insetBy(dx: 24, dy: 24)
        let clamped = clampedFrame(frame, to: targetVisibleFrame)

        isApplyingSettingsWindowPlacement = true
        window.setFrame(clamped, display: true)
        isApplyingSettingsWindowPlacement = false
        saveSettingsWindowFrame(window)
    }

    private func visibleFrameForSettingsWindowFrame(_ frame: NSRect) -> NSRect? {
        NSScreen.screens
            .map { screen -> (visibleFrame: NSRect, area: CGFloat) in
                let intersection = frame.intersection(screen.visibleFrame)
                return (screen.visibleFrame, max(0, intersection.width) * max(0, intersection.height))
            }
            .filter { $0.area > 0 }
            .max { lhs, rhs in lhs.area < rhs.area }?
            .visibleFrame
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

final class StatusPanelSettingsOverlayButton: NSButton {
    var actionHandler: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        setButtonType(.momentaryChange)
        imagePosition = .noImage
        title = ""
        focusRingType = .none
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        target = self
        action = #selector(performOverlayAction(_:))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        performOverlayAction(self)
    }

    override func performClick(_ sender: Any?) {
        performOverlayAction(sender)
    }

    @objc private func performOverlayAction(_ sender: Any?) {
        actionHandler?()
    }
}

final class StatusPanelContainerView: NSView {
    override var isOpaque: Bool {
        false
    }
}
