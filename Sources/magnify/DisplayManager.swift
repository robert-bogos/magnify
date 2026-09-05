import AppKit

/// Helpers for locating the display under the cursor and mapping NSScreen ↔ SCDisplay.
enum DisplayManager {

    static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    static func screenContainingCursor() -> NSScreen? {
        screen(containing: NSEvent.mouseLocation)
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }
}
