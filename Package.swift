// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "magnify",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure, AppKit-free logic so it can be unit-tested.
        .target(name: "MagnifyCore"),
        // The actual overlay app (AppKit + ScreenCaptureKit).
        .executableTarget(
            name: "magnify",
            dependencies: ["MagnifyCore"]
        ),
        .testTarget(
            name: "MagnifyCoreTests",
            dependencies: ["MagnifyCore"]
        ),
    ]
)
