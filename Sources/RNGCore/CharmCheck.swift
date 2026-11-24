// Checks whether a Charm Search target can exist at all, before searching for it, and explains
// why not. Uses the same rules as charm generation (`Engine.getCharm`):
//
// - skill 1 must be in this kind's first-skill list, with points in its range;
// - skill 2 must be in its second-skill list, with points 1…max (melding) or −min…max (quests);
// - the slot count must be reachable for the charm's "fill", which grows with its points.

extension CharmTables {
  /// Slot counts a charm with this fill value (1–20) can have.
  public func possibleSlots(fill: Int) -> [Int] {
    let v = slotValue[min(max(fill, 1), 20) - 1]
    let lower = [0, v.0, v.1, v.2], upper = [v.0, v.1, v.2, 100]
    return (0...3).filter { lower[$0] <= 99 && lower[$0] < upper[$0] }
  }

  /// nil if a charm matching this search can exist; otherwise a short explanation.
  ///
  /// - Parameters:
  ///   - skill1/skill2: global skill IDs, or nil for "no second skill" (exact) / "any" (at least).
  ///   - atLeast: true for "At least" searches (points and slots are minimums).
  public func impossibleReason(skill1 a: Int?, points1 pa: Int, skill2 b: Int?, points2 pb: Int,
                               slots: Int, origin: Origin, atLeast: Bool,
                               lang: LanguageTables) -> String? {
    let kindName = lang.kinds[kind] + "s"
    func name(_ id: Int) -> String { lang.skill[id] }
    func slotList(_ s: [Int]) -> String {
      s.count == 1 ? "\(s[0])" : s.dropLast().map(String.init).joined(separator: ", ") + " or \(s.last!)"
    }

    var max1: Int?
    if let a {
      guard let i = skill1.firstIndex(of: a) else {
        return "\(name(a)) can't be the first skill on \(kindName)."
      }
      let r = sp1[i]
      max1 = r.1
      if atLeast ? pa > r.1 : !(r.0...r.1).contains(pa) {
        return "On \(kindName), \(name(a)) in slot 1 ranges from +\(r.0) to +\(r.1)."
      }
    }
    var max2: Int?
    if let b {
      guard let i = skill2.firstIndex(of: b) else {
        return "\(name(b)) can't be the second skill on \(kindName)."
      }
      let r = sp2[i]
      max2 = r.1
      let low = origin == .quest ? -r.0 : 1
      if atLeast ? pb > r.1 : !(low...r.1).contains(pb) {
        let range = low == 1 ? "+1 to +\(r.1)" : "\(low) to +\(r.1)"
        return "On \(kindName) from \(origin == .quest ? "quests" : "melding"), \(name(b)) in slot 2 ranges from \(range)."
      }
    }

    // Slots depend on the charm's fill: floor(10 × (points1 / max1 + points2 / max2)).
    // With "any first skill" (At least, skill 1 empty) the fill isn't known, so don't check slots.
    guard let m1 = max1 else { return nil }
    func fill(_ p1: Int, _ p2: Int) -> Int {
      if let b, let m2 = max2, b != a { return (p1 * m2 + max(p2, 0) * m1) * 10 / (m1 * m2) }
      return p1 * 10 / m1
    }
    // Exact: the fill for these points. At least: every fill from these points up to the
    // maximum (more points doesn't always mean more slots, e.g. on Mystery charms).
    let fills = atLeast ? Array(fill(pa, pb)...fill(m1, max2 ?? 0)) : [fill(pa, pb)]
    let possible = Array(Set(fills.flatMap { possibleSlots(fill: $0) })).sorted()
    let ok = atLeast ? possible.contains { $0 >= slots } : possible.contains(slots)
    if !ok {
      let what = atLeast ? "with at least these points" : "with these points"
      return "\(kindName) like this can have \(slotList(possible)) slot\(possible == [1] ? "" : "s") \(what), not \(atLeast ? "\(slots) or more" : "\(slots)")."
    }
    return nil
  }
}
