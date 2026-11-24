// The tools listed in the sidebar (the same set as the macOS app).

enum Tool: Int, CaseIterable {
  case search, around, time, melding, sequence, fillSlot, combo, reward, dump

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

  var help: String {
    switch self {
    case .search: return "Find the frames where a charm appears. \"Exact\" matches the points and slots exactly; \"At least\" finds charms with at least those values and also shows aim points."
    case .around: return "List every charm within N frames either side of a frame (around())."
    case .time: return "Convert a frame count to a waiting time at 30 frames per second (watch()). Enter a baseline to get target − baseline. The result is also copied to the snipe timer's wait time."
    case .melding: return "Show the charms a Halcyon or Juju meld gives at a frame (halcyonpush() / jujupush())."
    case .sequence: return "Show the run of quest-reward charms starting at a frame (sequence_charm())."
    case .fillSlot: return "Find charms with a given fill value and slot count (search_fill_slot())."
    case .combo: return "Find your RNG position from item-combination results (search_combo()). Also shows how likely a chance match is, and if nothing matches exactly, checks for a 1–2 frame stutter in the combining rhythm."
    case .reward: return "Find your RNG position from a sequence of quest rewards (search_reward())."
    case .dump: return "Dump raw RNG state values (allpush())."
    }
  }

  /// Short name for the status line.
  var runName: String {
    switch self {
    case .search: return "search"
    case .around: return "around"
    case .time: return "wait time"
    case .melding: return "meld"
    case .sequence: return "sequence"
    case .fillSlot: return "slot & fill search"
    case .combo: return "combo search"
    case .reward: return "reward search"
    case .dump: return "RNG dump"
    }
  }
}

/// Control and command IDs.
enum ID {
  // Sidebar, run row and output
  static let toolList = 100, kind = 101, language = 102, showTimer = 103
  static let run = 110, stop = 111, copy = 112, clear = 113
  // Charm Search
  static let presets = 200, searchMode = 201, skill1 = 202, points1 = 203, skill2 = 204, points2 = 205
  static let searchSlots = 206, searchOrigin = 207, searchStart = 208, searchCount = 209, sendToCalc = 210
  // Other tools
  static let aroundFrame = 220, aroundNum = 221, aroundOrigin = 222
  static let timeTarget = 230, timeUseBaseline = 231, timeBaseline = 232
  static let meldKind = 240, meldFrame = 241, meldRank = 242
  static let seqFrame = 250, seqCount = 251
  static let fillFill = 260, fillSlots = 261, fillOrigin = 262, fillStart = 263, fillCount = 264
  static let comboText = 270, comboStart = 271, comboCount = 272
  static let rewardTable = 280, rewardSeq = 281, rewardBonus = 282, rewardStart = 283, rewardCount = 284
  static let dumpFrame = 290, dumpCount = 291, dumpShowAll = 292
  // Menu commands
  static let menuCopy = 600, menuExit = 601, menuSettings = 602
  static let menuShowTimer = 610, menuPoogie = 611, menuCounter = 612, menuStopwatch = 613
  static let menuResetStopwatch = 614, menuCountdown = 615
  static let menuAbout = 620, menuWebsite = 621
  // Charm presets: presetBase + index into App.presetList
  static let presetBase = 5000
}
