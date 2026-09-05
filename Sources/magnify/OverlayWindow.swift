import AppKit

/// A borderless, transparent, click-through window that floats above everything
/// (all apps, Spaces, the menu bar) and is itself excluded from screen capture.
final class OverlayWindow: NSWindow {

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // The whole point: you keep using the apps underneath.
        ignoresMouseEvents = true

        // Above the menu bar / Dock so we can magnify anything.
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        // Let other capturers (Meet/Teams/QuickTime) see the lens. We avoid the
        // hall-of-mirrors by excluding our own window from our own ScreenCaptureKit
        // stream by ID (see ScreenCapturer.excludedWindowID / SCContentFilter), so we
        // don't need the system-wide .none flag — which would also hide the lens from
        // every other screen share.
        sharingType = .readOnly

        isReleasedWhenClosed = false
        displaysWhenScreenProfileChanges = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
