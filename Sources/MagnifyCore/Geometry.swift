import CoreGraphics

/// Pure geometry for the magnifier. Isolated from AppKit so it can be unit-tested.
public enum Geometry {

    /// Compute the normalized sub-rectangle of the captured frame that the lens
    /// should display (i.e. the region under the cursor, sized for the zoom).
    ///
    /// Coordinate systems:
    ///  - `cursorGlobal` / `displayFrame` are in AppKit global points, **bottom-left** origin.
    ///  - The returned `CGRect` is normalized [0,1] for `CALayer.contentsRect`, which
    ///    on macOS is **also bottom-left** origin. Both axes are therefore measured
    ///    from the display's bottom-left corner, so no vertical flip is needed.
    ///
    /// Set `flipY: true` only if a particular setup samples vertically the wrong way
    /// (see README "Troubleshooting").
    public static func contentsRect(cursorGlobal: CGPoint,
                                    displayFrame: CGRect,
                                    zoom: CGFloat,
                                    lensSizePt: CGFloat,
                                    flipY: Bool = false) -> CGRect {
        let w = displayFrame.width
        let h = displayFrame.height
        guard w > 0, h > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }

        // Cursor position within the display, in points, bottom-left origin —
        // matching both AppKit global coords and macOS `CALayer.contentsRect`.
        let localX = cursorGlobal.x - displayFrame.origin.x
        let localY = cursorGlobal.y - displayFrame.origin.y

        // Source region side, in points. Larger zoom => smaller region shown.
        let cropSide = max(1, lensSizePt / max(zoom, 0.01))

        // Normalize per-axis. Width/height differ when the display isn't square,
        // which is correct: it still selects a square region in pixels.
        let cnx = min(cropSide / w, 1)
        let cny = min(cropSide / h, 1)

        let nx = localX / w
        let ny = localY / h

        var ox = nx - cnx / 2
        var oy = ny - cny / 2

        // Keep the lens full when the cursor nears an edge.
        ox = min(max(ox, 0), 1 - cnx)
        oy = min(max(oy, 0), 1 - cny)

        if flipY { oy = 1 - oy - cny }

        return CGRect(x: ox, y: oy, width: cnx, height: cny)
    }

    /// Clamp the lens's center so the square lens stays fully within the display,
    /// butting against the edge instead of hanging off it (where you'd lose sight
    /// of the lens — and your cursor — past the screen bounds).
    ///
    /// `cursorLocal` and the result are in the display's local point space
    /// (bottom-left origin, 0…width × 0…height). If the lens is larger than the
    /// display on an axis, it's centered on that axis.
    public static func clampedLensCenter(cursorLocal: CGPoint,
                                         displaySize: CGSize,
                                         lensSizePt: CGFloat) -> CGPoint {
        let half = lensSizePt / 2
        func clamp(_ v: CGFloat, within extent: CGFloat) -> CGFloat {
            guard extent >= lensSizePt else { return extent / 2 }
            return min(max(v, half), extent - half)
        }
        return CGPoint(x: clamp(cursorLocal.x, within: displaySize.width),
                       y: clamp(cursorLocal.y, within: displaySize.height))
    }
}
