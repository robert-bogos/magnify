import AppKit
import QuartzCore
import CoreVideo
import Carbon.HIToolbox
import MagnifyCore

/// Wires the overlay window, the lens, screen capture, cursor tracking, and the
/// per-frame update loop together. UI mutations happen on the main thread.
final class AppController: NSObject {

    private var config: Config
    private let window: OverlayWindow
    private let contentView: NSView
    private let lens: LensLayer
    private let capturer = ScreenCapturer()

    private var displayLink: CVDisplayLink?
    private var currentDisplayID: CGDirectDisplayID?
    private var monitors: [Any] = []
    private var statusItem: NSStatusItem?
    private var statusInfoItem: NSMenuItem?
    private var statusToggleItem: NSMenuItem?
    private var userHidden = false
    private var retryTimer: Timer?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?

    init(config: Config, screen: NSScreen) {
        self.config = config
        self.window = OverlayWindow(screen: screen)
        self.contentView = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        self.lens = LensLayer(config: config)
        super.init()

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView
        contentView.layer?.addSublayer(lens.root)
    }

    func start() {
        window.orderFrontRegardless()
        capturer.excludedWindowID = CGWindowID(window.windowNumber)

        if let screen = DisplayManager.screenContainingCursor()
            ?? NSScreen.main
            ?? NSScreen.screens.first {
            moveTo(screen: screen)
        }

        startDisplayLink()
        installMonitors()
        installStatusItem()
        installHotKey()
        startRetryTimer()
    }

    func stop() {
        if let link = displayLink { CVDisplayLinkStop(link) }
        displayLink = nil
        retryTimer?.invalidate()
        retryTimer = nil
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
        if let h = hotKeyHandler { RemoveEventHandler(h); hotKeyHandler = nil }
        if let r = hotKeyRef { UnregisterEventHotKey(r); hotKeyRef = nil }
        Task { await capturer.stop() }
    }

    // MARK: - Render loop (vsync via CVDisplayLink; work dispatched to main)

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else {
            errPrint("Could not create display link.")
            return
        }
        CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
            DispatchQueue.main.async { self?.renderTick() }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(link)
        displayLink = link
    }

    // MARK: - Display handling

    private func moveTo(screen: NSScreen) {
        guard let id = DisplayManager.displayID(of: screen) else { return }
        window.setFrame(screen.frame, display: true)
        contentView.frame = NSRect(origin: .zero, size: screen.frame.size)
        currentDisplayID = id

        let scale = screen.backingScaleFactor
        let pw = Int(screen.frame.width * scale)
        let ph = Int(screen.frame.height * scale)
        let fps = config.fps
        Task { await capturer.switchTo(displayID: id, pixelWidth: pw, pixelHeight: ph, fps: fps) }
    }

    // MARK: - Per-frame update

    private func renderTick() {
        if userHidden { return } // toggled off via ⌃⌥M / menu — nothing to draw
        let mouse = NSEvent.mouseLocation
        guard let screen = DisplayManager.screen(containing: mouse) ?? NSScreen.main else { return }

        // Follow the cursor across displays.
        if let id = DisplayManager.displayID(of: screen), id != currentDisplayID {
            moveTo(screen: screen)
            return
        }

        // Don't show the lens until we actually have a captured frame. Otherwise a
        // black square sits under the cursor and blocks you from clicking around —
        // e.g. while granting Screen Recording permission.
        guard let img = capturer.latest() else {
            setLensHidden(true)
            setStatus(waiting: true)
            return
        }
        setStatus(waiting: false)

        let origin = window.frame.origin
        let cursorLocal = CGPoint(x: mouse.x - origin.x, y: mouse.y - origin.y)
        // Keep the lens fully on-screen: clamp its center so the square butts against
        // the display edge instead of hanging off it (where you'd lose sight of it).
        let center = Geometry.clampedLensCenter(cursorLocal: cursorLocal,
                                                displaySize: contentView.bounds.size,
                                                lensSizePt: config.size)
        let rect = Geometry.contentsRect(cursorGlobal: mouse,
                                         displayFrame: screen.frame,
                                         zoom: config.zoom,
                                         lensSizePt: config.size,
                                         flipY: config.flipY)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lens.root.isHidden = false
        lens.apply(size: config.size, shape: config.shape)
        lens.root.contents = img
        lens.root.contentsRect = rect
        lens.root.position = center
        CATransaction.commit()
    }

    private func setLensHidden(_ hidden: Bool) {
        guard lens.root.isHidden != hidden else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lens.root.isHidden = hidden
        CATransaction.commit()
    }

    private func setStatus(waiting: Bool) {
        let title = waiting ? "Waiting for Screen Recording permission…" : "Magnify — move the mouse"
        if statusInfoItem?.title != title { statusInfoItem?.title = title }
    }

    // MARK: - Capture retry

    private func startRetryTimer() {
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.retryCaptureIfNeeded()
        }
        RunLoop.main.add(timer, forMode: .common)
        retryTimer = timer
    }

    /// While we have no frames (usually: permission not granted yet), keep trying to
    /// start the stream so the lens appears automatically once you grant it — no
    /// relaunch needed.
    private func retryCaptureIfNeeded() {
        guard !userHidden else { return }
        guard capturer.latest() == nil else { return }
        guard let screen = DisplayManager.screenContainingCursor() ?? NSScreen.main else { return }
        moveTo(screen: screen)
    }

    // MARK: - Live controls (require Accessibility permission to fire globally)

    private func installMonitors() {
        let scrollG = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] e in
            self?.handleScroll(e)
        }
        let scrollL = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] e in
            self?.handleScroll(e); return e
        }
        let keyG = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] e in
            self?.handleKey(e)
        }
        let keyL = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] e in
            self?.handleKey(e); return e
        }
        monitors = [scrollG, scrollL, keyG, keyL].compactMap { $0 }
    }

    /// Register ⌃⌥M as a real system hot-key (Carbon). Unlike an NSEvent global
    /// monitor this needs no Accessibility permission and *consumes* the event, so it
    /// works out of the box and doesn't make the frontmost app "beep".
    private func installHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<AppController>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { controller.toggleLens() }
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &hotKeyHandler)

        let id = EventHotKeyID(signature: OSType(0x4D41_474E), id: 1) // 'MAGN'
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_M),
                                         UInt32(controlKey | optionKey),
                                         id,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        if status != noErr {
            errPrint("Could not register ⌃⌥M hot-key (status \(status)). Use the 🔍 menu to toggle.")
        }
    }

    // MARK: - Menu bar (so it's quittable without Accessibility)

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🔍"
        let menu = NSMenu()
        let info = NSMenuItem(title: "Waiting for Screen Recording permission…", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        statusInfoItem = info
        menu.addItem(.separator())
        let toggle = NSMenuItem(title: "Hide Lens (⌃⌥M)", action: #selector(toggleLens), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        statusToggleItem = toggle
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Magnify", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Show/hide the lens without quitting. Hiding also stops the capture stream so
    /// it isn't burning CPU in the background; showing restarts capture and the
    /// render loop brings the lens back as soon as the first frame lands.
    @objc private func toggleLens() {
        userHidden.toggle()
        if userHidden {
            setLensHidden(true)
            Task { await capturer.stop() }
        } else if let screen = DisplayManager.screenContainingCursor() ?? NSScreen.main {
            moveTo(screen: screen)
        }
        updateToggleMenuTitle()
    }

    private func updateToggleMenuTitle() {
        statusToggleItem?.title = userHidden ? "Show Lens (⌃⌥M)" : "Hide Lens (⌃⌥M)"
    }

    private func handleScroll(_ e: NSEvent) {
        let factor = 1 + (e.scrollingDeltaY * 0.01)
        config.zoom = clamp(config.zoom * factor, Config.zoomRange)
    }

    private func handleKey(_ e: NSEvent) {
        switch e.keyCode {
        case 53:     NSApp.terminate(nil)                                    // esc
        case 24, 69: config.zoom = clamp(config.zoom + 0.5, Config.zoomRange) // = / keypad +
        case 27, 78: config.zoom = clamp(config.zoom - 0.5, Config.zoomRange) // - / keypad -
        case 33:     config.size = clamp(config.size - 20, Config.sizeRange)  // [
        case 30:     config.size = clamp(config.size + 20, Config.sizeRange)  // ]
        default:     break
        }
    }

    private func clamp(_ v: CGFloat, _ r: ClosedRange<CGFloat>) -> CGFloat {
        min(max(v, r.lowerBound), r.upperBound)
    }
}
