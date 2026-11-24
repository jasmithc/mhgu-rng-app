import Foundation

public struct CharmTables {
  public let skill1: [Int]
  public let sp1: [(Int, Int)]
  public let skill2: [Int]
  public let sp2: [(Int, Int)]
  public let slotValue: [(Int, Int, Int)]
  public let th: Int
  public let kind: Int

  public init(skill1: [Int], sp1: [(Int, Int)], skill2: [Int], sp2: [(Int, Int)],
              slotValue: [(Int, Int, Int)], th: Int, kind: Int) {
    self.skill1 = skill1; self.sp1 = sp1; self.skill2 = skill2; self.sp2 = sp2
    self.slotValue = slotValue; self.th = th; self.kind = kind
  }
}

public enum Language: String, CaseIterable, Identifiable, Sendable {
  case en, ja, zh
  public var id: String { rawValue }
  public var displayName: String {
    switch self {
    case .en: return "English"
    case .ja: return "日本語"
    case .zh: return "中文"
    }
  }
}

public struct LanguageTables {
  public let skill: [String]
  public let origin: [String]
  public let kinds: [String]
  public let melding: [String]
  public let kindWidth: String
  public let noSkill: String
  public let skillWidth: String
}

/// Charm kinds, in the notebook's order (set_blue, set_red, set_yellow, set_white).
public enum CharmKind: Int, CaseIterable, Identifiable, Sendable {
  case enduring = 0, timeworn = 1, shining = 2, mystery = 3
  public var id: Int { rawValue }
}

public enum Origin: Int, CaseIterable, Identifiable, Sendable {
  case melding = 0, quest = 1
  public var id: Int { rawValue }
}

public struct Options: Sendable {
  /// `num_of_charms`: quest charm count used for quest aim points.
  public var numOfCharms: Int = 40
  /// `showallrank`: show Halcyon/Juju aim points for every rank, not only rank 4.
  public var showAllRank: Bool = true
  /// `showrare`: show the rarity after each charm.
  public var showRare: Bool = true
  public var language: Language = .en
  public init() {}
}

public struct Charm {
  public var skill1: Int
  public var points1: Int
  public var skill2: Int   // -1 when the charm has no second skill
  public var points2: Int
  public var slots: Int
  public var fill: Int
  public var slotRoll: Int
  public var rare: Int
}

/// Equivalent of the list returned by the notebook's `parameter()`.
public struct SearchParams {
  public var id1: Int
  public var sp1: Int
  public var id2: Int
  public var sp2: Int
  public var slots: Int
  public var origin: Int
  public var len1: Int
  public var len2: Int
}

public struct RNGError: LocalizedError {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}

// MARK: - Output

public enum Tint: Equatable, Sendable {
  case rare(Int)
  case marker
}

public struct Segment: Sendable {
  public var text: String
  public var tint: Tint?
}

/// Collects printed text, the way the notebook's cells print to stdout.
public final class Output: @unchecked Sendable {
  public private(set) var lines: [[Segment]] = [[]]
  public let maxLines: Int
  public private(set) var truncated = false
  /// Frames reported by search / search_greater, in the order found.
  public private(set) var foundFrames: [Int] = []
  public func recordFound(_ frame: Int) { foundFrames.append(frame) }

  public init(maxLines: Int = 200_000) { self.maxLines = maxLines }

  public var isFull: Bool { lines.count >= maxLines }

  public func write(_ text: String, tint: Tint? = nil) {
    let parts = text.split(separator: "\n", omittingEmptySubsequences: false)
    for (i, part) in parts.enumerated() {
      if i > 0 {
        if isFull { truncated = true; return }
        lines.append([])
      }
      if !part.isEmpty { lines[lines.count - 1].append(Segment(text: String(part), tint: tint)) }
    }
  }

  /// Python's `print(text, end=end)`.
  public func print(_ text: String = "", end: String = "\n") {
    write(text + end)
  }

  public var plainText: String {
    lines.map { $0.map(\.text).joined() }.joined(separator: "\n")
  }
}

// MARK: - Python-style format specs

/// Implements the subset of Python's format-spec mini-language that the notebook uses:
/// `[[fill]align][0][width][x]`.
enum PyFormat {
  static func parse(_ spec: String, numeric: Bool) -> (fill: Character, align: Character, width: Int, hex: Bool) {
    var chars = Array(spec)
    var fill: Character = " "
    var align: Character = numeric ? ">" : "<"
    if chars.count >= 2, chars[1] == "<" || chars[1] == ">" {
      fill = chars[0]; align = chars[1]; chars.removeFirst(2)
    } else if let first = chars.first, first == "<" || first == ">" {
      align = first; chars.removeFirst()
    }
    var hex = false
    if chars.last == "x" { hex = true; chars.removeLast() }
    if chars.first == "0", chars.count > 1 { fill = "0"; align = ">"; chars.removeFirst() }
    return (fill, align, Int(String(chars)) ?? 0, hex)
  }

  static func pad(_ s: String, fill: Character, align: Character, width: Int) -> String {
    let n = s.count
    guard n < width else { return s }
    let padding = String(repeating: fill, count: width - n)
    return align == "<" ? s + padding : padding + s
  }

  static func str(_ s: String, _ spec: String) -> String {
    let p = parse(spec, numeric: false)
    return pad(s, fill: p.fill, align: p.align, width: p.width)
  }

  static func int(_ v: Int, _ spec: String) -> String {
    let p = parse(spec, numeric: true)
    let s = p.hex ? String(v, radix: 16) : String(v)
    return pad(s, fill: p.fill, align: p.align, width: p.width)
  }
}

@inline(__always) func floorDiv(_ a: Int, _ b: Int) -> Int {
  let q = a / b
  return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
}

@inline(__always) func floorMod(_ a: Int, _ b: Int) -> Int {
  let r = a % b
  return (r != 0 && (r < 0) != (b < 0)) ? r + b : r
}

/// The notebook's `watch()`: frames (30 per second) to `Xd Xh Xm Xs Xf`.
public func frameTime(_ f: Int) -> String {
  let d = floorDiv(f, 2_592_000)
  let h = floorDiv(floorMod(f, 2_592_000), 108_000)
  let m = floorDiv(floorMod(f, 108_000), 1800)
  let s = floorDiv(floorMod(f, 1800), 30)
  let fr = floorMod(f, 30)
  return "\(d)d \(h)h \(m)m \(s)s \(fr)f"
}
