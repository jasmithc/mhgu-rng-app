// Snipe-timer beeps: sine tones played through waveOut, fired at exact instants by a
// high-priority thread. winmm.dll is loaded at run time so the app doesn't depend on which
// multimedia headers the Swift WinSDK module exposes.
import WinSDK
#if canImport(ucrt)
import ucrt
#endif

enum Beep: Int, CaseIterable {
  case beat        // metronome beat
  case beatFinal   // metronome reached its target
  case tick        // countdown: last 10 seconds
  case finalMain   // countdown reached zero

  var frequency: Double { [880, 1320, 1000, 1760][rawValue] }
  var duration: Double { [0.06, 0.35, 0.06, 0.6][rawValue] }
  var volume: Double { [0.45, 0.7, 0.45, 0.7][rawValue] }
}

/// Which timer a beep belongs to. Each channel has its own output stream, so the counter and
/// the countdown can beep at the same moment.
enum BeepChannel: Int { case counter = 0, countdown = 1 }

/// Plays prepared tones on two waveOut streams (one per channel).
final class SoundPlayer {
  private typealias OpenFn = @convention(c) (UnsafeMutablePointer<UnsafeMutableRawPointer?>?, UINT,
                                             UnsafeRawPointer?, UInt, UInt, DWORD) -> UINT
  private typealias HeaderFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UINT) -> UINT

  private var prepareHeader: HeaderFn?
  private var write: HeaderFn?
  private var devices: [UnsafeMutableRawPointer?] = [nil, nil]
  /// WAVEHDR blocks, per channel: one per beep plus one of silence (index 4).
  private var headers: [[UnsafeMutableRawPointer]] = [[], []]
  private static let sampleRate = 44_100
  private static let headerSize = 48   // sizeof(WAVEHDR) on 64-bit Windows

  init() {
    guard let dll = withWide("winmm.dll", { LoadLibraryW($0) }),
          let open = GetProcAddress(dll, "waveOutOpen"),
          let prep = GetProcAddress(dll, "waveOutPrepareHeader"),
          let wr = GetProcAddress(dll, "waveOutWrite") else { return }
    let openFn = unsafeBitCast(open, to: OpenFn.self)
    prepareHeader = unsafeBitCast(prep, to: HeaderFn.self)
    write = unsafeBitCast(wr, to: HeaderFn.self)
    if let period = GetProcAddress(dll, "timeBeginPeriod") {
      // 1 ms timer resolution so the scheduler wakes on time.
      typealias PeriodFn = @convention(c) (UINT) -> UINT
      _ = unsafeBitCast(period, to: PeriodFn.self)(1)
    }

    // WAVEFORMATEX: 16-bit mono PCM.
    let fmt = UnsafeMutableRawPointer.allocate(byteCount: 20, alignment: 4)
    defer { fmt.deallocate() }
    fmt.initializeMemory(as: UInt8.self, repeating: 0, count: 20)
    fmt.storeBytes(of: UInt16(1), toByteOffset: 0, as: UInt16.self)                       // WAVE_FORMAT_PCM
    fmt.storeBytes(of: UInt16(1), toByteOffset: 2, as: UInt16.self)                       // channels
    fmt.storeBytes(of: UInt32(Self.sampleRate), toByteOffset: 4, as: UInt32.self)         // samples/s
    fmt.storeBytes(of: UInt32(Self.sampleRate * 2), toByteOffset: 8, as: UInt32.self)     // bytes/s
    fmt.storeBytes(of: UInt16(2), toByteOffset: 12, as: UInt16.self)                      // block align
    fmt.storeBytes(of: UInt16(16), toByteOffset: 14, as: UInt16.self)                     // bits/sample

    for ch in 0..<2 {
      var dev: UnsafeMutableRawPointer?
      let WAVE_MAPPER = UINT.max
      guard openFn(&dev, WAVE_MAPPER, UnsafeRawPointer(fmt), 0, 0, 0) == 0, let dev else { continue }
      devices[ch] = dev
      var hs: [UnsafeMutableRawPointer] = []
      for i in 0...Beep.allCases.count {
        let samples = i < Beep.allCases.count ? Self.tone(Beep(rawValue: i)!) : [Int16](repeating: 0, count: Self.sampleRate / 10)
        let data = UnsafeMutablePointer<Int16>.allocate(capacity: samples.count)
        data.initialize(from: samples, count: samples.count)
        let h = UnsafeMutableRawPointer.allocate(byteCount: Self.headerSize, alignment: 8)
        h.initializeMemory(as: UInt8.self, repeating: 0, count: Self.headerSize)
        h.storeBytes(of: UnsafeMutableRawPointer(data), toByteOffset: 0, as: UnsafeMutableRawPointer.self)
        h.storeBytes(of: UInt32(samples.count * 2), toByteOffset: 8, as: UInt32.self)
        _ = prepareHeader?(dev, h, UINT(Self.headerSize))
        hs.append(h)
      }
      headers[ch] = hs
    }
  }

  private static func tone(_ beep: Beep) -> [Int16] {
    let sr = Double(sampleRate)
    let n = Int(sr * beep.duration)
    let fade = Int(sr * 0.004)   // 4 ms fade in/out to avoid clicks
    return (0..<n).map { i in
      var env = 1.0
      if i < fade { env = Double(i) / Double(fade) }
      if i > n - fade { env = Double(n - i) / Double(fade) }
      let v = beep.volume * env * sin(2 * Double.pi * beep.frequency * Double(i) / sr)
      return Int16(max(-1, min(1, v)) * 32_000)
    }
  }

  func play(_ beep: Beep, on channel: BeepChannel) {
    guard let dev = devices[channel.rawValue], headers[channel.rawValue].count > beep.rawValue else { return }
    _ = write?(dev, headers[channel.rawValue][beep.rawValue], UINT(Self.headerSize))
  }

  /// Play a short silence so the output stream is running before the first real beep.
  func warmUp(_ channel: BeepChannel) {
    guard let dev = devices[channel.rawValue], let h = headers[channel.rawValue].last else { return }
    _ = write?(dev, h, UINT(Self.headerSize))
  }
}

/// Fires beeps at exact instants (seconds on `now()`) on a time-critical thread: it sleeps until
/// about 2 ms before each deadline, then spins, so there's no drift over long waits.
final class BeepScheduler {
  struct Event { let at: Double; let beep: Beep; let channel: BeepChannel }

  static let shared = BeepScheduler()
  /// Posted to `notifyWindow` when a channel's last beep has played: wParam = channel, lParam = generation.
  static let doneMessage = WM.app + 2

  let player = SoundPlayer()
  var notifyWindow: Int = 0   // HWND as an integer, read from the scheduler thread

  private let lock: UnsafeMutablePointer<SRWLOCK>
  private let wake: HANDLE?
  private var events: [Event] = []
  private var generations = [0, 0]

  private init() {
    lock = .allocate(capacity: 1)
    lock.initialize(to: SRWLOCK())
    InitializeSRWLock(lock)
    wake = CreateEventW(nil, false, false, nil)
    let thread = CreateThread(nil, 0, { _ in
      BeepScheduler.shared.threadMain()
      return 0
    }, nil, 0, nil)
    if let thread { _ = CloseHandle(thread) }
  }

  /// Replace the channel's beeps; returns the new generation (reported back when they finish).
  @discardableResult
  func start(_ channel: BeepChannel, _ newEvents: [Event]) -> Int {
    player.warmUp(channel)
    AcquireSRWLockExclusive(lock)
    generations[channel.rawValue] += 1
    let gen = generations[channel.rawValue]
    events.removeAll { $0.channel == channel }
    events.append(contentsOf: newEvents)
    events.sort { $0.at < $1.at }
    ReleaseSRWLockExclusive(lock)
    _ = SetEvent(wake)
    return gen
  }

  func cancel(_ channel: BeepChannel) {
    AcquireSRWLockExclusive(lock)
    generations[channel.rawValue] += 1
    events.removeAll { $0.channel == channel }
    ReleaseSRWLockExclusive(lock)
    _ = SetEvent(wake)
  }

  private func threadMain() {
    _ = SetThreadPriority(GetCurrentThread(), 15 /* THREAD_PRIORITY_TIME_CRITICAL */)
    while true {
      AcquireSRWLockExclusive(lock)
      let next = events.first
      ReleaseSRWLockExclusive(lock)
      guard let next else {
        _ = WaitForSingleObject(wake, 0xFFFF_FFFF)
        continue
      }
      let remaining = next.at - now()
      if remaining > 0.002 {
        // Sleep until shortly before the deadline, or until the events change.
        _ = WaitForSingleObject(wake, DWORD(max(1, Int((remaining - 0.002) * 1000))))
        continue
      }
      while now() < next.at {}
      // Fire every event that is due (and still scheduled).
      var done: [(BeepChannel, Int)] = []
      AcquireSRWLockExclusive(lock)
      let t = now()
      while let e = events.first, e.at <= t {
        events.removeFirst()
        player.play(e.beep, on: e.channel)
        if !events.contains(where: { $0.channel == e.channel }) {
          done.append((e.channel, generations[e.channel.rawValue]))
        }
      }
      ReleaseSRWLockExclusive(lock)
      for (ch, gen) in done {
        _ = PostMessageW(HWND(bitPattern: notifyWindow), BeepScheduler.doneMessage, WPARAM(ch.rawValue), LPARAM(gen))
      }
    }
  }
}
