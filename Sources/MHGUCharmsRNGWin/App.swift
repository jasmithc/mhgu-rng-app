// The main window: tool list and charm/language pickers on the left, the selected tool's form
// and its output in the middle, and the snipe timer panel on the right.
import RNGCore
import WinSDK

let appName = "MHGU Charms RNG"
let appVersion = "1.0.6"
let projectURL = "https://github.com/jasmithc/mhgu-rng-app"

/// A row of the tool form: an optional label in the left column, then controls left to right.
struct FormRow {
  var label: HWND?
  /// Controls and their widths in 96-DPI units (0 = fill the rest of the row; negative = up to
  /// that width, shrinking to leave room for the controls after it).
  var items: [(HWND, Int)]
  var height = 23
  /// A wrapping text control whose row grows to fit its text (and disappears when empty).
  var wrapping = false
}

/// What a background run sends back to the UI thread.
final class JobResult {
  let generation: Int
  let rtf: [UInt8]
  let plainText: String
  let found: [Int]
  let note: String?
  let seconds: Double
  let title: String
  init(generation: Int, rtf: [UInt8], plainText: String, found: [Int], note: String?, seconds: Double, title: String) {
    self.generation = generation; self.rtf = rtf; self.plainText = plainText; self.found = found
    self.note = note; self.seconds = seconds; self.title = title
  }
}

struct FormError: Error { let message: String }

final class App {
  static let jobDoneMessage = WM.app + 1
  static let smokeMessage = WM.app + 3

  var main: HWND!
  var panel: TimerPanel!
  var settings: SettingsWindow?
  var menu: HMENU?
  var accelerators: HACCEL?

  // Sidebar
  var kindLabel: HWND!, kindCombo: HWND!, langLabel: HWND!, langCombo: HWND!
  var toolsLabel: HWND!, toolList: HWND!, showTimerCheck: HWND!
  // Form
  var titleLabel: HWND!, helpLabel: HWND!, searchWarning: HWND!
  var rows: [Tool: [FormRow]] = [:]
  var runButton: HWND!, stopButton: HWND!, runHint: HWND!
  // Output
  var statusLabel: HWND!, copyButton: HWND!, clearButton: HWND!, output: HWND!
  var hasOutput = false

  /// Every control of the form, by ID (so values can be read when running).
  var controls: [Int: HWND] = [:]
  var combos = Set<Int>()        // HWNDs (as Int) of combo boxes: sized with room for the list
  var statics = Set<Int>()       // HWNDs of one-line labels: nudged down to line up with inputs
  var checks = Set<Int>()        // HWNDs of check boxes
  /// Text colours for particular static controls (warnings, captions, readouts).
  var textColors: [Int: COLORREF] = [:]

  var tool: Tool = .search
  /// False while the window is being built: edit controls send change notifications as soon as
  /// they're created, before the rest of the form exists.
  var ready = false
  var presetList: [CharmPreset] = []

  // Settings (saved in the registry, same keys as the macOS app's defaults)
  var kind: CharmKind = .enduring { didSet { Prefs.set("kind", kind.rawValue) } }
  var language: Language = .en { didSet { Prefs.set("language", language.rawValue) } }
  var numOfCharms = 40 { didSet { Prefs.set("numOfCharms", numOfCharms) } }
  var showAllRank = true { didSet { Prefs.set("showAllRank", showAllRank) } }
  var showRare = true { didSet { Prefs.set("showRare", showRare) } }
  var showTimer = true { didSet { Prefs.set("showTimer", showTimer) } }
  var sendFoundToCalc = true { didSet { Prefs.set("sendFoundToCalc", sendFoundToCalc) } }

  // Running
  var isRunning = false
  var generation = 0
  var task: Task<Void, Never>?
  var onFound: (([Int]) -> Void)?
  var lastPlainText = ""
  var status = "Ready" { didSet { setText(statusLabel, status) } }

  // Smoke test (--smoke-test <dir>): runs every tool, saves the output and screenshots, then quits.
  var smokeDir: String?
  var smokeLog = ""
  var smokeQueue: [Tool] = []

  var lang: LanguageTables { languageTables[language]! }
  var tables: CharmTables { charmKindTables[kind.rawValue] }

  init() {
    kind = Prefs.int("kind").flatMap { CharmKind(rawValue: $0) } ?? .enduring
    language = Prefs.string("language").flatMap { Language(rawValue: $0) } ?? .en
    numOfCharms = Prefs.int("numOfCharms") ?? 40
    showAllRank = Prefs.bool("showAllRank") ?? true
    showRare = Prefs.bool("showRare") ?? true
    showTimer = Prefs.bool("showTimer") ?? true
    sendFoundToCalc = Prefs.bool("sendFoundToCalc") ?? true
  }

  // MARK: - Creating the window

  func start(smokeDir: String?) {
    self.smokeDir = smokeDir
    let w = Int32(UI.px(1280)), h = Int32(UI.px(800))
    let CW_USEDEFAULT = Int32(bitPattern: 0x8000_0000)
    main = createWindow(mainClassName, appName, style: WS.overlappedWindow | WS.clipChildren,
                        parent: nil, x: CW_USEDEFAULT, y: CW_USEDEFAULT, w: w, h: h)
    BeepScheduler.shared.notifyWindow = Int(bitPattern: main)
    buildMenu()
    trace("start: did buildMenu()")
    buildSidebar()
    trace("start: did buildSidebar()")
    buildForms()
    trace("start: did buildForms()")
    buildOutput()
    trace("start: did buildOutput()")
    panel = TimerPanel(parent: main, app: self)
    trace("start: did panel = TimerPanel(parent: main, app: self)")
    refreshLanguage()
    trace("start: did refreshLanguage()")
    selectTool(.search)
    trace("start: did selectTool(.search)")
    updateTimerVisibility()
    trace("start: did updateTimerVisibility()")
    updateRunState()
    ready = true
    layout()
    _ = ShowWindow(main, smokeDir == nil ? SW_SHOWNORMAL : SW_SHOW)
    _ = UpdateWindow(main)
    _ = SetFocus(toolList)
    if smokeDir != nil { _ = PostMessageW(main, App.smokeMessage, 0, 0) }
  }

  private func buildMenu() {
    menu = CreateMenu()
    func popup(_ title: String, _ items: [(Int, String)]) {
      let m = CreatePopupMenu()
      for (id, text) in items {
        if id == 0 { _ = AppendMenuW(m, MF.separator, 0, nil) }
        else { _ = withWide(text) { AppendMenuW(m, MF.string, UINT_PTR(id), $0) } }
      }
      _ = withWide(title) { AppendMenuW(menu, MF.popup, UINT_PTR(UInt(bitPattern: m)), $0) }
    }
    popup("&File", [(ID.menuCopy, "&Copy Output"), (0, ""), (ID.menuSettings, "&Settings…"), (0, ""), (ID.menuExit, "E&xit")])
    popup("&Timer", [
      (ID.menuShowTimer, "Show &Timer Panel\tCtrl+Alt+T"), (0, ""),
      (ID.menuPoogie, "&Poogie in Room (−5 cycles)\tCtrl+Alt+P"), (0, ""),
      (ID.menuCounter, "Start/Stop Continue &Counter\tCtrl+Alt+C"),
      (ID.menuStopwatch, "Start/Stop &Stopwatch\tCtrl+Shift+S"),
      (ID.menuResetStopwatch, "&Reset Stopwatch"), (0, ""),
      (ID.menuCountdown, "Start/Cancel Count&down\tCtrl+Shift+Enter"),
    ])
    popup("&Help", [(ID.menuWebsite, "&Project Page and Guide"), (0, ""), (ID.menuAbout, "&About \(appName)")])
    _ = SetMenu(main, menu)

    // FVIRTKEY = 1, FSHIFT = 4, FCONTROL = 8, FALT = 16
    let keys: [(UInt8, UInt16, Int)] = [
      (1 | 8, VK.return, ID.run),
      (1 | 8 | 4, VK.return, ID.menuCountdown),
      (1 | 8 | 16, UInt16(UInt8(ascii: "T")), ID.menuShowTimer),
      (1 | 8 | 16, UInt16(UInt8(ascii: "P")), ID.menuPoogie),
      (1 | 8 | 16, UInt16(UInt8(ascii: "C")), ID.menuCounter),
      (1 | 8 | 4, UInt16(UInt8(ascii: "S")), ID.menuStopwatch),
    ]
    var table = keys.map { ACCEL(fVirt: $0.0, key: $0.1, cmd: WORD($0.2)) }
    accelerators = CreateAcceleratorTableW(&table, Int32(table.count))
  }

  func setMenuCheck(_ id: Int, _ on: Bool) {
    _ = CheckMenuItem(menu, UINT(id), on ? MF.checked : MF.unchecked)
  }

  // MARK: Control helpers

  func label(_ text: String, parent: HWND? = nil, align: DWORD = SS.left, font: HFONT? = UI.font,
             visible: Bool = true, wrap: Bool = false) -> HWND {
    let h = createWindow("STATIC", text, style: WS.child | (visible ? WS.visible : 0) | align | SS.noPrefix,
                         parent: parent ?? main)
    setFont(h, font)
    if !wrap { statics.insert(Int(bitPattern: h)) }
    return h
  }

  func edit(_ text: String, id: Int, parent: HWND? = nil, multiline: Bool = false, mono: Bool = false,
            align: DWORD = ES.left) -> HWND {
    var style = WS.child | WS.tabStop | align
    style |= multiline ? (ES.multiline | ES.wantReturn | ES.autoVScroll | WS.vScroll) : ES.autoHScroll
    let h = createWindow("EDIT", text, style: style, ex: WS.exClientEdge, parent: parent ?? main, id: id)
    setFont(h, mono ? UI.mono : UI.font)
    send(h, ES.setMargins, 3, LPARAM(UI.px(3) | (UI.px(3) << 16)))
    controls[id] = h
    return h
  }

  func combo(id: Int, parent: HWND? = nil, items: [(String, Int)] = [], selected: Int = 0) -> HWND {
    let h = createWindow("COMBOBOX", style: WS.child | WS.tabStop | WS.vScroll | CB.dropDownList,
                         parent: parent ?? main, id: id, h: Int32(UI.px(300)))
    setFont(h, UI.font)
    for (text, data) in items { comboAdd(h, text, data: data) }
    if !items.isEmpty { comboSelect(h, selected) }
    combos.insert(Int(bitPattern: h))
    controls[id] = h
    return h
  }

  func button(_ text: String, id: Int, parent: HWND? = nil, isDefault: Bool = false) -> HWND {
    let h = createWindow("BUTTON", text, style: WS.child | WS.tabStop | (isDefault ? BS.defPushButton : BS.pushButton),
                         parent: parent ?? main, id: id)
    setFont(h, UI.font)
    controls[id] = h
    return h
  }

  func checkbox(_ text: String, id: Int, parent: HWND? = nil, checked: Bool = false) -> HWND {
    let h = createWindow("BUTTON", text, style: WS.child | WS.tabStop | BS.autoCheckBox, parent: parent ?? main, id: id)
    setFont(h, UI.font)
    setChecked(h, checked)
    checks.insert(Int(bitPattern: h))
    controls[id] = h
    return h
  }

  /// Move a control into a row cell, keeping labels and check boxes lined up with the inputs.
  func place(_ h: HWND, _ x: Int, _ y: Int, _ w: Int, _ rowHeight: Int) {
    let key = Int(bitPattern: h)
    if combos.contains(key) {
      moveWindow(h, x, y, w, UI.px(300))
    } else if statics.contains(key) {
      moveWindow(h, x, y + (rowHeight - UI.px(16)) / 2, w, UI.px(18))
    } else if checks.contains(key) {
      moveWindow(h, x, y + (rowHeight - UI.px(20)) / 2, w, UI.px(20))
    } else {
      moveWindow(h, x, y, w, rowHeight)
    }
  }

  // MARK: Sidebar

  private func buildSidebar() {
    kindLabel = label("Charm kind")
    kindCombo = combo(id: ID.kind)
    show(kindCombo, true)
    langLabel = label("Skill names")
    langCombo = combo(id: ID.language, items: Language.allCases.map { ($0.displayName, Language.allCases.firstIndex(of: $0)!) },
                      selected: Language.allCases.firstIndex(of: language) ?? 0)
    show(langCombo, true)
    toolsLabel = label("Tools", font: UI.bold)
    toolList = createWindow("LISTBOX", style: WS.child | WS.visible | WS.tabStop | WS.vScroll | LB.notify | LB.noIntegralHeight,
                            ex: WS.exClientEdge, parent: main, id: ID.toolList)
    setFont(toolList, UI.font)
    send(toolList, LB.setItemHeight, 0, LPARAM(UI.px(24)))
    for t in Tool.allCases { _ = withWide(t.title) { send(toolList, LB.addString, 0, lparam($0)) } }
    showTimerCheck = checkbox("Show snipe timer", id: ID.showTimer, checked: showTimer)
    show(showTimerCheck, true)
  }

  // MARK: Forms

  private func buildForms() {
    titleLabel = label("", font: UI.title)
    helpLabel = label("", wrap: true)

    func numRow(_ text: String, _ id: Int, _ value: Int, width: Int = 180) -> FormRow {
      FormRow(label: label(text, align: SS.right, visible: false),
              items: [(edit(String(value), id: id, align: ES.right), width)])
    }
    func originRow(_ id: Int) -> FormRow {
      FormRow(label: label("Source", align: SS.right, visible: false), items: [(combo(id: id), 160)])
    }
    func rangeRows(_ startID: Int, _ countID: Int, count: Int) -> [FormRow] {
      [numRow("Start frame", startID, 0), numRow("Frames to search", countID, count)]
    }
    func comboRow(_ text: String, _ id: Int, _ items: [(String, Int)], selected: Int, width: Int = 120) -> FormRow {
      FormRow(label: label(text, align: SS.right, visible: false),
              items: [(combo(id: id, items: items, selected: selected), width)])
    }
    func checkRow(_ text: String, _ id: Int, _ on: Bool) -> FormRow {
      FormRow(label: nil, items: [(checkbox(text, id: id, checked: on), 0)], height: 22)
    }
    let slots0 = (0...3).map { ("\($0)", $0) }, slots1 = (1...3).map { ("\($0)", $0) }

    // Charm Search (defaults: Chain Crit +4 / Tenderizer +5, 3 slots)
    let warning = label("", visible: false, wrap: true)
    textColors[Int(bitPattern: warning)] = rgb(200, 100, 0)
    searchWarning = warning
    rows[.search] = [
      FormRow(label: label("Presets", align: SS.right, visible: false), items: [(button("God charms ▾", id: ID.presets), 130)], height: 25),
      comboRow("Match", ID.searchMode, [("Exact", 0), ("At least", 1)], selected: 0),
      FormRow(label: label("First skill", align: SS.right, visible: false),
              items: [(combo(id: ID.skill1), -260), (label("points", visible: false), 40), (edit("4", id: ID.points1, align: ES.right), 60)]),
      FormRow(label: label("Second skill", align: SS.right, visible: false),
              items: [(combo(id: ID.skill2), -260), (label("points", visible: false), 40), (edit("5", id: ID.points2, align: ES.right), 60)]),
      comboRow("Slots", ID.searchSlots, slots0, selected: 3, width: 60),
      originRow(ID.searchOrigin),
    ] + rangeRows(ID.searchStart, ID.searchCount, count: 1_000_000) + [
      FormRow(label: nil, items: [(warning, 0)], wrapping: true),
      checkRow("Set Continue Cycles target to the frame found", ID.sendToCalc, sendFoundToCalc),
    ]
    rows[.around] = [numRow("Frame", ID.aroundFrame, 4723), numRow("Frames either side", ID.aroundNum, 60), originRow(ID.aroundOrigin)]
    rows[.time] = [numRow("Target frame", ID.timeTarget, 4723), checkRow("Subtract a baseline frame", ID.timeUseBaseline, true),
                   numRow("Baseline frame", ID.timeBaseline, 1717)]
    rows[.melding] = [comboRow("Meld", ID.meldKind, [], selected: 0, width: 160), numRow("Frame", ID.meldFrame, 1730),
                      comboRow("Rank", ID.meldRank, [4, 3, 2, 1].map { ("Rank \($0)", $0) }, selected: 0, width: 100)]
    rows[.sequence] = [numRow("Start frame", ID.seqFrame, 221_014), numRow("Number of charms", ID.seqCount, 40)]
    rows[.fillSlot] = [comboRow("Fill", ID.fillFill, (1...20).map { ("\($0)", $0) }, selected: 19, width: 70),
                       comboRow("Slots", ID.fillSlots, slots1, selected: 2, width: 60), originRow(ID.fillOrigin)]
      + rangeRows(ID.fillStart, ID.fillCount, count: 1_000_000)
    let comboText = edit("00 03 06 09 11 13 16 18 21 23 25 27 30\r\n32 35 38 41 44 47 50 52 55 58 61 65 69\r\n72 75 78 81 85 88 91 93 97 99",
                         id: ID.comboText, multiline: true, mono: true)
    rows[.combo] = [FormRow(label: label("Combination results", align: SS.right, visible: false), items: [(comboText, 460)], height: 84)]
      + rangeRows(ID.comboStart, ID.comboCount, count: 10_000_000)
    let table = edit("MysteryBone:20 Fishing:40 RawMeat:65 Whetstone:85 PowerBait:90 HeavyBait:95 SpeedBait:100",
                     id: ID.rewardTable, multiline: true, mono: true)
    let sequence = edit("PowerBait Fishing RawMeat MysteryBone MysteryBone RawMeat Fishing",
                        id: ID.rewardSeq, multiline: true, mono: true)
    rows[.reward] = [
      FormRow(label: label("Reward table", align: SS.right, visible: false), items: [(table, 460)], height: 48),
      FormRow(label: label("Rewards received", align: SS.right, visible: false), items: [(sequence, 460)], height: 48),
      numRow("Bonus threshold", ID.rewardBonus, 28),
    ] + rangeRows(ID.rewardStart, ID.rewardCount, count: 10_000_000)
    rows[.dump] = [numRow("Frame", ID.dumpFrame, 1600), numRow("Frames to show", ID.dumpCount, 200),
                   checkRow("Show skills and mod 100", ID.dumpShowAll, true)]

    runButton = button("Run", id: ID.run, isDefault: true)
    stopButton = button("Stop", id: ID.stop)
    runHint = label("Ctrl+Enter to run · Esc to stop", font: UI.small)
    textColors[Int(bitPattern: runHint)] = rgb(110, 110, 110)
    for h in [titleLabel!, helpLabel!, runButton!, stopButton!, runHint!] { show(h, true) }
  }

  private func buildOutput() {
    statusLabel = label("Ready", align: SS.endEllipsis)
    textColors[Int(bitPattern: statusLabel)] = rgb(90, 90, 90)
    copyButton = button("Copy", id: ID.copy)
    clearButton = button("Clear", id: ID.clear)
    for h in [copyButton!, clearButton!] { show(h, true) }
    output = createWindow("RICHEDIT50W", style: WS.child | WS.visible | WS.vScroll | WS.tabStop | ES.multiline | ES.readOnly | ES.autoVScroll,
                          ex: WS.exClientEdge, parent: main)
    send(output, RE.exLimitText, 0, 0x7FFF_FFFF)
    send(output, RE.setTargetDevice, 0, 0)   // wrap lines to the window width
    send(output, ES.setMargins, 3, LPARAM(UI.px(8) | (UI.px(8) << 16)))
    setFont(output, UI.mono)
  }

  // MARK: - Layout

  func layout() {
    guard main != nil, panel != nil else { return }
    let (W, H) = clientSize(main)
    let pad = UI.px(12)

    // Sidebar
    let sideW = UI.px(220)
    var y = pad
    let sw = sideW - pad
    moveWindow(kindLabel, pad, y, sw, UI.px(18)); y += UI.px(19)
    place(kindCombo, pad, y, sw, UI.px(23)); y += UI.px(33)
    moveWindow(langLabel, pad, y, sw, UI.px(18)); y += UI.px(19)
    place(langCombo, pad, y, sw, UI.px(23)); y += UI.px(35)
    moveWindow(toolsLabel, pad, y, sw, UI.px(18)); y += UI.px(21)
    let checkY = H - pad - UI.px(20)
    moveWindow(toolList, pad, y, sw, checkY - UI.px(8) - y)
    moveWindow(showTimerCheck, pad, checkY, sw, UI.px(20))

    // Timer panel
    let panelW = showTimer ? UI.px(350) : 0
    if showTimer { moveWindow(panel.hwnd, W - panelW, 0, panelW, H) }

    // Tool form
    let x0 = sideW + UI.px(18), x1 = W - panelW - UI.px(18)
    let mw = x1 - x0
    y = pad
    moveWindow(titleLabel, x0, y, mw, UI.px(30)); y += UI.px(34)
    let helpH = textHeight(tool.help, font: UI.font, width: mw, reference: main)
    moveWindow(helpLabel, x0, y, mw, helpH); y += helpH + UI.px(14)

    let labelW = UI.px(140)
    let cx = x0 + labelW + UI.px(10)
    for row in rows[tool] ?? [] {
      var rh = UI.px(row.height)
      if row.wrapping, let first = row.items.first {
        let text = getText(first.0)
        if text.isEmpty { continue }
        rh = textHeight(text, font: UI.font, width: x1 - cx, reference: main)
      }
      if let l = row.label { place(l, x0, y, labelW, rh) }
      var x = cx
      for (i, (h, w)) in row.items.enumerated() {
        let rest = row.items[(i + 1)...].reduce(0) { $0 + UI.px(abs($1.1)) + UI.px(8) }
        let width = w == 0 ? max(x1 - x, UI.px(40))
          : (w < 0 ? max(min(UI.px(-w), x1 - x - rest), UI.px(120)) : UI.px(w))
        if row.wrapping { moveWindow(h, x, y, width, rh) } else { place(h, x, y, width, rh) }
        x += width + UI.px(8)
      }
      y += rh + UI.px(9)
    }
    y += UI.px(4)
    moveWindow(runButton, cx, y, UI.px(88), UI.px(27))
    moveWindow(stopButton, cx + UI.px(96), y, UI.px(88), UI.px(27))
    // The hint only shows when there's room for all of it.
    let hintW = x1 - cx - UI.px(196)
    show(runHint, hintW >= UI.px(180))
    place(runHint, cx + UI.px(196), y, max(hintW, 0), UI.px(27))
    y += UI.px(27) + UI.px(16)

    // Output
    let bw = UI.px(72)
    place(statusLabel, x0, y, mw - 2 * (bw + UI.px(8)), UI.px(25))
    moveWindow(copyButton, x1 - 2 * bw - UI.px(8), y, bw, UI.px(25))
    moveWindow(clearButton, x1 - bw, y, bw, UI.px(25))
    y += UI.px(25) + UI.px(6)
    moveWindow(output, x0, y, mw, H - pad - y)
  }

  // MARK: - Tool selection and pickers

  func selectTool(_ t: Tool) {
    for (other, rs) in rows where other != t {
      for r in rs {
        if let l = r.label { show(l, false) }
        for (h, _) in r.items { show(h, false) }
      }
    }
    tool = t
    for r in rows[t] ?? [] {
      if let l = r.label { show(l, true) }
      for (h, _) in r.items { show(h, true) }
    }
    send(toolList, LB.setCurSel, WPARAM(t.rawValue))
    setText(titleLabel, t.title)
    setText(helpLabel, t.help)
    if t == .search { updateSearchProblem(relayout: false) }
    if t == .time { updateBaselineEnabled() }
    layout()
    _ = InvalidateRect(main, nil, true)
  }

  /// Refill everything that shows names in the skill-name language.
  func refreshLanguage() {
    let kindIndex = kind.rawValue
    send(kindCombo, CB.resetContent)
    for k in CharmKind.allCases { comboAdd(kindCombo, lang.kinds[k.rawValue], data: k.rawValue) }
    comboSelect(kindCombo, kindIndex)
    for id in [ID.searchOrigin, ID.aroundOrigin, ID.fillOrigin] {
      let h = controls[id]!
      let sel = max(comboSelected(h), 0)
      send(h, CB.resetContent)
      for o in Origin.allCases { comboAdd(h, lang.origin[o.rawValue], data: o.rawValue) }
      comboSelect(h, sel)
    }
    let meld = controls[ID.meldKind]!
    let meldSel = max(comboSelected(meld), 0)
    send(meld, CB.resetContent)
    comboAdd(meld, lang.melding[1], data: 1)   // Halcyon
    comboAdd(meld, lang.melding[0], data: 0)   // Juju
    comboSelect(meld, meldSel)
    refreshSkills()
  }

  /// Skills that can roll in the first or second slot for the current charm kind, sorted by name.
  func skillChoices(second: Bool) -> [(id: Int, name: String)] {
    let ids = second ? tables.skill2 : tables.skill1
    return Set(ids).map { (id: $0, name: lang.skill[$0]) }.sorted { compareNames($0.name, $1.name) }
  }

  func refreshSkills() {
    for (id, second, fallback) in [(ID.skill1, false, 71), (ID.skill2, true, 70)] {
      let h = controls[id]!
      // Data is skill ID + 1, with 0 for "(none)".
      let previous = comboData(h) ?? (fallback + 1)
      send(h, CB.resetContent)
      comboAdd(h, "(none)", data: 0)
      for s in skillChoices(second: second) { comboAdd(h, s.name, data: s.id + 1) }
      // Keep the skill if this charm kind can roll it; otherwise clear it.
      if !comboSelectData(h, previous) { comboSelect(h, 0) }
    }
    updateSearchProblem()
  }

  func selectedSkill(_ id: Int) -> Int? {
    guard let d = comboData(controls[id]!), d > 0 else { return nil }
    return d - 1
  }

  /// Why the current Charm Search target can't exist, or nil if it can (or can't be read yet).
  var searchProblem: String? {
    let s1 = selectedSkill(ID.skill1), s2 = selectedSkill(ID.skill2)
    if s1 == nil && s2 == nil { return nil }
    guard let p1 = parseInt(getText(controls[ID.points1]!)), let p2 = parseInt(getText(controls[ID.points2]!)) else { return nil }
    let slots = comboData(controls[ID.searchSlots]!) ?? 0
    let origin = Origin(rawValue: comboData(controls[ID.searchOrigin]!) ?? 0) ?? .melding
    let atLeast = comboData(controls[ID.searchMode]!) == 1
    return tables.impossibleReason(skill1: s1, points1: p1, skill2: s2, points2: p2, slots: slots,
                                   origin: origin, atLeast: atLeast, lang: lang)
  }

  func updateSearchProblem(relayout: Bool = true) {
    guard let warning = searchWarning else { return }
    let text = searchProblem.map { "⚠ " + $0 } ?? ""
    if getText(warning) != text {
      setText(warning, text)
      if relayout && tool == .search { layout(); _ = InvalidateRect(main, nil, true) }
    }
  }

  func updateBaselineEnabled() {
    enable(controls[ID.timeBaseline]!, isChecked(controls[ID.timeUseBaseline]!))
  }

  func applyPreset(_ p: CharmPreset) {
    kind = p.kind
    comboSelectData(kindCombo, p.kind.rawValue)
    refreshSkills()
    comboSelectData(controls[ID.searchMode]!, 0)
    comboSelectData(controls[ID.searchOrigin]!, Origin.melding.rawValue)
    comboSelectData(controls[ID.skill1]!, p.skill1 + 1)
    comboSelectData(controls[ID.skill2]!, p.skill2 + 1)
    setText(controls[ID.points1]!, String(p.points1))
    setText(controls[ID.points2]!, String(p.points2))
    comboSelectData(controls[ID.searchSlots]!, p.slots)
    // Top charms are rare (often tens of millions of frames away), so search far enough to find them.
    let count = controls[ID.searchCount]!
    if (parseInt(getText(count)) ?? 0) < 100_000_000 { setText(count, "100000000") }
    updateSearchProblem()
    status = "Preset: \(p.label(lang)) (\(lang.kinds[p.kind.rawValue]))"
  }

  func showPresetMenu() {
    let m = CreatePopupMenu()
    presetList = []
    for section in PresetSection.allCases {
      _ = withWide(section.rawValue) { AppendMenuW(m, MF.string | MF.grayed, 0, $0) }
      for group in CharmPresets.groups where group.section == section {
        let sub = CreatePopupMenu()
        for p in group.presets {
          let id = ID.presetBase + presetList.count
          presetList.append(p)
          _ = withWide(p.label(lang)) { AppendMenuW(sub, MF.string, UINT_PTR(id), $0) }
        }
        _ = withWide("    " + group.name) { AppendMenuW(m, MF.popup, UINT_PTR(UInt(bitPattern: sub)), $0) }
      }
      if section != PresetSection.allCases.last { _ = AppendMenuW(m, MF.separator, 0, nil) }
    }
    var r = RECT()
    _ = GetWindowRect(controls[ID.presets]!, &r)
    _ = TrackPopupMenu(m, 0, r.left, r.bottom, 0, main, nil)
    _ = DestroyMenu(m)
  }

  // MARK: - Commands

  func command(_ id: Int, _ code: Int) {
    switch id {
    case ID.toolList where code == LB.selChange:
      let i = Int(send(toolList, LB.getCurSel))
      if let t = Tool(rawValue: i), t != tool { selectTool(t) }
    case ID.kind where code == CB.selChange:
      if let d = comboData(kindCombo), let k = CharmKind(rawValue: d) { kind = k; refreshSkills() }
    case ID.language where code == CB.selChange:
      if let d = comboData(langCombo) { language = Language.allCases[d]; refreshLanguage() }
    case ID.showTimer where code == BS.clicked, ID.menuShowTimer:
      showTimer = id == ID.menuShowTimer ? !showTimer : isChecked(showTimerCheck)
      updateTimerVisibility()
    case ID.sendToCalc where code == BS.clicked:
      sendFoundToCalc = isChecked(controls[ID.sendToCalc]!)
    case ID.timeUseBaseline where code == BS.clicked:
      updateBaselineEnabled()
    case ID.skill1, ID.skill2, ID.searchMode, ID.searchSlots, ID.searchOrigin:
      if code == CB.selChange { updateSearchProblem() }
    case ID.points1, ID.points2:
      if code == ES.enChange { updateSearchProblem() }
    case ID.presets where code == BS.clicked: showPresetMenu()
    case ID.run, IDOK:
      // Enter in the tool form runs it; Enter in the timer panel just applies the value typed.
      if id == IDOK, let f = GetFocus(), GetParent(f) == panel.hwnd { panel.commitFocused(); return }
      if !isRunning { run() }
    case ID.stop, IDCANCEL: if isRunning { stop() }
    case ID.copy, ID.menuCopy: copyOutput()
    case ID.clear:
      setText(output, "")
      hasOutput = false
      updateRunState()
    case ID.menuExit: _ = DestroyWindow(main)
    case ID.menuSettings: openSettings()
    case ID.menuPoogie, ID.menuCounter, ID.menuStopwatch, ID.menuResetStopwatch, ID.menuCountdown:
      panel.menuCommand(id)
    case ID.menuAbout:
      let text = "\(appName) \(appVersion) for Windows\n\nCharm RNG tools and snipe timer for Monster Hunter Generations Ultimate, "
        + "based on the mhxx-rng notebook.\n\n\(projectURL)\n\nMIT License."
      _ = withWide(text) { t in withWide("About \(appName)") { MessageBoxW(main, t, $0, 0x40 /* MB_ICONINFORMATION */) } }
    case ID.menuWebsite: openURL(projectURL)
    case ID.presetBase..<(ID.presetBase + 10_000):
      let i = id - ID.presetBase
      if i < presetList.count { applyPreset(presetList[i]) }
    default: break
    }
  }

  func updateTimerVisibility() {
    show(panel.hwnd, showTimer)
    setChecked(showTimerCheck, showTimer)
    setMenuCheck(ID.menuShowTimer, showTimer)
    layout()
    _ = InvalidateRect(main, nil, true)
  }

  func updateRunState() {
    enable(runButton, !isRunning)
    enable(stopButton, isRunning)
    enable(copyButton, hasOutput)
    enable(clearButton, hasOutput)
  }

  func copyOutput() {
    guard hasOutput else { return }
    send(output, ES.setSel, 0, -1)
    send(output, WM.copy)
    send(output, ES.setSel, 0, 0)
    status = "Output copied to the clipboard"
  }

  func openURL(_ url: String) {
    typealias ShellExecuteFn = @convention(c) (HWND?, UnsafePointer<WCHAR>?, UnsafePointer<WCHAR>?,
                                               UnsafePointer<WCHAR>?, UnsafePointer<WCHAR>?, Int32) -> UnsafeMutableRawPointer?
    guard let dll = withWide("shell32.dll", { LoadLibraryW($0) }), let fn = GetProcAddress(dll, "ShellExecuteW") else { return }
    _ = withWide("open") { verb in withWide(url) { unsafeBitCast(fn, to: ShellExecuteFn.self)(main, verb, $0, nil, nil, SW_SHOWNORMAL) } }
  }

  func openSettings() {
    guard settings == nil else { return }
    settings = SettingsWindow(app: self)
  }

  // MARK: - Running tools

  func num(_ id: Int, _ name: String) throws -> Int {
    guard let v = parseInt(getText(controls[id]!)) else { throw FormError(message: "\(name) must be a whole number.") }
    return v
  }

  func run() {
    do {
      try runTool()
    } catch let e as FormError {
      status = e.message
      _ = MessageBeep(0xFFFF_FFFF)
    } catch {
      status = "\(error)"
    }
  }

  private func runTool() throws {
    switch tool {
    case .search:
      let mode = comboData(controls[ID.searchMode]!) ?? 0
      let s1 = selectedSkill(ID.skill1), s2 = selectedSkill(ID.skill2)
      let p1 = try num(ID.points1, "First skill points"), p2 = try num(ID.points2, "Second skill points")
      let slots = comboData(controls[ID.searchSlots]!) ?? 0
      let origin = Origin(rawValue: comboData(controls[ID.searchOrigin]!) ?? 0) ?? .melding
      let start = try num(ID.searchStart, "Start frame"), count = try num(ID.searchCount, "Frames to search")
      if mode == 0 && s1 == nil { status = "Exact search needs a first skill."; return }
      if s1 == nil && s2 == nil { status = "Pick at least one skill."; return }
      if let problem = searchProblem {
        // Don't search for a charm that can't exist; explain why instead.
        let o = Output()
        o.print("Not searched: this charm can't exist.")
        o.print(problem)
        showOutput(o)
        status = "Not searched: this charm can't exist"
        return
      }
      launch(.search, { e in
        let p = try e.parameter(skill1: s1, points1: p1, skill2: s2, points2: p2, slots: slots, origin: origin)
        if mode == 0 { try e.search(start: start, step: count, p) } else { try e.searchGreater(start: start, step: count, p) }
      }, onFound: { [unowned self] frames in
        guard self.sendFoundToCalc, let first = frames.first else { return }
        self.panel.setCalcTarget(first)
        self.status += " · Continue Cycles target set to \(first)" + (frames.count > 1 ? " (first of \(frames.count) found)" : "")
      })
    case .around:
      let frame = try num(ID.aroundFrame, "Frame"), n = try num(ID.aroundNum, "Frames either side")
      let origin = Origin(rawValue: comboData(controls[ID.aroundOrigin]!) ?? 0) ?? .melding
      launch(.around) { e in e.around(frame: frame, num: max(n, 1), origin: origin) }
    case .time:
      let target = try num(ID.timeTarget, "Target frame")
      let useBaseline = isChecked(controls[ID.timeUseBaseline]!)
      let baseline = try useBaseline ? num(ID.timeBaseline, "Baseline frame") : 0
      let frames = target - baseline
      panel.setWaitFrames(frames)
      launch(.time) { e in
        e.out.print("\(frames) frames")
        e.out.print(frameTime(frames))
      }
    case .melding:
      let halcyon = comboData(controls[ID.meldKind]!) == 1
      let frame = try num(ID.meldFrame, "Frame"), rank = comboData(controls[ID.meldRank]!) ?? 4
      launch(.melding) { e in e.meldingPush(frame: frame, halcyon: halcyon, rank: rank) }
    case .sequence:
      let frame = try num(ID.seqFrame, "Start frame"), count = try num(ID.seqCount, "Number of charms")
      launch(.sequence) { e in e.sequenceCharm(frame: frame, count: count) }
    case .fillSlot:
      let fill = comboData(controls[ID.fillFill]!) ?? 20, slots = comboData(controls[ID.fillSlots]!) ?? 3
      let origin = Origin(rawValue: comboData(controls[ID.fillOrigin]!) ?? 0) ?? .melding
      let start = try num(ID.fillStart, "Start frame"), count = try num(ID.fillCount, "Frames to search")
      launch(.fillSlot) { e in try e.searchFillSlot(start: start, step: count, fill: fill, slot: slots, origin: origin) }
    case .combo:
      let text = getText(controls[ID.comboText]!).replacingCRLF()
      let start = try num(ID.comboStart, "Start frame"), count = try num(ID.comboCount, "Frames to search")
      launch(.combo) { e in
        try e.searchCombo(start: start, step: count, combo: text)
        try e.checkCombo(start: start, step: count, combo: text)
      }
    case .reward:
      let tableText = getText(controls[ID.rewardTable]!), seq = getText(controls[ID.rewardSeq]!).replacingCRLF()
      let bonus = try num(ID.rewardBonus, "Bonus threshold")
      let start = try num(ID.rewardStart, "Start frame"), count = try num(ID.rewardCount, "Frames to search")
      var table: [(String, Int)] = []
      for part in tableText.split(whereSeparator: { $0.isWhitespace || $0 == "," }) {
        let kv = part.split(separator: ":")
        guard kv.count == 2, let v = Int(kv[1]) else {
          throw FormError(message: "Reward table entries must look like Name:threshold (got \"\(part)\").")
        }
        table.append((String(kv[0]), v))
      }
      let t = table
      launch(.reward) { e in try e.searchReward(start: start, step: count, bonusTh: bonus, target: seq, table: t) }
    case .dump:
      let frame = try num(ID.dumpFrame, "Frame"), count = try num(ID.dumpCount, "Frames to show")
      let showAll = isChecked(controls[ID.dumpShowAll]!)
      launch(.dump) { e in try e.allPush(frame: frame, count: count, showAll: showAll) }
    }
  }

  /// Run `job` on a background task; the result comes back as `jobDoneMessage`.
  func launch(_ t: Tool, _ job: @escaping @Sendable (inout Engine) throws -> Void, onFound: (([Int]) -> Void)? = nil) {
    task?.cancel()
    generation += 1
    var opts = Options()
    opts.language = language
    opts.numOfCharms = numOfCharms
    opts.showAllRank = showAllRank
    opts.showRare = showRare
    let kind = self.kind, gen = generation, title = t.runName, window = Int(bitPattern: main)
    self.onFound = onFound
    isRunning = true
    status = "Running \(title)…"
    updateRunState()
    task = Task.detached(priority: .userInitiated) {
      let started = now()
      let out = Output()
      var engine = Engine(kind: kind, options: opts, out: out)
      var note: String?
      do {
        try job(&engine)
      } catch is CancellationError {
        note = "Stopped"
      } catch {
        out.print("Error: \(error)")
        note = "Error"
      }
      if out.lines.allSatisfy({ $0.isEmpty }) { out.write("No results.") }
      if out.truncated { out.print("… output truncated at \(out.maxLines) lines") }
      let result = JobResult(generation: gen, rtf: RTFRenderer.render(out, language: opts.language),
                             plainText: out.plainText, found: out.foundFrames, note: note,
                             seconds: now() - started, title: title)
      let ptr = Unmanaged.passRetained(result).toOpaque()
      _ = PostMessageW(HWND(bitPattern: window), App.jobDoneMessage, 0, LPARAM(Int(bitPattern: ptr)))
    }
  }

  func jobDone(_ r: JobResult) {
    guard r.generation == generation else { return }   // an older, replaced run
    trace("jobDone: \(r.rtf.count) bytes of RTF")
    isRunning = false
    setRTF(r.rtf)
    trace("jobDone: RTF set")
    lastPlainText = r.plainText
    hasOutput = true
    status = (r.note ?? "Done") + " · \(r.title) · \(fixed(r.seconds, 2))s"
    onFound?(r.found)
    onFound = nil
    updateRunState()
    if smokeDir != nil { smokeStepDone() }
  }

  func stop() {
    task?.cancel()
  }

  func showOutput(_ o: Output) {
    setRTF(RTFRenderer.render(o, language: language))
    lastPlainText = o.plainText
    hasOutput = true
    updateRunState()
  }

  func setRTF(_ rtf: [UInt8]) {
    var bytes = rtf
    bytes.append(0)
    var settings: [UInt32] = [0 /* ST_DEFAULT */, 0 /* CP_ACP */]
    settings.withUnsafeMutableBufferPointer { st in
      bytes.withUnsafeBufferPointer { b in
        _ = send(output, RE.setTextEx, WPARAM(UInt(bitPattern: st.baseAddress)), LPARAM(Int(bitPattern: b.baseAddress)))
      }
    }
    send(output, WM.vScroll, 6 /* SB_TOP */, 0)
  }

  // MARK: - Window messages

  func handle(_ h: HWND, _ msg: UINT, _ wp: WPARAM, _ lp: LPARAM) -> LRESULT {
    if msg == WM.command || msg >= WM.app || msg == WM.timer || msg == WM.destroy {
      trace("msg \(msg) wp \(wp) lp \(lp) to \(h == main ? "main" : (panel != nil && h == panel.hwnd ? "panel" : "other"))")
    }
    switch msg {
    case WM.command:
      if let s = settings, h == s.hwnd { s.command(lo(wp), hi(wp)); return 0 }
      if let p = panel, h == p.hwnd { if ready { p.command(lo(wp), hi(wp)) }; return 0 }
      if h == main { if ready { command(lo(wp), hi(wp)) }; return 0 }
    case WM.ctlColorStatic:
      // Labels paint a solid background (otherwise themed labels draw their text without
      // clearing what was there, which leaves traces when they move or change).
      let dc = HDC(bitPattern: UInt(wp))
      if let color = textColors[Int(lp)] { _ = SetTextColor(dc, color) }
      _ = SetBkColor(dc, GetSysColor(COLOR_BTNFACE))
      return handleToLRESULT(GetSysColorBrush(COLOR_BTNFACE))
    case 0x002B /* WM_DRAWITEM */:
      if let p = panel, h == p.hwnd, p.drawItem(lp) { return 1 }
    case WM.size:
      if h == main { layout(); return 0 }
      if let p = panel, h == p.hwnd { p.layout(); return 0 }
    case WM.getMinMaxInfo where h == main:
      if let info = UnsafeMutablePointer<MINMAXINFO>(bitPattern: Int(lp)) {
        info.pointee.ptMinTrackSize.x = LONG(UI.px(showTimer ? 1020 : 680))
        info.pointee.ptMinTrackSize.y = LONG(UI.px(560))
      }
      return 0
    case WM.timer:
      if let p = panel, h == p.hwnd { p.tick(); return 0 }
      if h == main { smokeTimer(Int(wp)); return 0 }
    case WM.vScroll, WM.mouseWheel:
      if let p = panel, h == p.hwnd { p.scroll(msg, wp); return 0 }
    case WM.close:
      if let s = settings, h == s.hwnd { s.close(); return 0 }
    case WM.destroy where h == main:
      task?.cancel()
      _ = SetThreadExecutionState(0x8000_0000)   // ES_CONTINUOUS: let the PC sleep again
      PostQuitMessage(0)
      return 0
    case App.jobDoneMessage:
      if let ptr = UnsafeMutableRawPointer(bitPattern: Int(lp)) {
        jobDone(Unmanaged<JobResult>.fromOpaque(ptr).takeRetainedValue())
      }
      return 0
    case BeepScheduler.doneMessage:
      panel?.beepsDone(channel: Int(wp), generation: Int(lp))
      return 0
    case App.smokeMessage:
      smokeStart()
      return 0
    default:
      break
    }
    return DefWindowProcW(h, msg, wp, lp)
  }

  // MARK: - Smoke test

  private func smokeStart() {
    smokeQueue = Tool.allCases
    smokeNext()
  }

  private func smokeNext() {
    guard let t = smokeQueue.first else {
      // Exercise the timers, then take a screenshot with them running.
      panel.menuCommand(ID.menuStopwatch)
      panel.menuCommand(ID.menuCounter)
      _ = SetTimer(main, 2, 1500, nil)
      return
    }
    trace("smoke: \(t.title)")
    selectTool(t)
    trace("smoke: selected")
    run()
    trace("smoke: launched, status \(status)")
  }

  private func smokeStepDone() {
    smokeLog += "== \(tool.title) ==\n\(lastPlainText)\n-- \(status)\n\n"
    trace("smoke: done \(tool.title): \(status)")
    if tool == .search { saveScreenshot(main, smokeDir! + "\\search.bmp"); trace("smoke: screenshot saved") }
    smokeQueue.removeFirst()
    smokeNext()
  }

  private func smokeTimer(_ id: Int) {
    _ = KillTimer(main, UINT_PTR(id))
    guard id == 2, let dir = smokeDir else { return }
    trace("smoke: timer screenshot")
    saveScreenshot(main, dir + "\\timer.bmp")
    // Scroll the timer panel a step at a time to the bottom (as the mouse wheel does) and check it.
    for _ in 0..<20 { send(panel.hwnd, WM.vScroll, 1 /* SB_LINEDOWN */, 0) }
    saveScreenshot(main, dir + "\\timer-scrolled.bmp")
    smokeLog += "== Timer ==\n" + panel.describe() + "\n"
    panel.menuCommand(ID.menuCounter)
    panel.menuCommand(ID.menuStopwatch)
    trace("smoke: writing log")
    writeFile(dir + "\\smoke.txt", Array(smokeLog.utf8))
    _ = DestroyWindow(main)
  }
}

extension String {
  /// Edit controls use CRLF line breaks; the engine expects "\n".
  func replacingCRLF() -> String {
    String(unicodeScalars.filter { $0 != "\r" }.map(Character.init))
  }
}

/// Compare skill names the way Explorer sorts (ignoring case, numbers by value).
func compareNames(_ a: String, _ b: String) -> Bool {
  let r = withWide(a) { pa in
    withWide(b) { pb in
      CompareStringEx(nil, 0x8 /* SORT_DIGITSASNUMBERS */ | 0x1 /* NORM_IGNORECASE */, pa, -1, pb, -1, nil, nil, 0)
    }
  }
  return r == 0 ? a < b : r == 1   // CSTR_LESS_THAN
}

/// Save a window's image as a 32-bit .bmp (smoke test).
func saveScreenshot(_ hwnd: HWND, _ path: String) {
  _ = RedrawWindow(hwnd, nil, nil, 0x0001 | 0x0004 | 0x0080 | 0x0100)   // INVALIDATE|ERASE|ALLCHILDREN|UPDATENOW
  var r = RECT()
  _ = GetWindowRect(hwnd, &r)
  let w = Int(r.right - r.left), h = Int(r.bottom - r.top)
  guard w > 0, h > 0, let screen = GetDC(nil), let dc = CreateCompatibleDC(screen) else { return }
  defer { _ = ReleaseDC(nil, screen); _ = DeleteDC(dc) }
  var info = BITMAPINFO()
  info.bmiHeader.biSize = DWORD(MemoryLayout<BITMAPINFOHEADER>.size)
  info.bmiHeader.biWidth = LONG(w)
  info.bmiHeader.biHeight = -LONG(h)
  info.bmiHeader.biPlanes = 1
  info.bmiHeader.biBitCount = 32
  var bits: UnsafeMutableRawPointer?
  guard let bmp = CreateDIBSection(dc, &info, 0, &bits, nil, 0), let bits else { return }
  defer { _ = DeleteObject(UnsafeMutableRawPointer(bmp)) }
  let old = SelectObject(dc, UnsafeMutableRawPointer(bmp))
  _ = PrintWindow(hwnd, dc, 2 /* PW_RENDERFULLCONTENT */)
  _ = SelectObject(dc, old)
  let size = w * h * 4
  var file: [UInt8] = []
  func u16(_ v: Int) { file += [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
  func u32(_ v: Int) { u16(v & 0xFFFF); u16((v >> 16) & 0xFFFF) }
  file += [0x42, 0x4D]; u32(54 + size); u32(0); u32(54)
  u32(40); u32(w); u32(-h & 0xFFFF_FFFF); u16(1); u16(32); u32(0); u32(size); u32(2835); u32(2835); u32(0); u32(0)
  file += UnsafeRawBufferPointer(start: bits, count: size)
  writeFile(path, file)
}
