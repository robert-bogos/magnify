import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import CoreImage

/// Wraps a ScreenCaptureKit stream. Captures the display the cursor is on, stores
/// the most recent frame as a CGImage, and can switch displays on demand.
final class ScreenCapturer: NSObject, SCStreamOutput, SCStreamDelegate {

    private let sampleQueue = DispatchQueue(label: "magnify.capture.samples")
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let lock = NSLock()

    private var _latest: CGImage?
    private var stream: SCStream?
    private var switching = false

    /// Window number of our overlay, so we can exclude it from capture.
    var excludedWindowID: CGWindowID = 0

    /// The most recent captured frame (nil until the first frame arrives).
    func latest() -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        return _latest
    }

    // Synchronous helpers so we never touch NSLock from an async context.
    private func beginSwitching() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if switching { return false }
        switching = true
        return true
    }
    private func endSwitching() {
        lock.lock(); switching = false; lock.unlock()
    }

    /// (Re)build the stream to capture the given display at native pixel size.
    func switchTo(displayID: CGDirectDisplayID, pixelWidth: Int, pixelHeight: Int, fps: Int) async {
        guard beginSwitching() else { return }
        defer { endSwitching() }

        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                errPrint("Display \(displayID) not shareable.")
                return
            }
            let excluded = content.windows.filter { $0.windowID == excludedWindowID }
            let filter = SCContentFilter(display: display, excludingWindows: excluded)

            let config = SCStreamConfiguration()
            config.width = max(2, pixelWidth)
            config.height = max(2, pixelHeight)
            config.showsCursor = true
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(1, fps)))
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.queueDepth = 3

            if let old = stream {
                try? await old.stopCapture()
                stream = nil
            }

            let newStream = SCStream(filter: filter, configuration: config, delegate: self)
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
            try await newStream.startCapture()
            stream = newStream
        } catch {
            errPrint("""
            Screen capture failed: \(error.localizedDescription)
            → Grant Screen Recording in System Settings ▸ Privacy & Security ▸ \
            Screen Recording, then relaunch.
            """)
        }
    }

    func stop() async {
        if let s = stream { try? await s.stopCapture() }
        stream = nil
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferIsValid(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Only use complete frames.
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]],
           let rawStatus = attachments.first?[.status] as? Int,
           rawStatus != SCFrameStatus.complete.rawValue {
            return
        }

        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return }
        lock.lock(); _latest = cg; lock.unlock()
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        errPrint("Capture stopped: \(error.localizedDescription)")
    }
}
