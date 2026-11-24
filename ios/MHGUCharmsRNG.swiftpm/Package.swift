// swift-tools-version: 5.9
// The iPhone/iPad app. Open this folder in Xcode (or run ios/build.sh).
// It uses the shared engine (RNGCore) and snipe timer (SnipeKit) from the repository root.
import PackageDescription
import AppleProductTypes

let package = Package(
  name: "MHGUCharmsRNG",
  platforms: [.iOS("17.0")],
  products: [
    .iOSApplication(
      name: "MHGU Charms RNG",
      targets: ["App"],
      bundleIdentifier: "io.github.jasmithc.mhgu-charms-rng",
      displayVersion: "1.0.6",
      bundleVersion: "1",
      appIcon: .asset("AppIcon"),
      accentColor: .presetColor(.blue),
      supportedDeviceFamilies: [.phone, .pad],
      supportedInterfaceOrientations: [
        .portrait, .landscapeLeft, .landscapeRight,
        .portraitUpsideDown(.when(deviceFamilies: [.pad])),
      ]
    ),
  ],
  dependencies: [
    // The repository root (folder name "mhgu-rng-app" when cloned from GitHub).
    .package(path: "../.."),
  ],
  targets: [
    .executableTarget(
      name: "App",
      dependencies: [
        .product(name: "RNGCore", package: "mhgu-rng-app"),
        .product(name: "SnipeKit", package: "mhgu-rng-app"),
      ],
      path: "Sources/App"   // Resources/Assets.xcassets (app icon) is picked up automatically
    ),
  ]
)
