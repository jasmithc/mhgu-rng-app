# Contributing

Thanks for helping! The app is macOS-only today, but the RNG engine is written to be shared, so a Windows or Linux version mainly needs a new front end.

## How the code is split

| Part | Path | Platforms |
|---|---|---|
| **RNGCore**: the RNG, charm generation, every search tool, and the snipe-timer maths (`ContinueCalc`, wait-time parsing, countdown). Swift standard library only. | `Sources/RNGCore` | macOS, Linux, Windows |
| **rngcheck**: command-line harness that runs any engine function and prints its output (standard library only) | `Sources/rngcheck` | macOS, Linux, Windows |
| **Unit tests** | `Tests/RNGCoreTests` | macOS, Linux, Windows |
| **SnipeKit**: the snipe timer model, precise beeps (AVFoundation) and timer panel, shared by both Apple apps | `Sources/SnipeKit` | macOS, iOS |
| **The macOS app**: SwiftUI windows, tool forms, settings | `Sources/MHXXRNG` | macOS only |
| **The iPhone/iPad app**: a Swift package app project, opened in Xcode | `ios/MHGUCharmsRNG.swiftpm` | iOS 17+ |

`Package.swift` only adds the macOS app target when building on a Mac, so `swift build` and `swift test` work on every platform.

## Building and testing

You need a [Swift toolchain](https://www.swift.org/install/) (5.9 or later). It comes with Xcode on macOS. CI uses the Swift that's preinstalled on GitHub's macOS and Ubuntu runners, and Swift 6.1 on Windows.

```bash
swift build -c release   # engine + rngcheck (+ the app on macOS)
swift test               # unit tests
```

To check the engine against the original Python notebook, get `mhxx-rng.ipynb` from [jasmithc/mhgu-rng](https://github.com/jasmithc/mhgu-rng) and run it (needs Python 3 only, no packages to install):

```bash
python3 tools/compare.py path/to/mhxx-rng.ipynb
```

[GitHub Actions](.github/workflows/ci.yml) runs all of this on macOS, Linux and Windows for every push and pull request.

## Adding a Windows or Linux front end

Build the new front end on top of `RNGCore` and keep platform-specific code out of the engine. A front end needs to:

1. **Run the tools.** Create an `Output`, an `Engine(kind:options:out:)`, call a tool (for example `search`, `around`, `searchCombo`), then show `output.lines`. Each line is a list of segments, and a segment's `tint` marks rarity colours. `Sources/rngcheck/main.swift` is the smallest working example, and `Sources/MHXXRNG/Views.swift` shows how the Mac app builds each tool's inputs.
2. **Run long searches off the UI thread.** The search loops check `Task.checkCancellation()`, so running them inside a `Task` gives you a working Stop button.
3. **Recreate the snipe timer panel.** Use `ContinueCalc`, `SnipeMath.parseWaitTime`, `SnipeMath.clockString` and `countdownSeconds` from RNGCore for the maths. Only the clock, the beeps and keeping the computer awake need platform code. For reference, see `Sources/MHXXRNG/Beeps.swift` (beeps scheduled to the millisecond) and `SnipeTimers.swift`.

Pick whichever UI approach suits the platform. Options include a Swift UI library for that platform, a command-line or terminal UI built on `rngcheck`, or another language that calls a small C-compatible wrapper around RNGCore. Please open an issue first if you plan a large change, so the approach can be discussed.

## Guidelines

- **Keep RNGCore dependency-free:** it uses only the Swift standard library (not even Foundation), so it builds anywhere Swift does. Put platform code such as UI, sound, files and settings in the front end.
- **Engine changes must keep matching the notebook.** Run `swift test` and `tools/compare.py` before opening a pull request.
- **Don't edit `Sources/RNGCore/Tables.swift` by hand.** It's generated from the notebook with `python3 tools/gen_tables.py path/to/mhxx-rng.ipynb`.
- By contributing, you agree that your work is released under the project's [MIT License](LICENSE).
