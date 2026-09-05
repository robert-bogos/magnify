import AppKit
import QuartzCore
import MagnifyCore

/// The magnifier itself: a Core Animation layer whose `contents` is the latest
/// captured frame and whose `contentsRect` is moved to the region under the cursor.
/// The layer scales that sub-rect up to fill its bounds — GPU-cheap magnification
/// with no per-frame CPU cropping.
final class LensLayer {

    let root = CALayer()
    private let border = CALayer()
    private let hLine = CALayer()
    private let vLine = CALayer()

    init(config: Config) {
        root.masksToBounds = true
        root.contentsGravity = .resizeAspectFill
        root.magnificationFilter = (config.filter == .nearest) ? .nearest : .linear
        root.backgroundColor = NSColor.black.cgColor
        root.isHidden = true // stays hidden until the first captured frame arrives

        border.borderWidth = 2
        // Solid white + a difference-blend compositing filter makes the stroke render
        // as the inverse of whatever is beneath it (white→black on light content, the
        // complement on colored content), so it never vanishes on white backgrounds the
        // way a fixed white border did. Set once here, not per-frame in apply().
        border.borderColor = NSColor.white.cgColor
        border.compositingFilter = "differenceBlendMode"
        border.masksToBounds = true
        root.addSublayer(border)

        let crossColor = NSColor.white.withAlphaComponent(0.35).cgColor
        hLine.backgroundColor = crossColor
        vLine.backgroundColor = crossColor
        root.addSublayer(hLine)
        root.addSublayer(vLine)

        apply(size: config.size, shape: config.shape)
    }

    /// Resize / reshape the lens. Cheap enough to call every frame.
    func apply(size: CGFloat, shape: Shape) {
        let radius: CGFloat = (shape == .circle) ? size / 2 : 8
        root.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        root.cornerRadius = radius

        border.frame = root.bounds
        border.cornerRadius = radius

        hLine.frame = CGRect(x: 0, y: size / 2 - 0.5, width: size, height: 1)
        vLine.frame = CGRect(x: size / 2 - 0.5, y: 0, width: 1, height: size)
    }
}
