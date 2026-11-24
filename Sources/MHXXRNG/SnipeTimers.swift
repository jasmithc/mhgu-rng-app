import Foundation
import RNGCore

/// The Continue Cycle formula:
///   (Target Frame − 3600) / 700                     = continue advances with 2 minutes to spare
///   advances / 60 BPM                                = minutes to perform them
///   minutes × 1800                                   = frames advanced meanwhile
///   (Target Frame − 3600 − frames advanced) / 702    = continue advances needed
struct ContinueCalc {
  static let poogieCycles = 5
  let target: Int
  /// Poogie is in the room: do 5 fewer cycles, leaving time to remove it.
  var poogie = false
  var advancesWithSpare: Double { Double(target - 3600) / 700 }
  var minutes: Double { advancesWithSpare / SnipeTimers.bpm }
  var framesAdvanced: Double { minutes * 1800 }
  var needed: Double { (Double(target - 3600) - framesAdvanced) / 702 }
  /// Rounded down, so the cycles never overshoot the target.
  var neededWhole: Int {
    max(0, Int(needed.rounded(.down)) - (poogie ? ContinueCalc.poogieCycles : 0))
  }
}

enum CorrectionUnit: String, CaseIterable, Identifiable {
  case seconds = "seconds", frames = "frames"
  var id: String { rawValue }
}

@MainActor
final class SnipeTimers: ObservableObject {
  nonisolated static let bpm = 60.0
  nonisolated static let fps = 30.0
  private let defaults = UserDefaults.standard
  private let clock = ContinuousClock()

  // MARK: Calculator
  @Published var calcTarget: Int {
    didSet {
      defaults.set(calcTarget, forKey: "timer.calcTarget")
      if !counterRunning { counterTarget = calc.neededWhole }
    }
  }
  @Published var poogie: Bool {
    didSet {
      defaults.set(poogie, forKey: "timer.poogie")
      if !counterRunning { counterTarget = calc.neededWhole }
    }
  }
  var calc: ContinueCalc { ContinueCalc(target: calcTarget, poogie: poogie) }

  // MARK: Continue counter (60 BPM metronome)
  @Published var counterTarget: Int
  @Published private(set) var counterStart: ContinuousClock.Instant?
  @Published private(set) var counterRunning = false
  @Published private(set) var counterFinished = false
  private let counterBeeps = BeepScheduler()

  // MARK: Stopwatch
  @Published private(set) var swStart: ContinuousClock.Instant?
  @Published private(set) var swAccumulated: Double = 0

  // MARK: Countdown
  @Published var waitText: String { didSet { defaults.set(waitText, forKey: "timer.waitText") } }
  @Published var correction: Double { didSet { defaults.set(correction, forKey: "timer.correction") } }
  @Published var correctionUnit: CorrectionUnit {
    didSet { defaults.set(correctionUnit.rawValue, forKey: "timer.correctionUnit") }
  }
  @Published private(set) var cdEnd: ContinuousClock.Instant?
  @Published private(set) var cdTotal: Double = 0
  @Published private(set) var cdUsedStopwatch: Double = 0
  @Published private(set) var cdRunning = false
  @Published private(set) var cdFinished = false
  @Published var cdError: String?
  private let countdownBeeps = BeepScheduler()

  private var activity: NSObjectProtocol?

  init() {
    let t = defaults.object(forKey: "timer.calcTarget") as? Int ?? 300_000
    calcTarget = t
    let pg = defaults.bool(forKey: "timer.poogie")
    poogie = pg
    counterTarget = ContinueCalc(target: t, poogie: pg).neededWhole
    waitText = defaults.string(forKey: "timer.waitText") ?? "0d 0h 2m 37s 13f"
    correction = defaults.object(forKey: "timer.correction") as? Double ?? 0
    correctionUnit = CorrectionUnit(rawValue: defaults.string(forKey: "timer.correctionUnit") ?? "") ?? .seconds
    // Start the audio engine now so the first beep isn't delayed by engine start-up.
    DispatchQueue.global(qos: .userInitiated).async { SoundPlayer.shared.prepare() }
  }

  var now: ContinuousClock.Instant { clock.now }

  // MARK: Counter

  func counterValue(at t: ContinuousClock.Instant) -> Int {
    if counterFinished { return counterTarget }
    guard let s = counterStart else { return 0 }
    let elapsed = (t - s).seconds
    return min(counterTarget, Int((elapsed * SnipeTimers.bpm / 60).rounded(.down)) + 1)
  }

  func startCounter() {
    guard counterTarget > 0 else { return }
    let start = clock.now + .milliseconds(150)  // let the audio engine settle before beat 1
    let period = 60 / SnipeTimers.bpm
    let events = (0..<counterTarget).map { n in
      BeepScheduler.Event(at: start + .nanoseconds(Int64(Double(n) * period * 1e9)),
                          beep: n == counterTarget - 1 ? .beatFinal : .beat)
    }
    counterStart = start
    counterRunning = true
    counterFinished = false
    counterBeeps.start(events) { [weak self] in
      Task { @MainActor in
        guard let self, self.counterRunning else { return }
        self.counterRunning = false
        self.counterFinished = true
        self.updateActivity()
      }
    }
    updateActivity()
  }

  func stopCounter() {
    counterBeeps.cancel()
    counterRunning = false
    updateActivity()
  }

  func resetCounter() {
    stopCounter()
    counterStart = nil
    counterFinished = false
  }

  // MARK: Stopwatch

  var swRunning: Bool { swStart != nil }

  func swElapsed(at t: ContinuousClock.Instant) -> Double {
    swAccumulated + (swStart.map { (t - $0).seconds } ?? 0)
  }

  func toggleStopwatch() {
    if let s = swStart {
      swAccumulated += (clock.now - s).seconds
      swStart = nil
    } else {
      swStart = clock.now
    }
  }

  func resetStopwatch() {
    swStart = nil
    swAccumulated = 0
  }

  // MARK: Countdown

  /// Frames parsed from the wait-time box: "Xd Xh Xm Xs Xf" (any parts) or a plain frame count.
  var waitFrames: Int? { SnipeTimers.parseWaitTime(waitText) }

  var correctionSeconds: Double {
    correctionUnit == .frames ? correction / SnipeTimers.fps : correction
  }

  /// wait − stopwatch + correction, using the stopwatch's value at `t`.
  func plannedTotal(at t: ContinuousClock.Instant) -> Double? {
    guard let f = waitFrames else { return nil }
    return Double(f) / SnipeTimers.fps - swElapsed(at: t) + correctionSeconds
  }

  func cdRemaining(at t: ContinuousClock.Instant) -> Double {
    if cdFinished { return 0 }
    guard let end = cdEnd else { return plannedTotal(at: t) ?? 0 }
    return max(0, (end - t).seconds)
  }

  func startCountdown() {
    cdError = nil
    let t = clock.now
    guard waitFrames != nil else {
      cdError = "Wait time must look like \"0d 1h 40m 6s 15f\" or be a frame count."
      return
    }
    // Freeze the stopwatch at the moment the countdown starts and use that value.
    if swRunning { toggleStopwatch() }
    let used = swElapsed(at: t)
    guard let total = plannedTotal(at: t), total > 0 else {
      cdError = "Nothing to count down: the stopwatch and correction already cover the wait time."
      return
    }
    let end = t + .nanoseconds(Int64(total * 1e9))
    var events: [BeepScheduler.Event] = []
    for k in 1...10 where Double(k) < total {
      events.append(.init(at: end - .seconds(k), beep: .tick))
    }
    events.append(.init(at: end, beep: .finalMain))
    cdUsedStopwatch = used
    cdTotal = total
    cdEnd = end
    cdRunning = true
    cdFinished = false
    countdownBeeps.start(events) { [weak self] in
      Task { @MainActor in
        guard let self, self.cdRunning else { return }
        self.cdRunning = false
        self.cdFinished = true
        self.updateActivity()
      }
    }
    updateActivity()
  }

  func cancelCountdown() {
    countdownBeeps.cancel()
    cdRunning = false
    cdEnd = nil
    cdFinished = false
    updateActivity()
  }

  /// Fill in the wait time from a frame count (used by the Frame → Wait Time tool).
  func setWaitFrames(_ frames: Int) {
    waitText = frameTime(frames)
  }

  /// Keep the Mac (and its display) awake while the metronome or countdown is running.
  private func updateActivity() {
    let busy = counterRunning || cdRunning
    if busy && activity == nil {
      activity = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiated, .idleSystemSleepDisabled, .idleDisplaySleepDisabled],
        reason: "Snipe timer running")
    } else if !busy, let a = activity {
      ProcessInfo.processInfo.endActivity(a)
      activity = nil
    }
  }

  // MARK: Parsing / formatting

  static func parseWaitTime(_ text: String) -> Int? {
    let s = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if s.isEmpty { return nil }
    if let n = Int(s) { return n }
    let mult: [Character: Int] = ["d": 2_592_000, "h": 108_000, "m": 1800, "s": 30, "f": 1]
    var total = 0
    var seen = false
    for token in s.split(whereSeparator: { $0.isWhitespace }) {
      guard let unit = token.last, let m = mult[unit], let v = Int(token.dropLast()) else { return nil }
      total += v * m
      seen = true
    }
    return seen ? total : nil
  }

  /// h:mm:ss.cc (with a leading "−" for negative values).
  static func clockString(_ seconds: Double) -> String {
    let neg = seconds < 0
    let cs = Int((abs(seconds) * 100).rounded(.down))
    let h = cs / 360_000, m = (cs / 6000) % 60, s = (cs / 100) % 60, c = cs % 100
    return (neg ? "−" : "") + String(format: "%d:%02d:%02d.%02d", h, m, s, c)
  }
}
