// Command-line harness: runs one engine function and prints the plain-text output,
// so it can be diffed against the Python notebook (see tools/compare.py).
//
//   rngcheck <lang> <kind 0-3> <command> [args...]
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(ucrt)
import ucrt
#endif
import RNGCore

var args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 3, let lang = Language(rawValue: args[0]), let kindRaw = Int(args[1]),
      let kind = CharmKind(rawValue: kindRaw) else {
  print("usage: rngcheck <en|ja|zh> <kind> <command> [args]")
  exit(2)
}
let cmd = args[2]
let a = Array(args.dropFirst(3))
func i(_ k: Int) -> Int { Int(a[k])! }
func skillID(_ s: String) -> Int? {
  if s.isEmpty || s == "-" { return nil }
  return languageTables[lang]!.skill.firstIndex(of: s)!
}

var opts = Options()
opts.language = lang
let out = Output()
var e = Engine(kind: kind, options: opts, out: out)

do {
  switch cmd {
  case "search", "search_greater":
    // name1 pts1 name2 pts2 slots origin start step
    let p = try e.parameter(skill1: skillID(a[0]), points1: i(1), skill2: skillID(a[2]), points2: i(3),
                            slots: i(4), origin: Origin(rawValue: i(5))!)
    if cmd == "search" { try e.search(start: i(6), step: i(7), p) }
    else { try e.searchGreater(start: i(6), step: i(7), p) }
  case "around": e.around(frame: i(0), num: i(1), origin: Origin(rawValue: i(2))!)
  case "halcyon": e.meldingPush(frame: i(0), halcyon: true, rank: i(1))
  case "juju": e.meldingPush(frame: i(0), halcyon: false, rank: i(1))
  case "sequence": e.sequenceCharm(frame: i(0), count: i(1))
  case "fill": try e.searchFillSlot(start: i(0), step: i(1), fill: i(2), slot: i(3), origin: Origin(rawValue: i(4))!)
  case "allpush": try e.allPush(frame: i(0), count: i(1), showAll: a[2] == "1")
  case "watch": out.print(frameTime(i(0)))
  case "combo": try e.searchCombo(start: i(0), step: i(1), combo: a[2])
  case "reward":
    let table = a[3].split(separator: " ").map { p -> (String, Int) in
      let kv = p.split(separator: ":"); return (String(kv[0]), Int(kv[1])!)
    }
    try e.searchReward(start: i(0), step: i(1), bonusTh: i(2), target: a[4], table: table)
  default:
    print("unknown command"); exit(2)
  }
} catch {
  print("error: \(error)")
}
print(out.plainText, terminator: "")
