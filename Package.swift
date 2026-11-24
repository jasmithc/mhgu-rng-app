// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "MHXXRNG",
  platforms: [.macOS(.v14)],
  targets: [
    // Port of the notebook's RNG logic (cells 1st/2nd/3rd).
    .target(name: "RNGCore"),
    // The SwiftUI desktop app.
    .executableTarget(name: "MHXXRNG", dependencies: ["RNGCore"]),
    // Command-line harness used to compare output with the Python notebook.
    .executableTarget(name: "rngcheck", dependencies: ["RNGCore"]),
  ]
)
