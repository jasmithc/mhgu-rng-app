import Foundation

/// Initial xorshift128 state (`s` in the notebook).
let seedState: (UInt32, UInt32, UInt32, UInt32) = (0x0194FD72, 0x79E6C985, 0x08DD9701, 0x41CFCE91)

/// Port of the RNG state and functions from the mhxx-rng notebook
/// (https://github.com/apmnnn/mhxx-rng, English translation https://github.com/jasmithc/mhgu-rng).
/// Each function writes the same text the notebook prints to `out`.
public struct Engine {
  // xorshift state
  var x: UInt32 = 0, y: UInt32 = 0, z: UInt32 = 0, w: UInt32 = 0
  var f: Int = 0
  // rolling window of the last 7 `w` values
  var r0: UInt32 = 0, r1: UInt32 = 0, r2: UInt32 = 0, r3: UInt32 = 0
  var r4: UInt32 = 0, r5: UInt32 = 0, r6: UInt32 = 0

  public private(set) var tables: CharmTables
  public let lang: LanguageTables
  public var options: Options
  public let out: Output

  public init(kind: CharmKind, options: Options, out: Output) {
    self.tables = charmKindTables[kind.rawValue]
    self.lang = languageTables[options.language]!
    self.options = options
    self.out = out
  }

  var kind: Int { tables.kind }
  var th: UInt32 { UInt32(tables.th) }

  mutating func setKind(_ k: Int) { tables = charmKindTables[k] }

  // MARK: - Core RNG

  mutating func initState() {
    (x, y, z, w) = seedState
    f = 0
  }

  @inline(__always) mutating func ascend() {
    let t = x ^ (x &<< 15)
    x = y; y = z; z = w
    w = w ^ (w >> 21) ^ t ^ (t >> 4)
    f += 1
  }

  @inline(__always) mutating func descend() {
    var t = w ^ z ^ (z >> 21)
    t ^= t >> 4
    t ^= t >> 8
    t ^= t >> 16
    w = z; z = y; y = x
    x = t ^ (t &<< 15) ^ (t &<< 30)
    f -= 1
  }

  @inline(__always) mutating func roll() {
    r0 = r1; r1 = r2; r2 = r3; r3 = r4; r4 = r5; r5 = r6; r6 = w
    ascend()
  }

  /// Jump straight to `frame` using x^n mod (characteristic polynomial), then roll 7 times.
  public mutating func jump(_ frame: Int) {
    initState()
    if frame < 0 {
      // A^(2^128-1) is the identity, so a negative frame is just stepping backwards.
      for _ in 0..<(-frame) { descend() }
    } else {
      var rPoly = GF2Poly.powMod(exponent: UInt64(frame))
      var sx: UInt32 = 0, sy: UInt32 = 0, sz: UInt32 = 0, sw: UInt32 = 0
      while !rPoly.isZero {
        if rPoly.lowBit {
          sx ^= x; sy ^= y; sz ^= z; sw ^= w
        }
        rPoly.shiftRight1()
        ascend()
      }
      x = sx; y = sy; z = sz; w = sw
    }
    f = frame
    for _ in 0..<7 { roll() }
  }

  // MARK: - Charm generation

  func slot(_ fill: Int, _ num: Int) -> Int {
    let v = tables.slotValue[fill - 1]
    if num >= v.2 { return 3 }
    if num >= v.1 { return 2 }
    if num >= v.0 { return 1 }
    return 0
  }

  func rare(_ slot: Int, _ fill: Int) -> Int {
    let n = slot * 2 + fill
    switch kind {
    case 0: return n >= 13 ? 10 : n >= 8 ? 9 : 8
    case 1: return n >= 13 ? 7 : n >= 8 ? 6 : 5
    case 2: return n >= 8 ? 4 : 3
    default: return n >= 8 ? 2 : 1
    }
  }

  func getCharm(_ origin: Int) -> Charm {
    let T = tables
    let id1 = Int(r0 % UInt32(T.skill1.count))
    let id2 = Int(r3 % UInt32(T.skill2.count))
    let s1 = T.sp1[id1].1
    let s2 = T.sp2[id2].1
    let c0 = T.skill1[id1]
    let tmp1 = Int(r1 % UInt32(T.sp1[id1].1 - T.sp1[id1].0 + 1)) + T.sp1[id1].0
    var c2 = -1, c3 = 0, tmp2 = 0
    var q5: UInt32
    if r2 % 100 >= th {
      c2 = T.skill2[id2]
      if origin == 1 && r4 % 2 == 0 {
        q5 = r6
        tmp2 = Int(r5 % UInt32(T.sp2[id2].0 + 1)) - T.sp2[id2].0
      } else {
        let q4: UInt32
        if origin == 1 { q4 = r5; q5 = r6 } else { q4 = r4; q5 = r5 }
        tmp2 = Int(q4 % UInt32(T.sp2[id2].1)) + 1
      }
      c3 = tmp2
      if T.skill1[id1] == T.skill2[id2] || tmp2 < 0 { tmp2 = 0 }
    } else {
      q5 = r3
    }
    let tmp0 = (tmp1 * s2 + tmp2 * s1) * 10 / (s1 * s2)
    let roll = Int(q5 % 100)
    let sl = slot(tmp0, roll)
    return Charm(skill1: c0, points1: tmp1, skill2: c2, points2: c3, slots: sl,
                 fill: tmp0, slotRoll: roll, rare: rare(sl, tmp0))
  }

  // MARK: - Printing helpers

  func pr(_ s: String, _ width: String = "2", _ end: String = " ", tint: Tint? = nil) {
    out.write(PyFormat.str(s, width), tint: tint)
    out.write(end)
  }

  func pr(_ v: Int, _ width: String = "2", _ end: String = " ") {
    out.write(PyFormat.int(v, width) + end)
  }

  func charmPush(_ c: Charm) {
    pr(lang.skill[c.skill1], lang.skillWidth)
    pr(c.points1)
    if c.skill2 == -1 {
      pr(lang.noSkill)
    } else {
      pr(lang.skill[c.skill2], lang.skillWidth)
      pr(c.points2, "3")
    }
    pr("S\(c.slots)")
    if options.showRare {
      out.write("RARE\(c.rare)", tint: .rare(c.rare))
      out.write(c.rare < 10 ? "  " : " ")
    }
    out.print()
  }

  func watch(_ frame: Int) { out.print(frameTime(frame)) }

  // MARK: - parameter()

  /// `parameter(str1, num1, str2, num2, num3, str3)` with global skill IDs instead of names.
  /// Pass `nil` for an empty skill name.
  public func parameter(skill1 s1: Int?, points1: Int, skill2 s2: Int?, points2: Int,
                        slots: Int, origin: Origin) throws -> SearchParams {
    var id1 = -1, id2 = -1
    if let s1 {
      guard let i = tables.skill1.firstIndex(of: s1) else {
        throw RNGError("\(lang.skill[s1]) can't be the first skill of this charm kind.")
      }
      id1 = i
    }
    if let s2 {
      guard let i = tables.skill2.firstIndex(of: s2) else {
        throw RNGError("\(lang.skill[s2]) can't be the second skill of this charm kind.")
      }
      id2 = i
    }
    if id1 == -1 && id2 == -1 { id1 = 0 }
    return SearchParams(id1: id1, sp1: points1, id2: id2, sp2: points2, slots: slots,
                        origin: origin.rawValue, len1: tables.skill1.count, len2: tables.skill2.count)
  }

  // MARK: - search / search_greater

  static let cancelCheckMask = (1 << 20) - 1

  public mutating func search(start: Int, step: Int, _ p: SearchParams) throws {
    jump(start)
    let skip2 = p.id2 == -1
    let len1 = UInt32(p.len1), len2 = UInt32(p.len2)
    let id1 = UInt32(truncatingIfNeeded: p.id1), id2 = UInt32(truncatingIfNeeded: p.id2)
    var found = 0
    for i in 0..<max(step, 0) {
      if i & Engine.cancelCheckMask == 0 { try Task.checkCancellation() }
      roll()
      if p.id1 >= 0 && r0 % len1 == id1 && (skip2 || (r2 % 100 >= th && r3 % len2 == id2)) {
        let c = getCharm(p.origin)
        if c.points1 == p.sp1 && c.slots == p.slots {
          let cond = !skip2 ? (c.points2 == p.sp2)
                            : (c.skill2 == -1 || c.skill2 == c.skill1 || c.points2 == 0)
          if cond {
            out.recordFound(f - 7)
            out.print("found!frame is… \(f - 7)")
            watch(f - 7)
            found += 1
            if out.isFull { break }
          }
        }
      }
    }
  }

  public mutating func searchGreater(start: Int, step: Int, _ p: SearchParams) throws {
    jump(start)
    let skip1 = p.id1 == -1
    let skip2 = p.id2 == -1
    let len1 = UInt32(p.len1), len2 = UInt32(p.len2)
    let id1 = UInt32(truncatingIfNeeded: p.id1), id2 = UInt32(truncatingIfNeeded: p.id2)
    var found = 0
    for i in 0..<max(step, 0) {
      if i & Engine.cancelCheckMask == 0 { try Task.checkCancellation() }
      roll()
      if (skip1 || r0 % len1 == id1) && (skip2 || (r2 % 100 >= th && r3 % len2 == id2)) {
        let c = getCharm(p.origin)
        if skip1 && c.skill1 == c.skill2 { continue }
        if (skip1 || c.points1 >= p.sp1) && (skip2 || c.points2 >= p.sp2) && c.slots >= p.slots {
          msg(c, p.origin)
          found += 1
          if out.isFull { break }
        }
      }
    }
  }

  /// `search_fill_slot(start, step, fill, slot, origin)`.
  public mutating func searchFillSlot(start: Int, step: Int, fill: Int, slot sl: Int, origin: Origin) throws {
    guard (1...20).contains(fill) else { throw RNGError("Fill must be between 1 and 20.") }
    guard (1...3).contains(sl) else { throw RNGError("Slots must be between 1 and 3.") }
    let o = origin.rawValue
    jump(start)
    let v = tables.slotValue[fill - 1]
    let arr = [v.0, v.1, v.2]
    let thD = UInt32(arr[sl - 1])
    let thU = UInt32(sl < 3 ? arr[sl] : 100)
    for i in 0..<max(step, 0) {
      if i & Engine.cancelCheckMask == 0 { try Task.checkCancellation() }
      roll()
      let q5 = o == 0 ? r5 : r6
      let m = q5 % 100
      if thD <= m && m < thU {
        let c = getCharm(o)
        if c.slots == sl && c.fill == fill {
          pr(f - 7, "7")
          charmPush(c)
          if out.isFull { break }
        }
      }
    }
  }

  // MARK: - msg() and aim points

  mutating func msg(_ c: Charm, _ origin: Int) {
    out.recordFound(f - 7)
    out.print("found!frame is… \(f - 7)")
    charmPush(c)
    watch(f - 7)
    if origin == 0 {
      switch kind {
      case 0:
        aimpointBlue()
      case 1:
        out.print(lang.melding[0])
        aimpointJuju()
        out.print(lang.melding[1])
        aimpointHalcyon()
      default:
        aimpointHalcyon()
      }
    } else {
      aimpointQuest(options.numOfCharms)
    }
    out.print()
  }

  static func rand(_ seed: Int, _ n: Int) -> Int {
    var v = seed & 0xFFFF
    for _ in 0..<n {
      v = max(v, 1)
      v = v * 176 % 65363
    }
    return v
  }

  mutating func aimpointBlue() {
    var n = 1
    for _ in 0..<9 { descend() }
    if w % 100 < th { n += 1 }
    for _ in 0..<2 { descend() }
    if w % 100 >= th { n += 1 }
    for _ in 0..<11 { ascend() }
    out.print("\(n) aim points exist")
  }

  mutating func aimpointMelding(_ num: Int, _ colors: (Int, Int) -> [Int], _ rank: Int) {
    let e = kind
    var a = [Int](repeating: 0, count: num + 3)
    var b = [Bool](repeating: false, count: num + 3)
    for _ in 0..<7 { descend() }
    for i in 0..<num {
      descend()
      a[i + 3] = Int(w)
    }
    for _ in 0..<(num + 7) { ascend() }
    for i in 0..<num {
      var c = i
      let d = colors(a[i + 3], rank)
      for j in d {
        setKind(j)
        if c == 0 && e == j { b[i] = true }
        if c >= 0 { c -= (a[c] % 100 < tables.th) ? 4 : 6 }
      }
    }
    showAimpoint(b.map { $0 ? 1 : 0 }) { $0 != 0 }
    setKind(e)
  }

  mutating func aimpointHalcyon() {
    let ranks = options.showAllRank ? [4, 3, 2, 1] : [4]
    for r in ranks {
      if options.showAllRank { pr("rank\(r): ") }
      aimpointMelding((6 - 1) * 6 + 1, Engine.halcyonColors, r)
    }
  }

  mutating func aimpointJuju() {
    let ranks = options.showAllRank ? [4, 3, 2, 1] : [4]
    for r in ranks {
      if options.showAllRank { pr("rank\(r): ") }
      aimpointMelding((4 - 1) * 6 + 1, Engine.jujuColors, r)
    }
  }

  mutating func aimpointQuest(_ numIn: Int) {
    let n1 = max(numIn, 2)
    let num = (n1 - 1) * 7 + 1
    var a = [Int](repeating: 0, count: num)
    var b = [Int](repeating: n1 + 1, count: num)
    b[0] = 1
    for _ in 0..<7 { descend() }
    for i in 0..<(num - 3) {
      descend()
      a[i + 3] = Int(w)
    }
    for _ in 0..<(num + 4) { ascend() }
    let t = tables.th
    for i in 0..<num {
      if i + 4 < num && a[i + 4] % 100 < t { b[i + 4] = min(b[i + 4], b[i] + 1) }
      if i + 7 < num && a[i + 7] % 100 >= t { b[i + 7] = min(b[i + 7], b[i] + 1) }
    }
    showAimpoint(b) { $0 <= n1 }
  }

  func showAimpoint(_ array: [Int], _ ok: (Int) -> Bool) {
    out.print("\(array.filter(ok).count) aim points exist", end: "  ")
    for i in stride(from: array.count - 1, through: 0, by: -1) {
      if i % 10 == 0 { pr(" ", "1", "") }
      if i == 0 { pr("[", "1", "") }
      pr(ok(array[i]) ? "◯" : "Ｘ", "1", "")
    }
    out.print("]")
  }

  static func halcyonColors(_ seed: Int, _ rank: Int) -> [Int] {
    var a = 1
    let (width, mn): (Int, Int) = [1: (3, 1), 2: (4, 1), 3: (4, 2), 4: (5, 2)][rank]!
    let num = rand(seed, a) % width + mn
    a += 1
    var b = [Int](repeating: 0, count: num)
    for i in 0..<num {
      while rand(seed, a) % 100 >= 85 { a += 1 }
      let c = rand(seed, a) % 100
      a += 1
      b[i] = c < 10 ? 3 : c < 55 ? 2 : 1
    }
    return b
  }

  static func jujuColors(_ seed: Int, _ rank: Int) -> [Int] {
    let (w1, m1, w2, m2): (Int, Int, Int, Int) =
      [1: (2, 0, 1, 1), 2: (2, 0, 2, 1), 3: (2, 1, 2, 1), 4: (1, 2, 2, 1)][rank]!
    let n1 = rand(seed, 1) % w1 + m1
    let n2 = rand(seed, 2) % w2 + m2
    return [Int](repeating: 0, count: n1) + [Int](repeating: 1, count: n2)
  }

  // MARK: - Listing tools

  /// `halcyonpush` / `jujupush`.
  public mutating func meldingPush(frame: Int, halcyon: Bool, rank: Int = 4) {
    let e = kind
    jump(frame - 1)
    let colors = halcyon ? Engine.halcyonColors(Int(r0), rank) : Engine.jujuColors(Int(r0), rank)
    roll()
    for j in colors {
      setKind(j)
      pr(lang.kinds[kind], lang.kindWidth, "  ")
      charmPush(getCharm(0))
      let b = r2 % 100 < th ? 4 : 6
      for _ in 0..<b { roll() }
    }
    setKind(e)
  }

  /// `sequence_charm(frame, num)`.
  public mutating func sequenceCharm(frame: Int, count: Int) {
    jump(frame)
    for i in 0..<max(count, 0) {
      if i % 10 == 0 { out.print() }
      charmPush(getCharm(1))
      let a = r2 % 100 < th ? 4 : 7
      for _ in 0..<a { roll() }
    }
  }

  /// `around(frame, num, origin)`.
  public mutating func around(frame: Int, num: Int, origin: Origin) {
    let a = origin.rawValue
    jump(frame - num)
    for i in -num..<num {
      if floorMod(i, 10) == 0 { out.print() }
      pr(f - 7 - frame, "4", "  ")
      charmPush(getCharm(a))
      roll()
      if i == -1 {
        out.print("\n")
        pr(0, "4", "  ")
        charmPush(getCharm(a))
        roll()
        out.print()
      }
    }
  }

  /// `allpush(frame, num, showall)`: raw RNG dump.
  public mutating func allPush(frame: Int, count: Int, showAll: Bool) throws {
    jump(frame - 7)
    linePush()
    out.print("jump to… frame \(f)\n\n")
    for i in 0..<max(count, 0) {
      if i & Engine.cancelCheckMask == 0 { try Task.checkCancellation() }
      if floorMod(f, 4) == 0 {
        linePush()
        if showAll {
          let l1 = UInt32(tables.skill1.count), l2 = UInt32(tables.skill2.count)
          push { PyFormat.str(lang.skill[tables.skill1[Int($0 % l1)]], "_>7") }
          push { PyFormat.str(lang.skill[tables.skill2[Int($0 % l2)]], "_>7") }
          push { PyFormat.int(Int($0 % 100), "_>8") }
        }
      }
      if floorMod(f, 40) == 0 { out.print() }
      if floorMod(f, 400) == 0 { out.print("\nframe is \(f)\n\n") }
      if out.isFull { break }
      ascend()
    }
  }

  func push(_ fn: (UInt32) -> String) {
    for v in [x, y, z, w] { out.write(fn(v) + " ") }
    out.print()
  }

  func linePush() { push { PyFormat.int(Int($0), "08x") } }

  // MARK: - Item combination / reward search

  static func kmpPrefix(_ A: [UInt8]) -> [Int] {
    var pi = [Int](repeating: 0, count: A.count)
    var j = 0
    for i in 1..<max(A.count, 1) where A.count > 1 {
      while j > 0 && A[i] != A[j] { j = pi[j - 1] }
      if A[i] == A[j] { j += 1 }
      pi[i] = j
    }
    return pi
  }

  /// `search_stride_nj`: find runs matching `A` in the RNG sequence, sampled every `stride` frames.
  mutating func searchStride(step: Int, _ A: [UInt8], stride: Int, lut: [UInt8]) throws -> [Int] {
    let n = A.count
    var res: [Int] = []
    if n == 0 { return res }
    let pi = Engine.kmpPrefix(A)
    var state = [Int](repeating: 0, count: stride)
    var r = 0
    for i in 0..<max(step, 0) {
      if i & Engine.cancelCheckMask == 0 { try Task.checkCancellation() }
      let v = lut[Int((w & 0xFFFF) % 100)]
      ascend()
      var k = state[r]
      while k > 0 && A[k] != v { k = pi[k - 1] }
      if A[k] == v { k += 1 }
      if k == n {
        res.append(i - stride * (n - 1))
        k = pi[n - 1]
      }
      state[r] = k
      r += 1
      if r == stride { r = 0 }
    }
    return res
  }

  /// `search_combo(start, step, combo_str)`.
  public mutating func searchCombo(start: Int, step: Int, combo: String) throws {
    jump(start)
    for _ in 0..<7 { descend() }
    let parts = combo.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    var raw: [Int] = []
    for p in parts {
      guard let v = Int(p) else { throw RNGError("\"\(p)\" is not a number.") }
      raw.append(v)
    }
    var pos = Array(raw.dropFirst(3))
    if pos.last == 99 { pos.removeLast() }
    if pos.count <= 1 {
      out.print("too short!")
      return
    }
    let dif = (0..<(pos.count - 1)).map { pos[$0 + 1] - pos[$0] }
    let invalid = dif.indices.filter { ![2, 3, 4].contains(dif[$0]) }
    if !invalid.isEmpty {
      out.print("invalid differences!")
      var marks = Set<Int>()
      for idx in invalid { marks.insert(idx + 4) }
      // Insert a marker before the element at index idx + 4 of the original list.
      for (i, p) in parts.enumerated() {
        if i > 0 { out.write(" ") }
        if marks.contains(i) { out.write("●", tint: .marker); out.write(" ") }
        out.write(p)
      }
      if marks.contains(parts.count) { out.write(" "); out.write("●", tint: .marker) }
      out.print()
      return
    }
    var lut = [UInt8](repeating: 4, count: 100)
    for i in 0..<25 { lut[i] = 2 }
    for i in 25..<75 { lut[i] = 3 }
    let hits = try searchStride(step: step, dif.map { UInt8($0) }, stride: 5, lut: lut)
    if hits.isEmpty { out.print("no results found") }
    for i in hits {
      let j = i - 5 * 3 - 15 + 2 * (raw.count - 1)
      out.print("found! frame is… \(start + j)")
      watch(start + j)
    }
  }

  /// `search_reward(start, step, bonus_th, target_str, reward_table)`.
  /// `table` is an ordered list of (item name, cumulative threshold).
  public mutating func searchReward(start: Int, step: Int, bonusTh: Int,
                                    target: String, table: [(String, Int)]) throws {
    jump(start)
    for _ in 0..<7 { descend() }
    let items = target.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    guard (4...8).contains(items.count) else {
      out.print("too short or too long!")
      return
    }
    var index: [String: Int] = [:]
    for (i, (k, _)) in table.enumerated() where index[k] == nil { index[k] = i }
    var A: [UInt8] = []
    for t in items {
      guard let i = index[t] else { throw RNGError("\"\(t)\" is not in the reward table.") }
      A.append(UInt8(i))
    }
    var lut = [UInt8](repeating: 0, count: 100)
    var prev = 0
    for (i, (_, t)) in table.enumerated() {
      let hi = min(max(t, 0), 100)
      if prev < hi { for j in prev..<hi { lut[j] = UInt8(i) } }
      prev = t
    }
    let hits = try searchStride(step: step, A, stride: 1, lut: lut)
    if hits.isEmpty { out.print("no results found") }
    for i in hits {
      jump(start + i - 7 - 1)
      if Engine.checkBonus(items.count, [x, y, z, w], bonusTh) {
        let j = i - min(items.count - 3, 4)
        out.print("found!frame is… \(start + j)")
        watch(start + j)
      }
    }
  }

  static func checkBonus(_ len: Int, _ four: [UInt32], _ bonusTh: Int) -> Bool {
    let flag = four.map { Int($0 & 0x1F) < bonusTh }
    if len == 8 { return flag.allSatisfy { $0 } }
    let k = len - 4
    return !flag[3] && flag[(3 - k)..<3].allSatisfy { $0 }
  }
}

// MARK: - GF(2)[x] arithmetic for jump()

/// Polynomials over GF(2) of degree < 256, stored as 4 little-endian 64-bit words.
struct GF2Poly {
  var w: [UInt64] = [0, 0, 0, 0]

  /// Characteristic polynomial of the xorshift128 transition matrix.
  static let modulus = GF2Poly(w: [0x1442057eea368001, 0x00000201a8362f67, 0x1, 0])

  var isZero: Bool { w[0] == 0 && w[1] == 0 && w[2] == 0 && w[3] == 0 }
  var lowBit: Bool { w[0] & 1 == 1 }

  var bitLength: Int {
    for i in stride(from: 3, through: 0, by: -1) where w[i] != 0 {
      return i * 64 + (64 - w[i].leadingZeroBitCount)
    }
    return 0
  }

  func bit(_ i: Int) -> Bool { (w[i >> 6] >> UInt64(i & 63)) & 1 == 1 }

  mutating func shiftRight1() {
    for i in 0..<4 {
      w[i] = (w[i] >> 1) | (i < 3 ? (w[i + 1] << 63) : 0)
    }
  }

  /// self ^= other << k
  mutating func xorShifted(_ other: GF2Poly, _ k: Int) {
    let ws = k >> 6, bs = UInt64(k & 63)
    for i in stride(from: 3, through: 0, by: -1) {
      let src = i - ws
      guard src >= 0 else { continue }
      var v = other.w[src] << bs
      if bs > 0 && src - 1 >= 0 { v |= other.w[src - 1] >> (64 - bs) }
      w[i] ^= v
    }
  }

  static func mul(_ a: GF2Poly, _ b: GF2Poly) -> GF2Poly {
    var res = GF2Poly()
    let n = b.bitLength
    for i in 0..<n where b.bit(i) { res.xorShifted(a, i) }
    return res
  }

  mutating func reduce() {
    let mLen = GF2Poly.modulus.bitLength
    while true {
      let d = bitLength - mLen
      if d < 0 { break }
      xorShifted(GF2Poly.modulus, d)
    }
  }

  /// x^exponent mod modulus
  static func powMod(exponent: UInt64) -> GF2Poly {
    var res = GF2Poly(w: [1, 0, 0, 0])
    var base = GF2Poly(w: [2, 0, 0, 0])
    var e = exponent
    while e > 0 {
      if e & 1 == 1 {
        res = mul(res, base); res.reduce()
      }
      base = mul(base, base); base.reduce()
      e >>= 1
    }
    return res
  }
}
