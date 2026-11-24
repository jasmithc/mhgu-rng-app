// Cross-platform tests for RNGCore. Run with `swift test` on macOS, Linux or Windows.
// Expected values come from the original mhxx-rng README examples, and from
// tools/compare.py runs against the Python notebook.
import XCTest
@testable import RNGCore

final class RNGCoreTests: XCTestCase {
  // Global skill IDs (index into the skill-name tables).
  let expert = 69, tenderizer = 70, chainCrit = 71, crisis = 100, recLevel = 116

  func engine(_ kind: CharmKind = .enduring, _ out: Output) -> Engine {
    var o = Options()
    o.language = .en
    return Engine(kind: kind, options: o, out: out)
  }

  // MARK: Searches (README examples)

  func testSearchFindsReadmeCharms() throws {
    let cases: [(Int, Int, Int, Int, Int, Int, Int)] = [
      // skill1, pts1, skill2, pts2, slots, search length, expected frame
      (chainCrit, 4, tenderizer, 5, 3, 10_000, 4723),
      (crisis, 4, recLevel, 2, 0, 10_000, 1725),
      (tenderizer, 6, expert, 10, 3, 300_000, 296_260),
    ]
    for (s1, p1, s2, p2, slots, count, frame) in cases {
      let out = Output()
      var e = engine(.enduring, out)
      let p = try e.parameter(skill1: s1, points1: p1, skill2: s2, points2: p2, slots: slots, origin: .melding)
      try e.search(start: 0, step: count, p)
      XCTAssertTrue(out.foundFrames.contains(frame), "expected frame \(frame), got \(out.foundFrames)")
    }
  }

  func testAroundShowsCharmAtFrame() {
    let out = Output()
    var e = engine(.enduring, out)
    e.around(frame: 4723, num: 1, origin: .melding)
    let zeroLine = out.plainText.split(separator: "\n").first { $0.hasPrefix("   0") }
    XCTAssertNotNil(zeroLine)
    XCTAssertTrue(zeroLine!.contains("Chain Crit"))
    XCTAssertTrue(zeroLine!.contains("Tenderizer"))
    XCTAssertTrue(zeroLine!.contains("S3"))
  }

  func testComboSearch() throws {
    let out = Output()
    var e = engine(.enduring, out)
    let combo = """
      00 03 06 09 11 13 16 18 21 23 25 27 30
      32 35 38 41 44 47 50 52 55 58 61 65 69
      72 75 78 81 85 88 91 93 97 99
      """
    try e.searchCombo(start: 0, step: 1_000_000, combo: combo)
    XCTAssertTrue(out.plainText.contains("found! frame is… 1741"), out.plainText)
  }

  // MARK: RNG jump

  /// jump(n) uses polynomial arithmetic; it must agree with stepping the RNG one frame at a time.
  func testJumpMatchesStepping() {
    for n in [0, 1, 7, 1000, 123_457] {
      var a = engine(.enduring, Output()), b = engine(.enduring, Output())
      a.jump(n)
      a.roll()
      b.jump(n + 1)
      XCTAssertEqual([a.x, a.y, a.z, a.w], [b.x, b.y, b.z, b.w], "state at frame \(n + 1)")
      XCTAssertEqual([a.r0, a.r1, a.r2, a.r3, a.r4, a.r5, a.r6], [b.r0, b.r1, b.r2, b.r3, b.r4, b.r5, b.r6])
      XCTAssertEqual(a.f, b.f)
    }
  }

  func testNegativeJumpStepsBackwards() {
    var a = engine(.enduring, Output()), b = engine(.enduring, Output())
    a.jump(-5)
    for _ in 0..<5 { a.roll() }
    b.jump(0)
    XCTAssertEqual([a.x, a.y, a.z, a.w], [b.x, b.y, b.z, b.w])
    XCTAssertEqual(a.f, b.f)
  }

  // MARK: Wait time and timer maths

  func testFrameTime() {
    XCTAssertEqual(frameTime(4723 - 1717), "0d 0h 1m 40s 6f")
    XCTAssertEqual(frameTime(296_260 - 4723), "0d 2h 41m 57s 27f")
  }

  func testParseWaitTime() {
    XCTAssertEqual(SnipeMath.parseWaitTime("0d 2h 41m 57s 27f"), 296_260 - 4723)
    XCTAssertEqual(SnipeMath.parseWaitTime(frameTime(123_456_789)), 123_456_789)
    XCTAssertEqual(SnipeMath.parseWaitTime("4723"), 4723)
    XCTAssertEqual(SnipeMath.parseWaitTime("1m 30f"), 1830)
    XCTAssertNil(SnipeMath.parseWaitTime(""))
    XCTAssertNil(SnipeMath.parseWaitTime("abc"))
  }

  func testClockString() {
    XCTAssertEqual(SnipeMath.clockString(0), "0:00:00.00")
    XCTAssertEqual(SnipeMath.clockString(156.5), "0:02:36.50")
    XCTAssertEqual(SnipeMath.clockString(3725.25), "1:02:05.25")
    XCTAssertEqual(SnipeMath.clockString(-0.9), "−0:00:00.90")
  }

  func testContinueCalc() {
    let c = ContinueCalc(target: 296_260)
    XCTAssertEqual(c.advancesWithSpare, (296_260 - 3600) / 702.0, accuracy: 1e-9)
    XCTAssertEqual(c.framesAdvanced, c.advancesWithSpare * 30, accuracy: 1e-9)
    XCTAssertEqual(c.neededWhole, 399)
    XCTAssertEqual(ContinueCalc(target: 296_260, poogie: true).neededWhole, 394)
    XCTAssertEqual(ContinueCalc(target: 101_840).advancesWithSpare, 139.94, accuracy: 0.005)
    XCTAssertEqual(ContinueCalc(target: 3000).neededWhole, 0)
  }

  func testCountdown() {
    // 0d 0h 2m 37s 13f wait, 10 s on the stopwatch, −27 frames correction.
    XCTAssertEqual(countdownSeconds(waitFrames: 4723, stopwatchSeconds: 10, correctionSeconds: -27 / 30.0),
                   4723 / 30.0 - 10 - 0.9, accuracy: 1e-9)
  }
}
