// Ready-made "god charm" targets for Charm Search: the best 3-slot Enduring charms for
// Blademaster weapons, grouped by weapon. Every preset is checked against the game's charm
// tables by `CharmTables.canRoll` (see the unit tests), so each one can actually exist.

public struct CharmPreset: Hashable, Sendable {
  public let kind: CharmKind
  /// Global skill IDs (index into the skill-name tables).
  public let skill1: Int
  public let points1: Int
  public let skill2: Int
  public let points2: Int
  public let slots: Int

  /// "Tenderizer +6 / Expert +10 ◯◯◯" in the given language.
  public func label(_ lang: LanguageTables) -> String {
    "\(lang.skill[skill1]) +\(points1) / \(lang.skill[skill2]) +\(points2) " + String(repeating: "◯", count: slots)
  }
}

public struct CharmPresetGroup: Hashable, Sendable {
  public let name: String
  public let presets: [CharmPreset]
}

public enum CharmPresets {
  public static let groups: [CharmPresetGroup] = [
    group("General Blademaster", [
      ("Tenderizer", 6, "Expert", 10), ("Tenderizer", 6, "Critical Up", 5), ("Tenderizer", 6, "Attack", 10),
      ("Tenderizer", 6, "Sharpness", 7), ("Tenderizer", 6, "Handicraft", 5),
      ("Sharpness", 7, "Expert", 10), ("Sharpness", 7, "Critical Up", 5), ("Sharpness", 7, "Handicraft", 5),
      ("Sharpness", 7, "Attack", 10),
      ("Chain Crit", 5, "Expert", 10), ("Chain Crit", 5, "Critical Up", 5), ("Chain Crit", 5, "Sharpness", 7),
      ("Chain Crit", 5, "Handicraft", 5),
      ("Spirit", 5, "Expert", 10), ("Spirit", 5, "Tenderizer", 5), ("Spirit", 5, "Critical Up", 5),
      ("Spirit", 5, "Sharpness", 7), ("Spirit", 5, "Handicraft", 5),
    ]),
    group("Great Sword", [
      ("FastCharge", 6, "Crit Draw", 5), ("FastCharge", 6, "Critical Up", 5), ("FastCharge", 6, "Expert", 10),
      ("FastCharge", 6, "Attack", 10), ("FastCharge", 6, "Tenderizer", 5),
      ("Crit Draw", 5, "Critical Up", 5), ("Crit Draw", 5, "Punish Draw", 8),
      ("Sheathing", 10, "Crit Draw", 5),
      ("Sheathe Sharpen", 10, "Crit Draw", 5), ("Sheathe Sharpen", 10, "Critical Up", 5),
    ]),
    group("Long Sword", [
      ("Tenderizer", 6, "Expert", 10), ("Sharpness", 7, "Critical Up", 5), ("Spirit", 5, "Expert", 10),
      ("Sheathe Sharpen", 10, "Expert", 10), ("Sheathe Sharpen", 10, "Critical Up", 5),
    ]),
    group("Sword & Shield / Dual Blades", [
      ("Chain Crit", 5, "Expert", 10), ("Chain Crit", 5, "Critical Up", 5),
      ("Sharpness", 7, "Expert", 10), ("Sharpness", 7, "Handicraft", 5),
      ("Crit Element", 6, "Expert", 10),
    ] + elements { ("Crit Element", 6, $0, 13) } + elements { ("Elemental", 7, $0, 13) } + [
      ("Elemental", 7, "Sharpness", 7),
      ("Status", 7, "Expert", 10), ("Crit Status", 6, "Status", 7),
    ]),
    group("Hammer", [
      ("Tenderizer", 6, "Expert", 10), ("Tenderizer", 6, "Critical Up", 5), ("Tenderizer", 6, "KO", 10),
      ("Sharpness", 7, "Expert", 10), ("Spirit", 5, "Critical Up", 5), ("Blunt", 6, "Expert", 10),
    ]),
    group("Hunting Horn", [
      ("Tenderizer", 6, "Maestro", 10), ("Sharpness", 7, "Maestro", 10), ("Chain Crit", 5, "Maestro", 10),
      ("Spirit", 5, "Maestro", 10), ("Evasion", 6, "Maestro", 10),
    ]),
    group("Lance", [
      ("Guard", 7, "Expert", 10), ("Guard", 7, "Critical Up", 5), ("Guard", 7, "Sharpness", 7),
      ("Guard", 7, "Tenderizer", 5), ("Guard Up", 7, "Guard", 5),
      ("Chain Crit", 5, "Expert", 10), ("Tenderizer", 6, "Expert", 10),
    ]),
    group("Gunlance", [
      ("Sharpness", 7, "Artillery", 10), ("Guard", 7, "Artillery", 10), ("Guard Up", 7, "Artillery", 10),
      ("Tenderizer", 6, "Artillery", 10), ("Loading", 5, "Artillery", 10), ("Sharpness", 7, "Handicraft", 5),
      ("Evade Dist", 6, "Artillery", 10),
    ]),
    group("Switch Axe", [
      ("Tenderizer", 6, "Expert", 10), ("Sharpness", 7, "Handicraft", 5), ("Sharpness", 7, "Critical Up", 5),
      ("Chain Crit", 5, "Expert", 10), ("Evade Dist", 6, "Expert", 10), ("Evasion", 6, "Sharpness", 7),
      ("Blunt", 6, "Expert", 10),
    ]),
    group("Charge Blade", [
      ("Tenderizer", 6, "Artillery", 10), ("Sharpness", 7, "Artillery", 10), ("Blunt", 6, "Artillery", 10),
      ("Loading", 5, "Artillery", 10), ("Guard", 7, "Artillery", 10), ("Tenderizer", 6, "Expert", 10),
    ] + elements { ("Elemental", 7, $0, 13) }),
    group("Insect Glaive", [
      ("Tenderizer", 6, "Expert", 10), ("Chain Crit", 5, "Expert", 10), ("Chain Crit", 5, "Critical Up", 5),
      ("Sharpness", 7, "Expert", 10), ("Sharpness", 7, "Handicraft", 5),
      ("Vault", 6, "Expert", 10), ("Vault", 6, "Critical Up", 5),
    ]),
  ]

  /// "Element Atk" presets, one per element.
  static func elements(_ make: (String) -> (String, Int, String, Int)) -> [(String, Int, String, Int)] {
    ["Fire Atk", "Water Atk", "Thunder Atk", "Ice Atk", "Dragon Atk"].map(make)
  }

  /// Builds a group of 3-slot Enduring presets from English skill names.
  static func group(_ name: String, _ rows: [(String, Int, String, Int)]) -> CharmPresetGroup {
    let en = languageTables[.en]!.skill
    func id(_ s: String) -> Int {
      guard let i = en.firstIndex(of: s) else { preconditionFailure("unknown skill name \(s)") }
      return i
    }
    return CharmPresetGroup(name: name, presets: rows.map {
      CharmPreset(kind: .enduring, skill1: id($0.0), points1: $0.1, skill2: id($0.2), points2: $0.3, slots: 3)
    })
  }
}

extension CharmTables {
  /// Whether a charm with these skills, points and slots can be generated for this charm kind
  /// (by melding): skill 1 and skill 2 must be in this kind's lists, the points within range,
  /// and the slot count reachable for the charm's total points.
  public func canRoll(skill1 a: Int, points1 pa: Int, skill2 b: Int, points2 pb: Int, slots: Int) -> Bool {
    guard a != b, let i1 = skill1.firstIndex(of: a), let i2 = skill2.firstIndex(of: b) else { return false }
    let r1 = sp1[i1], max2 = sp2[i2].1
    guard (r1.0...r1.1).contains(pa), (1...max2).contains(pb), (0...3).contains(slots) else { return false }
    let fill = (pa * max2 + pb * r1.1) * 10 / (r1.1 * max2)
    let v = slotValue[fill - 1]
    let need = [0, v.0, v.1, v.2][slots]
    return need <= 99
  }
}
