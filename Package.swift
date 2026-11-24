// swift-tools-version:5.9
import PackageDescription

// RNGCore and rngcheck are plain Swift + Foundation and build on macOS, Linux and Windows.
// The SwiftUI app is macOS-only, so it's only added when building on a Mac.
// See CONTRIBUTING.md for how to add a front end for another platform.

var targets: [Target] = [
  // Port of the mhxx-rng notebook's RNG and charm logic, plus the snipe-timer maths.
  .target(name: "RNGCore"),
  // Command-line harness used to compare output with the Python notebook (tools/compare.py).
  .executableTarget(name: "rngcheck", dependencies: ["RNGCore"]),
  // Unit tests for RNGCore; run with `swift test` on any platform.
  .testTarget(name: "RNGCoreTests", dependencies: ["RNGCore"]),
]

#if os(macOS)
// The native macOS app (SwiftUI/AppKit).
targets.append(.executableTarget(name: "MHXXRNG", dependencies: ["RNGCore"]))
#endif

let package = Package(
  name: "MHXXRNG",
  platforms: [.macOS(.v14)],
  targets: targets
)
