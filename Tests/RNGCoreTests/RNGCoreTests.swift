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

  // MARK: Combo reliability and stutter check

  /// A real recording: the 4th value really was 07, but the combinations up to value #5
  /// came one frame early, so there's no exact match. The stutter check finds frame 98781.
  let recordedCombo = "00 02 04 07 10 14 17 20 23 26 29 32 35 38 40 43 45 48 50 54 57 60 63 66 69 72 75 78 82 86 88 92 95 98 99"

  func testComboStutterFindsRecordedPosition() throws {
    let out = Output()
    var e = engine(.enduring, out)
    try e.searchCombo(start: 0, step: 200_000, combo: recordedCombo)
    XCTAssertTrue(out.plainText.contains("no results found"))
    let matches = try e.checkCombo(start: 0, step: 200_000, combo: recordedCombo)
    XCTAssertEqual(matches, [ComboMatch(frame: 98_781, shift: -1, steadyFromValue: 6)])
    XCTAssertTrue(out.plainText.contains("came 1 frame early"), out.plainText)
    XCTAssertFalse(out.plainText.contains("Warning"), out.plainText)
  }

  func testComboWarnsWhenAChanceMatchIsLikely() throws {
    // The first 22 values match frame 5131615 purely by chance.
    let short = "00 02 04 07 10 14 17 20 23 26 29 32 35 38 40 43 45 48 50 54 57 60"
    let out = Output()
    var e = engine(.enduring, out)
    let matches = try e.checkCombo(start: 4_500_000, step: 1_000_000, combo: short)
    XCTAssertEqual(matches.map(\.frame), [5_131_615])
    XCTAssertEqual(matches.first?.shift, 0)
    XCTAssertTrue(out.plainText.contains("1 in 8,388,608"), out.plainText)
    XCTAssertTrue(out.plainText.contains("Warning"), out.plainText)
  }

  func testComboExactMatchIsReportedAsReliable() throws {
    let out = Output()
    var e = engine(.enduring, out)
    let combo = "00 03 06 09 11 13 16 18 21 23 25 27 30 32 35 38 41 44 47 50 52 55 58 61 65 69 72 75 78 81 85 88 91 93 97 99"
    let matches = try e.checkCombo(start: 0, step: 100_000, combo: combo)
    XCTAssertEqual(matches, [ComboMatch(frame: 1741, shift: 0, steadyFromValue: 4)])
    XCTAssertTrue(out.plainText.contains("Reliability"))
    XCTAssertFalse(out.plainText.contains("Warning"))
  }

  func testNumberFormatting() {
    XCTAssertEqual(Engine.grouped(10_000_000), "10,000,000")
    XCTAssertEqual(Engine.grouped(999), "999")
    XCTAssertEqual(Engine.twoDecimals(1.192), "1.19")
    XCTAssertEqual(Engine.twoDecimals(0.004), "0.00")
  }

  // MARK: Charm presets

  func testEveryPresetCanExist() {
    for group in CharmPresets.groups {
      XCTAssertFalse(group.presets.isEmpty, group.name)
      for p in group.presets {
        let t = charmKindTables[p.kind.rawValue]
        XCTAssertTrue(t.canRoll(skill1: p.skill1, points1: p.points1, skill2: p.skill2, points2: p.points2, slots: p.slots),
                      "\(group.name): \(p.label(languageTables[.en]!)) can't exist")
      }
    }
  }

  func testPresetLabelsAndElements() {
    let en = languageTables[.en]!
    let general = CharmPresets.groups.first { $0.name == "General Blademaster" }!
    XCTAssertEqual(general.presets.first?.label(en), "Tenderizer +6 / Expert +10 ◯◯◯")
    let sns = CharmPresets.groups.first { $0.name == "Sword & Shield / Dual Blades" }!.presets.map { $0.label(en) }
    for element in ["Fire Atk", "Water Atk", "Thunder Atk", "Ice Atk", "Dragon Atk"] {
      XCTAssertTrue(sns.contains("Elemental +7 / \(element) +13 ◯◯◯"), element)
    }
    XCTAssertEqual(CharmPresets.groups.filter { $0.section == .blademaster }.reduce(0) { $0 + $1.presets.count }, 101)
    XCTAssertEqual(CharmPresets.groups.filter { $0.section == .gunner }.reduce(0) { $0 + $1.presets.count }, 44)
    let bow = CharmPresets.groups.first { $0.name == "Bow" }!.presets.map { $0.label(en) }
    XCTAssertTrue(bow.contains("Expert +4 / Power C+ +12 ◯ (Shining Charm)"))
    XCTAssertTrue(bow.contains("Expert +3 / Power C+ +11 ◯◯ (Shining Charm)"))
  }

  func testCanRollRejectsImpossibleCharms() {
    let t = charmKindTables[CharmKind.enduring.rawValue]
    XCTAssertTrue(t.canRoll(skill1: tenderizer, points1: 6, skill2: expert, points2: 10, slots: 3))
    XCTAssertFalse(t.canRoll(skill1: tenderizer, points1: 7, skill2: expert, points2: 10, slots: 3))  // over max
    XCTAssertFalse(t.canRoll(skill1: tenderizer, points1: 6, skill2: expert, points2: 11, slots: 3))
    XCTAssertFalse(t.canRoll(skill1: tenderizer, points1: 6, skill2: tenderizer, points2: 5, slots: 3)) // same skill
    XCTAssertFalse(t.canRoll(skill1: tenderizer, points1: 1, skill2: expert, points2: 1, slots: 3))  // below Tenderizer's minimum of 2
    // Slot limits: a low-point Mystery charm (Paralysis +1 / Poison +1) can have 1 slot but not 2.
    let mystery = charmKindTables[CharmKind.mystery.rawValue]
    XCTAssertTrue(mystery.canRoll(skill1: 1, points1: 1, skill2: 0, points2: 1, slots: 1))
    XCTAssertFalse(mystery.canRoll(skill1: 1, points1: 1, skill2: 0, points2: 1, slots: 2))
  }

  // MARK: Can the charm exist?

  func reason(_ kind: CharmKind, _ a: Int?, _ pa: Int, _ b: Int?, _ pb: Int, slots: Int,
              origin: Origin = .melding, atLeast: Bool = false) -> String? {
    charmKindTables[kind.rawValue].impossibleReason(skill1: a, points1: pa, skill2: b, points2: pb, slots: slots,
                                                    origin: origin, atLeast: atLeast, lang: languageTables[.en]!)
  }

  func testPossibleCharmsPass() {
    XCTAssertNil(reason(.enduring, tenderizer, 6, expert, 10, slots: 3))
    XCTAssertNil(reason(.enduring, crisis, 4, recLevel, 2, slots: 0))
    XCTAssertNil(reason(.enduring, chainCrit, 4, nil, 0, slots: 3))
    XCTAssertNil(reason(.enduring, tenderizer, 6, expert, -3, slots: 0, origin: .quest))  // quests can give negative points
    XCTAssertNil(reason(.enduring, tenderizer, 6, expert, 10, slots: 3, atLeast: true))
    XCTAssertNil(reason(.enduring, nil, 0, expert, 10, slots: 3, atLeast: true))
  }

  func testImpossibleCharmsExplainWhy() {
    XCTAssertEqual(reason(.enduring, tenderizer, 7, expert, 10, slots: 3),
                   "On Enduring Charms, Tenderizer in slot 1 ranges from +2 to +6.")
    XCTAssertEqual(reason(.enduring, expert, 10, tenderizer, 5, slots: 3),
                   "Expert can't be the first skill on Enduring Charms.")
    XCTAssertEqual(reason(.enduring, tenderizer, 6, expert, 11, slots: 3),
                   "On Enduring Charms from melding, Expert in slot 2 ranges from +1 to +10.")
    XCTAssertEqual(reason(.enduring, tenderizer, 6, expert, -3, slots: 0),
                   "On Enduring Charms from melding, Expert in slot 2 ranges from +1 to +10.")
    XCTAssertEqual(reason(.enduring, tenderizer, 7, nil, 0, slots: 0, atLeast: true),
                   "On Enduring Charms, Tenderizer in slot 1 ranges from +2 to +6.")
  }

  func testSlotLimits() {
    // Paralysis (1) / Poison (0) on Mystery charms.
    XCTAssertEqual(reason(.mystery, 1, 1, 0, 1, slots: 2),
                   "Mystery Charms like this can have 0 or 1 slots with these points, not 2.")
    // More points can mean fewer slots on Mystery charms, so "at least" checks every total.
    XCTAssertNil(reason(.mystery, 1, 1, 0, 1, slots: 1, atLeast: true))
    XCTAssertEqual(reason(.mystery, 1, 5, 0, 7, slots: 1, atLeast: true),
                   "Mystery Charms like this can have 0 slots with at least these points, not 1 or more.")
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
