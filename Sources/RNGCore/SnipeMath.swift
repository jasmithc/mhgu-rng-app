// Platform-independent maths behind the snipe timer panel, so any front end
// (macOS, Windows, Linux, CLI) can share it.

/// Game timing constants.
public enum SnipeMath {
  /// The game runs at 30 frames per second.
  public static let fps = 30.0
  /// Default pace for continue cycles, in presses per minute.
  public static let bpm = 60.0
  /// Paces the timer accepts, in presses per minute.
  public static let bpmRange = 30...240

  /// Parse a wait time typed as `Xd Xh Xm Xs Xf` (any subset of the parts, in any order)
  /// or as a plain frame count. Returns the total in frames, or nil if it can't be read.
  public static func parseWaitTime(_ text: String) -> Int? {
    let s = text.lowercased().split(whereSeparator: { $0.isWhitespace })
    if s.isEmpty { return nil }
    if s.count == 1, let n = Int(s[0]) { return n }
    let mult: [Character: Int] = ["d": 2_592_000, "h": 108_000, "m": 1800, "s": 30, "f": 1]
    var total = 0
    for token in s {
      guard let unit = token.last, let m = mult[unit], let v = Int(token.dropLast()) else { return nil }
      total += v * m
    }
    return total
  }

  /// Format seconds as `h:mm:ss.cc` (hundredths, rounded down), with a leading "−" when negative.
  public static func clockString(_ seconds: Double) -> String {
    let neg = seconds < 0
    let cs = Int((abs(seconds) * 100).rounded(.down))
    let h = cs / 360_000, m = (cs / 6000) % 60, s = (cs / 100) % 60, c = cs % 100
    func two(_ v: Int) -> String { v < 10 ? "0\(v)" : "\(v)" }
    return (neg ? "−" : "") + "\(h):\(two(m)):\(two(s)).\(two(c))"
  }
}

/// The Continue Cycle formula:
///   (Target Frame − 3600) / 702                     = continue advances with 2 minutes to spare
///   advances / BPM (60 by default)                   = minutes to perform them
///   minutes × 1800                                   = frames advanced meanwhile
///   (Target Frame − 3600 − frames advanced) / 702    = continue advances needed
public struct ContinueCalc: Sendable {
  /// Cycles taken off when Poogie is in the room, leaving time to remove it.
  public static let poogieCycles = 5

  public let target: Int
  public var poogie: Bool
  /// Continue presses per minute.
  public var bpm: Double

  /// `bpm` is kept within `SnipeMath.bpmRange`; a non-number falls back to the default.
  public init(target: Int, poogie: Bool = false, bpm: Double = SnipeMath.bpm) {
    self.target = target
    self.poogie = poogie
    let r = SnipeMath.bpmRange
    self.bpm = bpm.isFinite ? min(max(bpm, Double(r.lowerBound)), Double(r.upperBound)) : SnipeMath.bpm
  }

  public var advancesWithSpare: Double { Double(target - 3600) / 702 }
  public var minutes: Double { advancesWithSpare / bpm }
  public var framesAdvanced: Double { minutes * 1800 }
  public var needed: Double { (Double(target - 3600) - framesAdvanced) / 702 }
  /// Rounded down so the cycles never overshoot the target, minus the Poogie allowance.
  public var neededWhole: Int {
    guard needed.isFinite else { return 0 }
    return max(0, Int(needed.rounded(.down)) - (poogie ? ContinueCalc.poogieCycles : 0))
  }
}

/// The final countdown: wait time − stopwatch + correction, all in seconds.
public func countdownSeconds(waitFrames: Int, stopwatchSeconds: Double, correctionSeconds: Double) -> Double {
  Double(waitFrames) / SnipeMath.fps - stopwatchSeconds + correctionSeconds
}
