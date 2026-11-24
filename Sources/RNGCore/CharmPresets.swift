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

  /// "Tenderizer +6 / Expert +10 ◯◯◯" in the given language, with the charm kind added
  /// when it isn't an Enduring charm.
  public func label(_ lang: LanguageTables) -> String {
    "\(lang.skill[skill1]) +\(points1) / \(lang.skill[skill2]) +\(points2) " + String(repeating: "◯", count: slots)
      + (kind == .enduring ? "" : " (\(lang.kinds[kind.rawValue]))")
  }
}

public enum PresetSection: String, CaseIterable, Sendable {
  case blademaster = "Blademaster", gunner = "Gunner"
}

public struct CharmPresetGroup: Hashable, Sendable {
  public let name: String
  public let section: PresetSection
  public let presets: [CharmPreset]
}

public enum CharmPresets {
  /// The presets shown in the menu: `allGroups` with duplicates folded into each section's
  /// General group, so a charm is listed once (see `deduplicated`).
  public static let groups: [CharmPresetGroup] = deduplicated(allGroups)

  /// Within each section, a charm that is in the General group, or in two or more weapon
  /// groups, is listed only under General. The first group of each section is its General
  /// group. Weapon groups left empty are dropped.
  static func deduplicated(_ groups: [CharmPresetGroup]) -> [CharmPresetGroup] {
    var result: [CharmPresetGroup] = []
    for section in PresetSection.allCases {
      let inSection = groups.filter { $0.section == section }
      guard let general = inSection.first else { continue }
      let weapons = inSection.dropFirst()
      var seenIn: [CharmPreset: Int] = [:]
      for g in weapons { for p in Set(g.presets) { seenIn[p, default: 0] += 1 } }
      var generalPresets = general.presets
      for g in weapons {
        for p in g.presets where seenIn[p, default: 0] > 1 && !generalPresets.contains(p) { generalPresets.append(p) }
      }
      result.append(CharmPresetGroup(name: general.name, section: section, presets: generalPresets))
      for g in weapons {
        let own = g.presets.filter { !generalPresets.contains($0) }
        if !own.isEmpty { result.append(CharmPresetGroup(name: g.name, section: section, presets: own)) }
      }
    }
    return result
  }

  /// Every preset, grouped as recommended per weapon (with repeats).
  static let allGroups: [CharmPresetGroup] = [
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

    // Gunner: an ammo or weapon skill at its Enduring maximum, paired like the Blademaster
    // charms, built from community weapon-guide recommendations and checked against the tables.
    group("General Gunner", section: .gunner, [
      ("Normal Up", 6, "Expert", 10), ("Normal Up", 6, "Critical Up", 5), ("Normal Up", 6, "Attack", 10),
      ("Pierce Up", 6, "Expert", 10), ("Pierce Up", 6, "Critical Up", 5), ("Pierce Up", 6, "Attack", 10),
      ("Pellet Up", 6, "Expert", 10), ("Pellet Up", 6, "Critical Up", 5),
      ("Heavy Up", 6, "Expert", 10), ("Heavy Up", 6, "Critical Up", 5),
      ("Chain Crit", 5, "Expert", 10), ("Tenderizer", 6, "Expert", 10), ("Ammo Saver", 7, "Expert", 10),
    ]),
    group("Light Bowgun", section: .gunner, [
      ("Rapid Fire", 5, "Expert", 10), ("Rapid Fire", 5, "Critical Up", 5),
      ("Normal Up", 6, "Rapid Fire", 5), ("Pierce Up", 6, "Rapid Fire", 5), ("Ammo Saver", 7, "Rapid Fire", 5),
      ("Recoil", 6, "Reload Spd", 7), ("Reload Spd", 7, "Recoil", 7), ("Evade Dist", 6, "Expert", 10),
    ]),
    group("Heavy Bowgun", section: .gunner, [
      ("Recoil", 6, "Reload Spd", 7), ("Reload Spd", 7, "Recoil", 7),
      ("Normal Up", 6, "Recoil", 7), ("Pierce Up", 6, "Recoil", 7), ("Pierce Up", 6, "Reload Spd", 7),
      ("Pellet Up", 6, "Recoil", 7), ("Loading", 5, "Expert", 10), ("Ammo Saver", 7, "Recoil", 7),
    ]),
    // Power C+ (for "Use Power Coating") only appears on Shining charms, and high-point Shining
    // charms can have at most 1 slot: max points with 1 slot, or slightly less with 2.
    group("Bow", section: .gunner, [
      ("Dead Eye", 5, "Expert", 10), ("Dead Eye", 5, "Critical Up", 5),
      ("FastCharge", 6, "Dead Eye", 5), ("FastCharge", 6, "Expert", 10), ("Normal Up", 6, "FastCharge", 5),
      ("Normal Up", 6, "Dead Eye", 5), ("Pierce Up", 6, "Dead Eye", 5), ("Pellet Up", 6, "Dead Eye", 5),
      ("Heavy Up", 6, "Dead Eye", 5), ("Chain Crit", 5, "Dead Eye", 5), ("Evasion", 6, "Dead Eye", 5),
    ], extra: rows([("Expert", 4, "Power C+", 12), ("Attack", 4, "Power C+", 12)], kind: .shining, slots: 1)
      + rows([("Expert", 3, "Power C+", 11), ("Attack", 3, "Power C+", 11)], kind: .shining, slots: 2)),
  ]

  /// "Element Atk" presets, one per element.
  static func elements(_ make: (String) -> (String, Int, String, Int)) -> [(String, Int, String, Int)] {
    ["Fire Atk", "Water Atk", "Thunder Atk", "Ice Atk", "Dragon Atk"].map(make)
  }

  /// Builds a group of 3-slot Enduring presets from English skill names.
  static func group(_ name: String, section: PresetSection = .blademaster,
                    _ list: [(String, Int, String, Int)], extra: [CharmPreset] = []) -> CharmPresetGroup {
    CharmPresetGroup(name: name, section: section, presets: rows(list) + extra)
  }

  /// Presets from English skill names (3-slot Enduring unless stated).
  static func rows(_ list: [(String, Int, String, Int)], kind: CharmKind = .enduring, slots: Int = 3) -> [CharmPreset] {
    let en = languageTables[.en]!.skill
    func id(_ s: String) -> Int {
      guard let i = en.firstIndex(of: s) else { preconditionFailure("unknown skill name \(s)") }
      return i
    }
    return list.map {
      CharmPreset(kind: kind, skill1: id($0.0), points1: $0.1, skill2: id($0.2), points2: $0.3, slots: slots)
    }
  }
}

extension CharmTables {
  /// Whether a two-skill charm with these points and slots can come from melding for this kind.
  /// (Presets never use the same skill twice.)
  public func canRoll(skill1 a: Int, points1 pa: Int, skill2 b: Int, points2 pb: Int, slots: Int) -> Bool {
    a != b && impossibleReason(skill1: a, points1: pa, skill2: b, points2: pb, slots: slots,
                               origin: .melding, atLeast: false, lang: languageTables[.en]!) == nil
  }
}
