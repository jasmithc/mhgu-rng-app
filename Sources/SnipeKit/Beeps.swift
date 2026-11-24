import AVFoundation
import Foundation

/// The beep sounds, generated as sine tones so they start with very low latency.
enum Beep: CaseIterable {
  case beat        // metronome beat
  case beatFinal   // metronome reached its target
  case tick        // countdown: last 10 seconds
  case finalMain   // countdown reached zero

  var frequency: Double {
    switch self {
    case .beat: return 880
    case .beatFinal: return 1320
    case .tick: return 1000
    case .finalMain: return 1760
    }
  }
  var duration: Double {
    switch self {
    case .beat, .tick: return 0.06
    case .beatFinal: return 0.35
    case .finalMain: return 0.6
    }
  }
  var volume: Float {
    switch self {
    case .beat, .tick: return 0.45
    case .beatFinal, .finalMain: return 0.7
    }
  }
}

final class SoundPlayer: @unchecked Sendable {
  static let shared = SoundPlayer()

  private let engine = AVAudioEngine()
  private var players: [Beep: AVAudioPlayerNode] = [:]
  private var buffers: [Beep: AVAudioPCMBuffer] = [:]
  private let lock = NSLock()
  private var started = false

  private init() {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    for beep in Beep.allCases {
      let node = AVAudioPlayerNode()
      engine.attach(node)
      engine.connect(node, to: engine.mainMixerNode, format: format)
      players[beep] = node
      buffers[beep] = SoundPlayer.tone(beep, format: format)
    }
  }

  private static func tone(_ beep: Beep, format: AVAudioFormat) -> AVAudioPCMBuffer {
    let sr = format.sampleRate
    let n = AVAudioFrameCount(sr * beep.duration)
    let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
    buf.frameLength = n
    let data = buf.floatChannelData![0]
    let fade = Int(sr * 0.004)  // 4 ms fade in/out to avoid clicks
    for i in 0..<Int(n) {
      var env: Float = 1
      if i < fade { env = Float(i) / Float(fade) }
      if i > Int(n) - fade { env = Float(Int(n) - i) / Float(fade) }
      data[i] = beep.volume * env * Float(sin(2 * Double.pi * beep.frequency * Double(i) / sr))
    }
    return buf
  }

  /// Start the audio engine ahead of time so the first beep isn't delayed.
  func prepare() {
    lock.lock(); defer { lock.unlock() }
    guard !started || !engine.isRunning else { return }
    #if os(iOS)
    // Play even with the silent switch on, alongside any other audio.
    try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    #endif
    engine.prepare()
    do {
      try engine.start()
      for p in players.values { p.play() }
      started = true
    } catch {
      started = false
    }
  }

  func play(_ beep: Beep) {
    prepare()
    guard let node = players[beep], let buf = buffers[beep] else { return }
    node.scheduleBuffer(buf, at: nil, options: .interrupts)
    if !node.isPlaying { node.play() }
  }
}

/// Fires a list of beeps at exact instants on a high-priority queue. Each event re-arms a
/// one-shot timer for the next deadline, so there is no drift over long waits.
final class BeepScheduler: @unchecked Sendable {
  struct Event {
    let at: ContinuousClock.Instant
    let beep: Beep
  }

  private let queue = DispatchQueue(label: "beep-scheduler", qos: .userInteractive)
  private var timer: DispatchSourceTimer?
  private var events: [Event] = []
  private var index = 0
  private var generation = 0
  private var onFinish: (@Sendable () -> Void)?

  func start(_ events: [Event], onFinish: @escaping @Sendable () -> Void) {
    SoundPlayer.shared.prepare()
    queue.async {
      self.generation += 1
      self.timer?.cancel(); self.timer = nil
      self.events = events.sorted { $0.at < $1.at }
      self.index = 0
      self.onFinish = onFinish
      self.armNext(self.generation)
    }
  }

  func cancel() {
    queue.async {
      self.generation += 1
      self.timer?.cancel(); self.timer = nil
      self.events = []
      self.onFinish = nil
    }
  }

  private func armNext(_ gen: Int) {
    guard gen == generation else { return }
    let clock = ContinuousClock()
    // Fire exactly on time. Any constant output delay is absorbed by the user's correction offset.
    let early = Duration.zero
    while index < events.count && clock.now >= events[index].at - early {
      SoundPlayer.shared.play(events[index].beep)
      index += 1
    }
    guard index < events.count else {
      timer?.cancel(); timer = nil
      if let f = onFinish { onFinish = nil; DispatchQueue.main.async(execute: f) }
      return
    }
    let delta = (events[index].at - early) - clock.now
    let ns = max(0, Int(delta.components.seconds) * 1_000_000_000 + Int(delta.components.attoseconds / 1_000_000_000))
    let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
    t.schedule(deadline: .now() + .nanoseconds(ns), leeway: .nanoseconds(0))
    t.setEventHandler { [weak self] in self?.armNext(gen) }
    timer?.cancel()
    timer = t
    t.resume()
  }
}

extension Duration {
  var seconds: Double {
    Double(components.seconds) + Double(components.attoseconds) / 1e18
  }
}
