// Extra checks for item-combination results, run after the exact `searchCombo`:
//
// 1. Reliability: how likely a random frame is to match the sequence, so a short sequence
//    over a large range is flagged as a possible coincidence.
// 2. Frame stutters: holding Combine normally gives one combination every 5 frames, but the
//    rhythm can slip by a frame or two (seen in real recordings near the start of combining).
//    If there is no exact match, look for one where the combinations before some point ran
//    1-2 frames early or late, with the steady 5-frame rhythm after it.
//
// The frame reported for a stutter match is anchored on the part after the stutter, which is
// what the RNG continues from, and still counts every combination you entered.

/// A parsed item-combination sequence, using the same rules as `searchCombo`.
struct ComboSequence {
  let raw: [Int]
  /// Gaps between values 4, 5, 6… (the first three values and a trailing 99 are not used).
  let gaps: [Int]

  init?(_ text: String) {
    var raw: [Int] = []
    for p in text.split(whereSeparator: { $0.isWhitespace }) {
      guard let v = Int(p) else { return nil }
      raw.append(v)
    }
    var pos = Array(raw.dropFirst(3))
    if pos.last == 99 { pos.removeLast() }
    guard pos.count > 1 else { return nil }
    let gaps = (0..<(pos.count - 1)).map { pos[$0 + 1] - pos[$0] }
    guard gaps.allSatisfy({ (2...4).contains($0) }) else { return nil }
    self.raw = raw
    self.gaps = gaps
  }

  /// Probability that a random RNG position gives exactly these gaps.
  /// Gap 2 and gap 4 each have a 25% chance, gap 3 has 50%.
  var matchProbability: Double {
    gaps.reduce(1.0) { $0 * ($1 == 3 ? 0.5 : 0.25) }
  }

  /// Result frame for a match whose first used gap is at stride index `i0` (as in searchCombo).
  func frame(start: Int, i0: Int) -> Int { start + i0 - 5 * 3 - 15 + 2 * (raw.count - 1) }
}

/// A match found by `checkCombo`.
public struct ComboMatch: Equatable, Sendable {
  public let frame: Int
  /// 0 for an exact match; otherwise how many frames early (negative) or late (positive)
  /// the combinations before the stutter came, relative to the rhythm after it.
  public let shift: Int
  /// 1-based position, in the values you entered, of the first value after the stutter.
  public let steadyFromValue: Int
}

extension Engine {
  /// Runs the reliability and stutter checks for a combination sequence and prints the
  /// findings. Call after `searchCombo` with the same arguments. Returns the matches it
  /// reports (exact matches, or stutter matches when there are no exact ones).
  @discardableResult
  public mutating func checkCombo(start: Int, step: Int, combo: String, maxShift: Int = 2) throws -> [ComboMatch] {
    guard let seq = ComboSequence(combo), step > 0 else { return [] }
    let n = seq.gaps.count
    let gaps = seq.gaps.map { UInt8($0) }

    // Combination gap given by the RNG at each frame of the search range (plus room for the
    // sequence and early shifts).
    jump(start)
    for _ in 0..<7 { descend() }
    var lut = [UInt8](repeating: 4, count: 100)
    for i in 0..<25 { lut[i] = 2 }
    for i in 25..<75 { lut[i] = 3 }
    let total = step + 5 * n + maxShift + 1
    var v = [UInt8](repeating: 0, count: total)
    for f in 0..<total {
      if f & Engine.cancelCheckMask == 0 { try Task.checkCancellation() }
      v[f] = lut[Int((w & 0xFFFF) % 100)]
      ascend()
    }

    let p = seq.matchProbability
    var exact: [ComboMatch] = []
    var stutter: [ComboMatch] = []
    for i0 in 0..<step {
      if i0 & Engine.cancelCheckMask == 0 { try Task.checkCancellation() }
      // Scan from the end: the steady part must match exactly at i0 + 5k.
      var k = n - 1
      while k >= 0 && v[i0 + 5 * k] == gaps[k] { k -= 1 }
      if k < 0 {
        exact.append(ComboMatch(frame: seq.frame(start: start, i0: i0), shift: 0, steadyFromValue: 4))
        continue
      }
      // Gaps 0...k didn't fit the steady rhythm: try them shifted by a frame or two.
      let s = k + 1
      guard s < n else { continue }   // need at least one steady gap after the stutter
      for d in [-1, 1, -2, 2] where abs(d) <= maxShift {
        guard i0 + d >= 0 else { continue }
        if (0..<s).allSatisfy({ v[i0 + 5 * $0 + d] == gaps[$0] }) {
          stutter.append(ComboMatch(frame: seq.frame(start: start, i0: i0), shift: d, steadyFromValue: s + 5))
          break
        }
      }
    }

    out.print()
    if !exact.isEmpty {
      reportOdds(p: p, range: step, variants: 1)
      return exact
    }
    out.print("No exact match. Checking for a frame stutter (the combining rhythm slipping by up to \(maxShift) frame\(maxShift == 1 ? "" : "s"))…")
    if stutter.isEmpty {
      out.print("No match with a stutter either. Check the values against your recording, or try a different search range.")
      return []
    }
    for m in stutter {
      let value = seq.raw[m.steadyFromValue - 1]
      let when = m.shift < 0 ? "early" : "late"
      out.print("found! frame is… \(m.frame)")
      watch(m.frame)
      out.print("  stutter: the combinations before value #\(m.steadyFromValue) (\(value)) came \(abs(m.shift)) frame\(abs(m.shift) == 1 ? "" : "s") \(when); the rest kept the steady rhythm")
    }
    // A stutter can sit between any two gaps and shift either way, which multiplies the chances.
    reportOdds(p: p, range: step, variants: n * 2 * maxShift)
    return stutter
  }

  /// Prints how unusual the sequence is and warns if a chance match is likely in this range.
  mutating func reportOdds(p: Double, range: Int, variants: Int) {
    let expected = p * Double(range) * Double(variants)
    out.print("Reliability: a random frame matches this sequence about 1 in \(Engine.bigNumber(1 / p)); expected chance matches in \(Engine.grouped(range)) frames: \(Engine.twoDecimals(expected)).")
    if expected >= 0.05 {
      out.write("Warning:", tint: .marker)
      out.print(" a match this short could be a coincidence. Enter more combination values, or search a narrower range around where you expect to be.")
    }
  }

  static func grouped(_ n: Int) -> String {
    let s = String(abs(n))
    var out = ""
    for (i, c) in s.enumerated() {
      if i > 0 && (s.count - i) % 3 == 0 { out.append(",") }
      out.append(c)
    }
    return (n < 0 ? "-" : "") + out
  }

  static func bigNumber(_ x: Double) -> String {
    x < 9e15 ? grouped(Int(x.rounded())) : "more than 9 quadrillion"
  }

  static func twoDecimals(_ x: Double) -> String {
    if x >= 1e6 { return grouped(Int(x.rounded())) }
    let cents = Int((x * 100).rounded())
    let frac = cents % 100
    return "\(grouped(cents / 100)).\(frac < 10 ? "0" : "")\(frac)"
  }
}
