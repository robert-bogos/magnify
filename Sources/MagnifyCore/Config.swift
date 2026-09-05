import CoreGraphics
import Foundation

public enum Shape: String { case square, circle }
public enum Filter: String { case nearest, linear }

/// Runtime configuration. Mutable so live controls (scroll / keys) can adjust it.
public struct Config {
    public var zoom: CGFloat
    public var size: CGFloat
    public var shape: Shape
    public var fps: Int
    public var filter: Filter
    public var flipY: Bool

    public init(zoom: CGFloat = 2,
                size: CGFloat = 300,
                shape: Shape = .square,
                fps: Int = 60,
                filter: Filter = .nearest,
                flipY: Bool = false) {
        self.zoom = zoom
        self.size = size
        self.shape = shape
        self.fps = fps
        self.filter = filter
        self.flipY = flipY
    }

    public static let zoomRange: ClosedRange<CGFloat> = 1...20
    public static let sizeRange: ClosedRange<CGFloat> = 100...800

    public static func parse(_ args: [String]) -> Config {
        var c = Config()
        var i = 1
        func nextValue() -> String? {
            i += 1
            return i < args.count ? args[i] : nil
        }
        while i < args.count {
            switch args[i] {
            case "--zoom":   if let v = nextValue(), let d = Double(v) { c.zoom = CGFloat(d) }
            case "--size":   if let v = nextValue(), let d = Double(v) { c.size = CGFloat(d) }
            case "--shape":  if let v = nextValue(), let s = Shape(rawValue: v) { c.shape = s }
            case "--fps":    if let v = nextValue(), let n = Int(v) { c.fps = n }
            case "--filter": if let v = nextValue(), let f = Filter(rawValue: v) { c.filter = f }
            case "--flip-y": c.flipY = true
            case "-h", "--help": printUsage(); exit(0)
            default: break
            }
            i += 1
        }
        c.zoom = min(max(c.zoom, zoomRange.lowerBound), zoomRange.upperBound)
        c.size = min(max(c.size, sizeRange.lowerBound), sizeRange.upperBound)
        c.fps  = min(max(c.fps, 15), 120)
        return c
    }

    static func printUsage() {
        print("""
        magnify — a system-wide magnifying glass that follows your cursor.

        Usage: magnify [options]
          --zoom <n>     magnification factor (1–20, default 2)
          --size <pt>    lens size in points (100–800, default 300)
          --shape <s>    square | circle (default square)
          --fps <n>      capture frame rate (15–120, default 60)
          --filter <f>   nearest | linear (default nearest)
          --flip-y       flip vertical sampling (use if the lens image is inverted)
          -h, --help     show this help

        Quit: Ctrl-C in this terminal.
        Show/hide the lens: ⌃⌥M, or the 🔍 menu-bar item.
        With Accessibility permission granted, also: scroll or +/- to zoom,
        [ / ] to resize, Esc to quit.
        """)
    }
}
