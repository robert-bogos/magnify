import CoreGraphics
import Foundation

// Standalone geometry checks (compiled together with Geometry.swift as one module,
// so no import is needed). Mirrors Tests/MagnifyCoreTests/GeometryTests.swift.

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond { print("✓ \(msg)") } else { print("✗ \(msg)"); failures += 1 }
}
func approx(_ a: CGFloat, _ b: CGFloat, _ tol: CGFloat = 1e-6) -> Bool { abs(a - b) < tol }

let f = CGRect(x: 0, y: 0, width: 1000, height: 800)

let center = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 400),
                                   displayFrame: f, zoom: 2, lensSizePt: 200)
check(approx(center.width, 0.1), "centered: width normalized to 0.1")
check(approx(center.height, 0.125), "centered: height normalized to 0.125")
check(approx(center.midX, 0.5) && approx(center.midY, 0.5), "centered: rect centered on cursor")

// Screen top-left in AppKit global coords is (x:0, y:height). With a bottom-left
// contentsRect that maps to the left edge (minX 0) and the TOP edge (maxY 1).
let tl = Geometry.contentsRect(cursorGlobal: CGPoint(x: 0, y: 800),
                               displayFrame: f, zoom: 2, lensSizePt: 200)
check(approx(tl.minX, 0) && approx(tl.maxY, 1), "screen top-left → contentsRect left+top edge")

// Screen bottom-right is (x:width, y:0) → right edge (maxX 1) and bottom (minY 0).
let br = Geometry.contentsRect(cursorGlobal: CGPoint(x: 1000, y: 0),
                               displayFrame: f, zoom: 2, lensSizePt: 200)
check(approx(br.maxX, 1) && approx(br.minY, 0), "screen bottom-right → contentsRect right+bottom edge")

let secondary = Geometry.contentsRect(cursorGlobal: CGPoint(x: 1500, y: 400),
                                      displayFrame: CGRect(x: 1000, y: 0, width: 1000, height: 800),
                                      zoom: 4, lensSizePt: 400)
check(approx(secondary.midX, 0.5), "secondary display: cursor maps to display-local center")
check(approx(secondary.width, 0.1), "secondary display: zoom 4 shrinks region to 0.1")

let sq = CGRect(x: 0, y: 0, width: 1000, height: 1000)
let low = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 500), displayFrame: sq, zoom: 2, lensSizePt: 300)
let high = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 500), displayFrame: sq, zoom: 8, lensSizePt: 300)
check(high.width < low.width, "higher zoom shows a smaller region")

// Regression test for vertical tracking: moving the cursor UP must sample a
// HIGHER region (larger minY) under the bottom-left contentsRect convention.
let lowCursor  = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 200), displayFrame: sq, zoom: 2, lensSizePt: 200)
let highCursor = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 800), displayFrame: sq, zoom: 2, lensSizePt: 200)
check(highCursor.minY > lowCursor.minY, "cursor up → higher sampled region")

// flipY mirrors the sampled row (escape hatch for setups that sample top-down).
let up      = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 750), displayFrame: sq, zoom: 2, lensSizePt: 200)
let flipped = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 750), displayFrame: sq, zoom: 2, lensSizePt: 200, flipY: true)
check(approx(up.minY, 0.70), "default: high cursor samples high region")
check(approx(flipped.minY, 0.20), "flipY mirrors the sampled row")

// Lens center clamps so the square lens never hangs off the display edge.
let disp = CGSize(width: 1000, height: 800)
let midLens = Geometry.clampedLensCenter(cursorLocal: CGPoint(x: 500, y: 400), displaySize: disp, lensSizePt: 300)
check(approx(midLens.x, 500) && approx(midLens.y, 400), "lens center: unclamped away from edges")
let cornerLens = Geometry.clampedLensCenter(cursorLocal: CGPoint(x: 0, y: 800), displaySize: disp, lensSizePt: 300)
check(approx(cornerLens.x, 150) && approx(cornerLens.y, 650), "lens center: clamps at a corner (300pt lens stays on-screen)")
let hugeLens = Geometry.clampedLensCenter(cursorLocal: CGPoint(x: 10, y: 10), displaySize: CGSize(width: 200, height: 200), lensSizePt: 300)
check(approx(hugeLens.x, 100) && approx(hugeLens.y, 100), "lens center: lens bigger than display → centered")

if failures == 0 {
    print("\nAll geometry checks passed.")
} else {
    print("\n\(failures) check(s) failed.")
    exit(1)
}
