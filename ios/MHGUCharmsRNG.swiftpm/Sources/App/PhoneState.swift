import RNGCore
import SnipeKit
import SwiftUI

/// Charm Search inputs.
struct SearchForm {
  enum Mode: String, CaseIterable, Identifiable { case exact = "Exact", atLeast = "At least"; var id: String { rawValue } }
  var mode: Mode = .exact
  var skill1: Int? = 71   // Chain Crit
  var points1 = 4
  var skill2: Int? = 70   // Tenderizer
  var points2 = 5
  var slots = 3
  var origin: Origin = .melding
  var start = 0
  var count = 1_000_000
}

/// App-wide state for the iPhone/iPad app: settings, the search form, the last results,
/// and the shared snipe timer.
@MainActor
final class PhoneState: ObservableObject {
  private let defaults = UserDefaults.standard

  @Published var kind: CharmKind { didSet { defaults.set(kind.rawValue, forKey: "kind"); kindChanged() } }
  @Published var language: Language { didSet { defaults.set(language.rawValue, forKey: "language") } }
  @Published var numOfCharms: Int { didSet { defaults.set(numOfCharms, forKey: "numOfCharms") } }
  @Published var showAllRank: Bool { didSet { defaults.set(showAllRank, forKey: "showAllRank") } }
  @Published var showRare: Bool { didSet { defaults.set(showRare, forKey: "showRare") } }
  @Published var sendFoundToCalc: Bool { didSet { defaults.set(sendFoundToCalc, forKey: "sendFoundToCalc") } }

  @Published var search = SearchForm()
  @Published var output: AttributedString = ""
  @Published var status = ""
  @Published var isRunning = false
  private var task: Task<Void, Never>?

  let timers = SnipeTimers()

  init() {
    kind = CharmKind(rawValue: defaults.integer(forKey: "kind")) ?? .enduring
    language = Language(rawValue: defaults.string(forKey: "language") ?? "") ?? .en
    numOfCharms = defaults.object(forKey: "numOfCharms") as? Int ?? 40
    showAllRank = defaults.object(forKey: "showAllRank") as? Bool ?? true
    showRare = defaults.object(forKey: "showRare") as? Bool ?? true
    sendFoundToCalc = defaults.object(forKey: "sendFoundToCalc") as? Bool ?? true
  }

  var lang: LanguageTables { languageTables[language]! }
  var tables: CharmTables { charmKindTables[kind.rawValue] }
  func kindName(_ k: CharmKind) -> String { lang.kinds[k.rawValue] }
  func originName(_ o: Origin) -> String { lang.origin[o.rawValue] }

  /// Skills this charm kind can roll in slot 1 or slot 2, sorted by name.
  func skillChoices(second: Bool) -> [(id: Int, name: String)] {
    Set(second ? tables.skill2 : tables.skill1).map { (id: $0, name: lang.skill[$0]) }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private func kindChanged() {
    if let s = search.skill1, !tables.skill1.contains(s) { search.skill1 = nil }
    if let s = search.skill2, !tables.skill2.contains(s) { search.skill2 = nil }
  }

  /// Why the current search target can't exist, or nil if it can.
  var searchProblem: String? {
    let f = search
    if f.skill1 == nil && f.skill2 == nil { return nil }
    return tables.impossibleReason(skill1: f.skill1, points1: f.points1, skill2: f.skill2, points2: f.points2,
                                   slots: f.slots, origin: f.origin, atLeast: f.mode == .atLeast, lang: lang)
  }

  func applyPreset(_ p: CharmPreset) {
    kind = p.kind
    search.mode = .exact
    search.origin = .melding
    search.skill1 = p.skill1
    search.points1 = p.points1
    search.skill2 = p.skill2
    search.points2 = p.points2
    search.slots = p.slots
    search.count = max(search.count, 100_000_000)   // top charms are often tens of millions of frames away
  }

  func runSearch() {
    let f = search
    if f.mode == .exact && f.skill1 == nil { show("Exact search needs a first skill."); return }
    if f.skill1 == nil && f.skill2 == nil { show("Pick at least one skill."); return }
    if let problem = searchProblem { show("Not searched: this charm can't exist.\n" + problem); return }
    run("Charm Search", onFound: { [weak self] frames in
      guard let self, self.sendFoundToCalc, let first = frames.first else { return }
      self.timers.calcTarget = first
      self.status += " · Continue Cycles target set to \(first)"
    }) { e in
      let p = try e.parameter(skill1: f.skill1, points1: f.points1, skill2: f.skill2,
                              points2: f.points2, slots: f.slots, origin: f.origin)
      if f.mode == .exact { try e.search(start: f.start, step: f.count, p) }
      else { try e.searchGreater(start: f.start, step: f.count, p) }
    }
  }

  func show(_ message: String) {
    output = AttributedString(message)
    status = ""
  }

  func stop() { task?.cancel() }

  /// Runs an engine job off the main thread and shows its output.
  func run(_ title: String, onFound: (@MainActor ([Int]) -> Void)? = nil,
           _ job: @escaping @Sendable (inout Engine) throws -> Void) {
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
      let out = Output(maxLines: 5000)   // keep the phone responsive
      var engine = Engine(kind: kind, options: opts, out: out)
      var note = "Done"
      do { try job(&engine) } catch is CancellationError { note = "Stopped" } catch {
        out.print("Error: \(error)"); note = "Error"
      }
      if out.lines.allSatisfy({ $0.isEmpty }) { out.write("No results.") }
      if out.truncated { out.print("… output truncated at \(out.maxLines) lines") }
      let text = OutputStyle.render(out)
      let found = out.foundFrames
      let secs = Date().timeIntervalSince(started)
      let finalNote = note
      await MainActor.run {
        self.output = text
        self.isRunning = false
        self.status = "\(finalNote) · \(String(format: "%.2fs", secs))"
        onFound?(found)
      }
    }
  }
}

enum OutputStyle {
  static func color(_ tint: Tint) -> Color {
    switch tint {
    case .marker: return .green
    case .rare(let r):
      let rgb: [Int: (Double, Double, Double)] = [
        1: (128, 128, 128), 2: (128, 128, 255), 3: (192, 192, 0), 4: (192, 128, 192),
        5: (128, 192, 128), 6: (64, 64, 192), 7: (192, 64, 64), 8: (128, 192, 192),
        9: (255, 192, 128), 10: (192, 64, 192)]
      let c = rgb[r] ?? (128, 128, 128)
      return Color(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255)
    }
  }

  static func render(_ out: Output) -> AttributedString {
    var result = AttributedString()
    for (i, line) in out.lines.enumerated() {
      if i > 0 { result.append(AttributedString("\n")) }
      for seg in line {
        var a = AttributedString(seg.text)
        if let t = seg.tint { a.foregroundColor = color(t); a.font = .system(.caption, design: .monospaced).bold() }
        result.append(a)
      }
    }
    return result
  }
}
