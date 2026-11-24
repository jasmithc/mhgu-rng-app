import Foundation
import RNGCore

// ContinueCalc and the timing maths live in RNGCore (SnipeMath.swift) so other front ends can share them.

enum CorrectionUnit: String, CaseIterable, Identifiable {
  case seconds = "seconds", frames = "frames"
  var id: String { rawValue }
}

@MainActor
final class SnipeTimers: ObservableObject {
  nonisolated static let fps = SnipeMath.fps
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
  /// Continue presses per minute: the counter's beat, and the pace the calculator assumes.
  @Published var bpm: Int {
    didSet {
      // Keep the pace in range (setting it here doesn't re-run didSet).
      let r = SnipeMath.bpmRange
      if !r.contains(bpm) { bpm = min(max(bpm, r.lowerBound), r.upperBound) }
      if Int(paceText.trimmingCharacters(in: .whitespaces)) != bpm { paceText = String(bpm) }
      defaults.set(bpm, forKey: "timer.bpm")
      if !counterRunning { counterTarget = calc.neededWhole }
    }
  }
  /// What's typed in the Pace box. Valid paces apply as you type; anything else waits for
  /// Return, leaving the box, or Start (see `commitPaceText`).
  @Published var paceText: String = ""

  func paceTextChanged() {
    if let v = Int(paceText.trimmingCharacters(in: .whitespaces)), SnipeMath.bpmRange.contains(v), v != bpm { bpm = v }
  }

  /// Apply whatever is in the Pace box (kept within range), then show the pace in use.
  func commitPaceText() {
    if let v = Int(paceText.trimmingCharacters(in: .whitespaces)) { bpm = v }
    paceText = String(bpm)
  }

  var calc: ContinueCalc { ContinueCalc(target: calcTarget, poogie: poogie, bpm: Double(bpm)) }

  // MARK: Continue counter (metronome at `bpm`)
  @Published var counterTarget: Int
  @Published private(set) var counterStart: ContinuousClock.Instant?
  /// The pace the running counter was started with: the count and the beeps both use it.
  private(set) var counterBpm: Int = Int(SnipeMath.bpm)
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
    let savedBpm = defaults.object(forKey: "timer.bpm") as? Int ?? Int(SnipeMath.bpm)
    let pace = min(max(savedBpm, SnipeMath.bpmRange.lowerBound), SnipeMath.bpmRange.upperBound)
    bpm = pace
    paceText = String(pace)
    counterTarget = ContinueCalc(target: t, poogie: pg, bpm: Double(pace)).neededWhole
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
    return min(counterTarget, Int((elapsed * Double(counterBpm) / 60).rounded(.down)) + 1)
  }

  func startCounter() {
    commitPaceText()   // a pace still being typed applies before the beat is scheduled
    guard counterTarget > 0 else { return }
    counterBpm = bpm
    let start = clock.now + .milliseconds(150)  // let the audio engine settle before beat 1
    let period = 60 / Double(counterBpm)
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
    return countdownSeconds(waitFrames: f, stopwatchSeconds: swElapsed(at: t), correctionSeconds: correctionSeconds)
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

  static func parseWaitTime(_ text: String) -> Int? { SnipeMath.parseWaitTime(text) }

  /// h:mm:ss.cc (with a leading "−" for negative values).
  static func clockString(_ seconds: Double) -> String { SnipeMath.clockString(seconds) }
}
