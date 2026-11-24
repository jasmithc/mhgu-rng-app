// swift-tools-version:5.9
import PackageDescription

// RNGCore and rngcheck use only the Swift standard library and build on macOS, Linux and Windows.
// SnipeKit (snipe-timer model, beeps and panel) and the macOS app need Apple frameworks, so they're
// only added when building on a Mac. The iPhone/iPad app lives in ios/ and uses RNGCore and SnipeKit.
// See CONTRIBUTING.md for how to add a front end for another platform.

var products: [Product] = [
  .library(name: "RNGCore", targets: ["RNGCore"]),
]

var targets: [Target] = [
  // Port of the mhxx-rng notebook's RNG and charm logic, plus the snipe-timer maths.
  .target(name: "RNGCore"),
  // Command-line harness used to compare output with the Python notebook (tools/compare.py).
  .executableTarget(name: "rngcheck", dependencies: ["RNGCore"]),
  // Unit tests for RNGCore; run with `swift test` on any platform.
  .testTarget(name: "RNGCoreTests", dependencies: ["RNGCore"]),
]

#if os(macOS)
// Snipe timer shared by the macOS and iOS apps (SwiftUI, AVFoundation).
products.append(.library(name: "SnipeKit", targets: ["SnipeKit"]))
targets.append(.target(name: "SnipeKit", dependencies: ["RNGCore"]))
// The native macOS app (SwiftUI/AppKit).
targets.append(.executableTarget(name: "MHXXRNG", dependencies: ["RNGCore", "SnipeKit"]))
#endif

let package = Package(
  name: "MHXXRNG",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: products,
  targets: targets
)
