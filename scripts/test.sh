#!/bin/bash
# Runs the geometry checks with swiftc (XCTest/`swift test` needs full Xcode; this
# doesn't). The same assertions live in Tests/MagnifyCoreTests for when Xcode is present.
set -euo pipefail
cd "$(dirname "$0")/.."

SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="arm64-apple-macos13.0"
OUT=".build/manual"
mkdir -p "$OUT"

swiftc -sdk "$SDK" -target "$TARGET" \
    Sources/MagnifyCore/Geometry.swift scripts/checks/main.swift \
    -o "$OUT/geocheck"

"$OUT/geocheck"
