import XCTest
import CoreGraphics
@testable import MagnifyCore

final class GeometryTests: XCTestCase {

    func testCenteredCursor() {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let r = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 400),
                                      displayFrame: frame, zoom: 2, lensSizePt: 200)
        // crop side = 200/2 = 100 pt → normalized 0.1 wide, 0.125 tall.
        XCTAssertEqual(r.width, 0.1, accuracy: 1e-6)
        XCTAssertEqual(r.height, 0.125, accuracy: 1e-6)
        XCTAssertEqual(r.midX, 0.5, accuracy: 1e-6)
        XCTAssertEqual(r.midY, 0.5, accuracy: 1e-6)
    }

    func testScreenTopLeftMapsToContentsTopLeft() {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        // Cursor at screen top-left in AppKit global coords is (x:0, y:height).
        // `CALayer.contentsRect` is bottom-left origin, so that maps to the left
        // edge (minX 0) and the TOP edge (maxY 1).
        let r = Geometry.contentsRect(cursorGlobal: CGPoint(x: 0, y: 800),
                                      displayFrame: frame, zoom: 2, lensSizePt: 200)
        XCTAssertEqual(r.minX, 0, accuracy: 1e-6)
        XCTAssertEqual(r.maxY, 1, accuracy: 1e-6)
    }

    func testScreenBottomRightMapsToContentsBottomRight() {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        // Screen bottom-right is (x:width, y:0) → right edge (maxX 1) and bottom (minY 0).
        let r = Geometry.contentsRect(cursorGlobal: CGPoint(x: 1000, y: 0),
                                      displayFrame: frame, zoom: 2, lensSizePt: 200)
        XCTAssertEqual(r.maxX, 1, accuracy: 1e-6)
        XCTAssertEqual(r.minY, 0, accuracy: 1e-6)
    }

    func testSecondaryDisplayOffset() {
        // A display to the right of the primary one.
        let frame = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let r = Geometry.contentsRect(cursorGlobal: CGPoint(x: 1500, y: 400),
                                      displayFrame: frame, zoom: 4, lensSizePt: 400)
        XCTAssertEqual(r.midX, 0.5, accuracy: 1e-6)
        XCTAssertEqual(r.width, 0.1, accuracy: 1e-6) // 400/4 = 100 → /1000
    }

    func testHigherZoomShrinksRegion() {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let low = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 500),
                                        displayFrame: frame, zoom: 2, lensSizePt: 300)
        let high = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 500),
                                         displayFrame: frame, zoom: 8, lensSizePt: 300)
        XCTAssertLessThan(high.width, low.width)
    }

    func testCursorUpSamplesHigherRegion() {
        // The bug this guards: moving the cursor UP must sample a HIGHER region
        // (larger minY), because macOS `CALayer.contentsRect` is bottom-left origin.
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let low  = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 200),
                                         displayFrame: frame, zoom: 2, lensSizePt: 200)
        let high = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 800),
                                         displayFrame: frame, zoom: 2, lensSizePt: 200)
        XCTAssertGreaterThan(high.minY, low.minY)
    }

    func testFlipYMirrorsSampledRow() {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        // Default (bottom-left): localY 750 → ny 0.75 → oy 0.70.
        let up = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 750),
                                       displayFrame: frame, zoom: 2, lensSizePt: 200)
        XCTAssertEqual(up.minY, 0.70, accuracy: 1e-6)
        // flipY mirrors it → 1 - 0.70 - 0.10 = 0.20.
        let flipped = Geometry.contentsRect(cursorGlobal: CGPoint(x: 500, y: 750),
                                            displayFrame: frame, zoom: 2, lensSizePt: 200, flipY: true)
        XCTAssertEqual(flipped.minY, 0.20, accuracy: 1e-6)
    }

    func testLensCenterUnclampedInMiddle() {
        let c = Geometry.clampedLensCenter(cursorLocal: CGPoint(x: 500, y: 400),
                                           displaySize: CGSize(width: 1000, height: 800),
                                           lensSizePt: 300)
        XCTAssertEqual(c.x, 500, accuracy: 1e-6)
        XCTAssertEqual(c.y, 400, accuracy: 1e-6)
    }

    func testLensCenterClampsAtCorner() {
        // Cursor at the display's top-left (bottom-left origin → x 0, y = height).
        let c = Geometry.clampedLensCenter(cursorLocal: CGPoint(x: 0, y: 800),
                                           displaySize: CGSize(width: 1000, height: 800),
                                           lensSizePt: 300)
        XCTAssertEqual(c.x, 150, accuracy: 1e-6)  // half a lens in from the left
        XCTAssertEqual(c.y, 650, accuracy: 1e-6)  // half a lens down from the top
    }

    func testLensCenterLargerThanDisplayIsCentered() {
        let c = Geometry.clampedLensCenter(cursorLocal: CGPoint(x: 10, y: 10),
                                           displaySize: CGSize(width: 200, height: 200),
                                           lensSizePt: 300)
        XCTAssertEqual(c.x, 100, accuracy: 1e-6)
        XCTAssertEqual(c.y, 100, accuracy: 1e-6)
    }
}
