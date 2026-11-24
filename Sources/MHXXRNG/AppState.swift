import AppKit
import RNGCore
import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
  case search, around, time, melding, sequence, fillSlot, combo, reward, dump
  var id: String { rawValue }

  var title: String {
    switch self {
    case .search: return "Charm Search"
    case .around: return "Around a Frame"
    case .time: return "Frame → Wait Time"
    case .melding: return "Halcyon / Juju Meld"
    case .sequence: return "Quest Charm Sequence"
    case .fillSlot: return "Slot & Fill Search"
    case .combo: return "Item Combo Search"
    case .reward: return "Quest Reward Search"
    case .dump: return "Raw RNG Dump"
    }
  }

  var symbol: String {
    switch self {
    case .search: return "magnifyingglass"
    case .around: return "list.bullet.indent"
    case .time: return "timer"
    case .melding: return "flame"
    case .sequence: return "list.number"
    case .fillSlot: return "circle.grid.3x3"
    case .combo: return "flask"
    case .reward: return "gift"
    case .dump: return "number"
    }
  }

  var help: String {
    switch self {
    case .search: return "Find the frames where a charm appears. \"Exact\" matches the points and slots exactly; \"At least\" finds charms with at least those values and also shows aim points."
    case .around: return "List every charm within N frames either side of a frame (around())."
    case .time: return "Convert a frame count to a waiting time at 30 frames per second (watch()). Enter a baseline to get target − baseline."
    case .melding: return "Show the charms a Halcyon or Juju meld gives at a frame (halcyonpush() / jujupush())."
    case .sequence: return "Show the run of quest-reward charms starting at a frame (sequence_charm())."
    case .fillSlot: return "Find charms with a given fill value and slot count (search_fill_slot())."
    case .combo: return "Find your RNG position from item-combination results (search_combo()). Also shows how likely a chance match is, and if nothing matches exactly, checks for a 1–2 frame stutter in the combining rhythm."
    case .reward: return "Find your RNG position from a sequence of quest rewards (search_reward())."
    case .dump: return "Dump raw RNG state values (allpush())."
    }
  }
}

enum SearchMode: String, CaseIterable, Identifiable {
  case exact = "Exact", atLeast = "At least"
  var id: String { rawValue }
}

struct SearchForm {
  var mode: SearchMode = .exact
  var skill1: Int? = 71   // Chain Crit
  var points1 = 4
  var skill2: Int? = 70   // Tenderizer
  var points2 = 5
  var slots = 3
  var origin: Origin = .melding
  var start = 0
  var count = 1_000_000
}

struct AroundForm { var frame = 4723; var num = 60; var origin: Origin = .melding }
struct TimeForm { var target = 4723; var baseline = 1717; var useBaseline = true }
struct MeldingForm { var frame = 1730; var halcyon = true; var rank = 4 }
struct SequenceForm { var frame = 221_014; var count = 40 }
struct FillForm { var start = 0; var count = 1_000_000; var fill = 20; var slots = 3; var origin: Origin = .melding }
struct ComboForm {
  var start = 0
  var count = 10_000_000
  var text = "00 03 06 09 11 13 16 18 21 23 25 27 30\n32 35 38 41 44 47 50 52 55 58 61 65 69\n72 75 78 81 85 88 91 93 97 99"
}
struct RewardForm {
  var start = 0
  var count = 10_000_000
  var bonusTh = 28
  var table = "MysteryBone:20 Fishing:40 RawMeat:65 Whetstone:85 PowerBait:90 HeavyBait:95 SpeedBait:100"
  var sequence = "PowerBait Fishing RawMeat MysteryBone MysteryBone RawMeat Fishing"
}
struct DumpForm { var frame = 1600; var count = 200; var showAll = true }

@MainActor
final class AppState: ObservableObject {
  private let defaults = UserDefaults.standard

  @Published var tool: Tool? = .search
  @Published var showTimer: Bool { didSet { defaults.set(showTimer, forKey: "showTimer") } }
  /// Charm Search: send the first frame found to the Continue Cycles calculator's target.
  @Published var sendFoundToCalc: Bool { didSet { defaults.set(sendFoundToCalc, forKey: "sendFoundToCalc") } }
  let timers = SnipeTimers()
  @Published var kind: CharmKind { didSet { defaults.set(kind.rawValue, forKey: "kind") } }
  @Published var language: Language { didSet { defaults.set(language.rawValue, forKey: "language") } }
  @Published var numOfCharms: Int { didSet { defaults.set(numOfCharms, forKey: "numOfCharms") } }
  @Published var showAllRank: Bool { didSet { defaults.set(showAllRank, forKey: "showAllRank") } }
  @Published var showRare: Bool { didSet { defaults.set(showRare, forKey: "showRare") } }

  @Published var search = SearchForm()
  @Published var around = AroundForm()
  @Published var time = TimeForm()
  @Published var melding = MeldingForm()
  @Published var sequence = SequenceForm()
  @Published var fill = FillForm()
  @Published var combo = ComboForm()
  @Published var reward = RewardForm()
  @Published var dump = DumpForm()

  @Published var output = NSAttributedString(string: "")
  @Published var status = "Ready"
  @Published var isRunning = false
  private var task: Task<Void, Never>?

  init() {
    kind = CharmKind(rawValue: defaults.integer(forKey: "kind")) ?? .enduring
    language = Language(rawValue: defaults.string(forKey: "language") ?? "") ?? .en
    numOfCharms = defaults.object(forKey: "numOfCharms") as? Int ?? 40
    showAllRank = defaults.object(forKey: "showAllRank") as? Bool ?? true
    showRare = defaults.object(forKey: "showRare") as? Bool ?? true
    showTimer = defaults.object(forKey: "showTimer") as? Bool ?? true
    sendFoundToCalc = defaults.object(forKey: "sendFoundToCalc") as? Bool ?? true
  }

  var lang: LanguageTables { languageTables[language]! }
  var tables: CharmTables { charmKindTables[kind.rawValue] }

  func kindName(_ k: CharmKind) -> String { lang.kinds[k.rawValue] }
  func originName(_ o: Origin) -> String { lang.origin[o.rawValue] }

  /// Skills that can roll in the first or second slot for the current charm kind, sorted by name.
  func skillChoices(second: Bool) -> [(id: Int, name: String)] {
    let ids = second ? tables.skill2 : tables.skill1
    return Set(ids).map { (id: $0, name: lang.skill[$0]) }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  /// Fill in Charm Search from a preset: charm kind, skills, points and slots, as an exact
  /// melding search.
  func applyPreset(_ p: CharmPreset) {
    kind = p.kind
    search.mode = .exact
    search.origin = .melding
    search.skill1 = p.skill1
    search.points1 = p.points1
    search.skill2 = p.skill2
    search.points2 = p.points2
    search.slots = p.slots
    status = "Preset: \(p.label(lang)) (\(kindName(p.kind)))"
  }

  /// Clear skill choices that the newly selected charm kind can't roll.
  func kindChanged() {
    if let s = search.skill1, !tables.skill1.contains(s) { search.skill1 = nil }
    if let s = search.skill2, !tables.skill2.contains(s) { search.skill2 = nil }
  }

  func stop() { task?.cancel() }

  func run(_ title: String, _ job: @escaping @Sendable (inout Engine) throws -> Void,
           onFound: (@MainActor ([Int]) -> Void)? = nil) {
    task?.cancel()
    var opts = Options()
    opts.language = language
    opts.numOfCharms = numOfCharms
    opts.showAllRank = showAllRank
    opts.showRare = showRare
    let kind = self.kind
    isRunning = true
    status = "Running \(title)…"
    let started = Date()
    task = Task.detached(priority: .userInitiated) {
      let out = Output()
      var engine = Engine(kind: kind, options: opts, out: out)
      var note: String?
      do {
        try job(&engine)
      } catch is CancellationError {
        note = "Stopped"
      } catch {
        out.print("Error: \(error.localizedDescription)")
        note = "Error"
      }
      if out.lines.allSatisfy({ $0.isEmpty }) { out.write("No results.") }
      if out.truncated { out.print("… output truncated at \(out.maxLines) lines") }
      let text = OutputRenderer.render(out)
      let found = out.foundFrames
      let secs = Date().timeIntervalSince(started)
      let finalNote = note
      await MainActor.run {
        self.output = text
        onFound?(found)
        self.isRunning = false
        self.status = (finalNote ?? "Done") + String(format: " · %@ · %.2fs", title, secs)
      }
    }
  }
}

/// RNGCore is Foundation-free, so give its error type a localized description here.
extension RNGError: LocalizedError {
  public var errorDescription: String? { message }
}

enum OutputRenderer {
  static func color(for tint: Tint) -> NSColor {
    switch tint {
    case .marker: return .systemGreen
    case .rare(let r):
      let rgb: [Int: (CGFloat, CGFloat, CGFloat)] = [
        1: (128, 128, 128), 2: (128, 128, 255), 3: (192, 192, 0), 4: (192, 128, 192),
        5: (128, 192, 128), 6: (64, 64, 192), 7: (192, 64, 64), 8: (128, 192, 192),
        9: (255, 192, 128), 10: (192, 64, 192)]
      let c = rgb[r] ?? (128, 128, 128)
      return NSColor(srgbRed: c.0 / 255, green: c.1 / 255, blue: c.2 / 255, alpha: 1)
    }
  }

  static func render(_ out: Output) -> NSAttributedString {
    let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    let bold = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    // Wrapped continuation lines are indented a little so each output line's start stays clear.
    let para = NSMutableParagraphStyle()
    para.headIndent = 4 * ("0" as NSString).size(withAttributes: [.font: font]).width
    let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.textColor, .paragraphStyle: para]
    let result = NSMutableAttributedString()
    for (i, line) in out.lines.enumerated() {
      if i > 0 { result.append(NSAttributedString(string: "\n", attributes: base)) }
      for seg in line {
        var attrs = base
        if let t = seg.tint {
          attrs[.foregroundColor] = color(for: t)
          attrs[.font] = bold
        }
        result.append(NSAttributedString(string: seg.text, attributes: attrs))
      }
    }
    return result
  }
}
