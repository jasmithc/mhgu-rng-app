// The snipe timer panel: Continue Cycles calculator, continue counter (metronome), stopwatch and
// final countdown. The maths comes from RNGCore (SnipeMath.swift); this file holds the state,
// the controls and the Windows-specific parts (clock, beeps, keeping the PC awake).
import RNGCore
import WinSDK

final class TimerPanel {
  let hwnd: HWND
  unowned let app: App

  // MARK: State (saved under the same names as the macOS app)

  var calcTarget: Int { didSet { Prefs.set("timer.calcTarget", calcTarget); syncCounterTarget() } }
  var poogie: Bool { didSet { Prefs.set("timer.poogie", poogie); syncCounterTarget() } }
  var bpm: Int { didSet { Prefs.set("timer.bpm", bpm); syncCounterTarget() } }
  var calc: ContinueCalc { ContinueCalc(target: calcTarget, poogie: poogie, bpm: Double(bpm)) }

  var counterTarget = 0
  var counterStart: Double?
  var counterBpm = Int(SnipeMath.bpm)
  var counterRunning = false
  var counterFinished = false
  var counterGeneration = 0

  var swStart: Double?
  var swAccumulated = 0.0
  var swRunning: Bool { swStart != nil }

  var waitText: String { didSet { Prefs.set("timer.waitText", waitText) } }
  var correction: Double { didSet { Prefs.set("timer.correction", correction) } }
  var correctionInFrames: Bool { didSet { Prefs.set("timer.correctionUnit", correctionInFrames ? "frames" : "seconds") } }
  var cdEnd: Double?
  var cdTotal = 0.0
  var cdUsedStopwatch = 0.0
  var cdRunning = false
  var cdFinished = false
  var cdError: String?
  var cdGeneration = 0

  // MARK: Controls

  enum C {
    static let target = 400, poogie = 401
    static let counterTarget = 410, counterStart = 411, counterReset = 412, pace = 413
    static let paceDown = 414, paceUp = 415, paceReset = 416
    static let swStart = 420, swReset = 421
    static let wait = 430, correction = 431, correctionUnit = 432, cdStart = 433, cdReset = 434
  }

  private var c: [Int: HWND] = [:]           // inputs and buttons by ID
  private var l: [String: HWND] = [:]        // labels by name
  private var cache: [Int: String] = [:]     // last text set on each label (avoids flicker)
  private var colors: [Int: COLORREF] = [:]  // last colour per readout
  private var suppress = false               // ignore EN_CHANGE caused by our own SetWindowText
  private var scrollPos = 0
  private var contentHeight = 0
  private var ticking = false
  private var awake = false

  private static let gray = rgb(100, 100, 100), red = rgb(200, 40, 40), orange = rgb(200, 100, 0), green = rgb(30, 150, 60)

  init(parent: HWND, app: App) {
    self.app = app
    hwnd = createWindow(panelClassName, style: WS.child | WS.visible | WS.vScroll | WS.clipChildren,
                        ex: WS.exControlParent, parent: parent)
    let t = Prefs.int("timer.calcTarget") ?? 300_000
    calcTarget = t
    poogie = Prefs.bool("timer.poogie") ?? false
    let r = SnipeMath.bpmRange
    bpm = min(max(Prefs.int("timer.bpm") ?? Int(SnipeMath.bpm), r.lowerBound), r.upperBound)
    waitText = Prefs.string("timer.waitText") ?? "0d 0h 2m 37s 13f"
    correction = Prefs.double("timer.correction") ?? 0
    correctionInFrames = Prefs.string("timer.correctionUnit") == "frames"
    counterTarget = calc.neededWhole
    trace("panel: building")
    build()
    trace("panel: built")
    refresh()
    trace("panel: refreshed")
  }

  // MARK: Building

  private func label(_ name: String, _ text: String = "", font: HFONT? = UI.font, align: DWORD = SS.left,
                     color: COLORREF? = nil) -> HWND {
    let h = createWindow("STATIC", text, style: WS.child | WS.visible | align | SS.noPrefix, parent: hwnd)
    setFont(h, font)
    if let color { app.textColors[Int(bitPattern: h)] = color }
    l[name] = h
    cache[Int(bitPattern: h)] = text
    return h
  }

  private func input(_ id: Int, _ text: String, mono: Bool = false, align: DWORD = ES.right) -> HWND {
    let h = createWindow("EDIT", text, style: WS.child | WS.visible | WS.tabStop | ES.autoHScroll | align,
                         ex: WS.exClientEdge, parent: hwnd, id: id)
    setFont(h, mono ? UI.mono : UI.font)
    send(h, ES.setMargins, 3, LPARAM(UI.px(3) | (UI.px(3) << 16)))
    c[id] = h
    return h
  }

  private func button(_ id: Int, _ text: String) -> HWND {
    let h = createWindow("BUTTON", text, style: WS.child | WS.visible | WS.tabStop, parent: hwnd, id: id)
    setFont(h, UI.font)
    c[id] = h
    return h
  }

  private func line(_ name: String) {
    l[name] = createWindow("STATIC", style: WS.child | WS.visible | SS.etchedHorz, parent: hwnd)
  }

  private func build() {
    // Continue Cycles
    _ = label("h.calc", "Continue Cycles", font: UI.bold)
    line("line.calc")
    _ = label("calc.targetLabel", "Target frame")
    _ = input(C.target, String(calcTarget))
    _ = label("calc.error", "", color: TimerPanel.red)
    for (name, text) in [("advances", "Advances (2 min to spare)"), ("time", "Time at 60 BPM"), ("frames", "Frames advanced meanwhile"),
                         ("poogieRow", "Poogie in room")] {
      _ = label("calc.\(name)Label", text, color: TimerPanel.gray)
      _ = label("calc.\(name)", "", align: SS.right)
    }
    let pg = createWindow("BUTTON", "Poogie? (it's in your room: do 5 fewer cycles)",
                          style: WS.child | WS.visible | WS.tabStop | BS.autoCheckBox, parent: hwnd, id: C.poogie)
    setFont(pg, UI.font)
    setChecked(pg, poogie)
    c[C.poogie] = pg
    _ = label("calc.neededLabel", "Continue cycles needed", font: UI.bold)
    _ = label("calc.needed", "", font: UI.bold, align: SS.right)
    _ = label("calc.caption", "", font: UI.small, color: TimerPanel.gray)

    // Continue Counter
    _ = label("h.counter", "Continue Counter", font: UI.bold)
    line("line.counter")
    _ = label("counter.readout", "", font: UI.readout, align: SS.center)
    _ = label("counter.targetLabel", "Target")
    _ = input(C.counterTarget, String(counterTarget))
    _ = button(C.counterStart, "Start")
    _ = button(C.counterReset, "Reset")
    _ = label("counter.paceLabel", "Pace")
    _ = input(C.pace, String(bpm))
    _ = button(C.paceDown, "−5")
    _ = button(C.paceUp, "+5")
    _ = label("counter.bpm", "BPM", color: TimerPanel.gray)
    _ = button(C.paceReset, "Reset to 60")
    _ = label("counter.caption", "Continue presses per minute (\(SnipeMath.bpmRange.lowerBound)–\(SnipeMath.bpmRange.upperBound)). The calculator above uses the same pace.",
              font: UI.small, color: TimerPanel.gray)
    _ = label("counter.warning", "", font: UI.small, color: TimerPanel.orange)

    // Stopwatch
    _ = label("h.sw", "Stopwatch", font: UI.bold)
    line("line.sw")
    _ = label("sw.readout", "", font: UI.readout, align: SS.center)
    _ = button(C.swStart, "Start")
    _ = button(C.swReset, "Reset")
    _ = label("sw.hint", "Ctrl+Shift+S", font: UI.small, align: SS.right, color: TimerPanel.gray)
    _ = label("sw.caption", "Start it when you press Combine; it's subtracted from the countdown.", font: UI.small, color: TimerPanel.gray)

    // Final Countdown
    _ = label("h.cd", "Final Countdown", font: UI.bold)
    line("line.cd")
    _ = label("cd.waitTitle", "Wait time (from Frame → Wait Time)")
    _ = input(C.wait, waitText, mono: true, align: ES.left)
    _ = label("cd.correctionLabel", "Correction")
    _ = input(C.correction, correction == 0 ? "0" : String(correction))
    let unit = createWindow("COMBOBOX", style: WS.child | WS.visible | WS.tabStop | CB.dropDownList, parent: hwnd,
                            id: C.correctionUnit, h: Int32(UI.px(200)))
    setFont(unit, UI.font)
    comboAdd(unit, "seconds", data: 0)
    comboAdd(unit, "frames", data: 1)
    comboSelect(unit, correctionInFrames ? 1 : 0)
    c[C.correctionUnit] = unit
    _ = label("cd.correctionCaption", "+ waits longer, − shorter.", font: UI.small, color: TimerPanel.gray)
    for (name, text) in [("wait", "Wait time"), ("sw", "− Stopwatch"), ("corr", "+ Correction")] {
      _ = label("cd.\(name)Label", text, color: TimerPanel.gray)
      _ = label("cd.\(name)", "", align: SS.right)
    }
    line("line.cdSum")
    _ = label("cd.totalLabel", "= Countdown", font: UI.bold)
    _ = label("cd.total", "", font: UI.bold, align: SS.right)
    _ = label("cd.readout", "", font: UI.readout, align: SS.center)
    _ = label("cd.frames", "", font: UI.small, align: SS.center, color: TimerPanel.gray)
    _ = label("cd.error", "", font: UI.small, color: TimerPanel.red)
    _ = button(C.cdStart, "Start Countdown")
    _ = button(C.cdReset, "Reset")
    _ = label("cd.hint", "Ctrl+Shift+Enter", font: UI.small, align: SS.right, color: TimerPanel.gray)
    _ = label("cd.caption", "Beeps each of the last 10 seconds, then a long beep at zero. Starting it stops the stopwatch.",
              font: UI.small, color: TimerPanel.gray)
  }

  // MARK: Layout (with vertical scrolling when the window is short)

  func layout() {
    let (W, H) = clientSize(hwnd)
    let pad = UI.px(14)
    let x0 = pad, cw = W - 2 * pad
    var y = UI.px(12) - scrollPos
    let rowH = UI.px(23), gap = UI.px(6)

    func header(_ name: String, _ line: String) {
      moveWindow(l[name]!, x0, y, cw, UI.px(18))
      y += UI.px(21)
      moveWindow(l[line]!, x0, y, cw, 2)
      y += UI.px(8)
    }
    /// Label on the left, control(s) on the right of a row.
    func pair(_ label: String, _ right: HWND, width: Int) {
      moveWindow(l[label]!, x0, y + (rowH - UI.px(16)) / 2, cw - width - UI.px(8), UI.px(18))
      moveWindow(right, x0 + cw - width, y, width, rowH)
      y += rowH + gap
    }
    /// A label/value line.
    func result(_ name: String) {
      // Label and value side by side, not overlapping (a static paints its whole rectangle).
      let valueW = UI.px(112)
      moveWindow(l["\(name)Label"]!, x0, y, cw - valueW - UI.px(4), UI.px(18))
      moveWindow(l[name]!, x0 + cw - valueW, y, valueW, UI.px(18))
      y += UI.px(20)
    }
    /// Wrapping text; takes no space when empty.
    func text(_ name: String, font: HFONT? = UI.small) {
      let h = l[name]!
      let s = cache[Int(bitPattern: h)] ?? ""
      if s.isEmpty { moveWindow(h, x0, y, cw, 0); return }
      let th = textHeight(s, font: font, width: cw, reference: hwnd)
      moveWindow(h, x0, y, cw, th)
      y += th + gap
    }
    func readout(_ name: String) {
      moveWindow(l[name]!, x0, y, cw, UI.px(40))
      y += UI.px(44)
    }

    header("h.calc", "line.calc")
    pair("calc.targetLabel", c[C.target]!, width: UI.px(120))
    text("calc.error", font: UI.font)
    for name in ["calc.advances", "calc.time", "calc.frames"] { result(name) }
    moveWindow(c[C.poogie]!, x0, y, cw, UI.px(20)); y += UI.px(24)
    if poogie { result("calc.poogieRow") } else {
      moveWindow(l["calc.poogieRowLabel"]!, 0, 0, 0, 0); moveWindow(l["calc.poogieRow"]!, 0, 0, 0, 0)
    }
    result("calc.needed")
    text("calc.caption")
    y += UI.px(10)

    header("h.counter", "line.counter")
    readout("counter.readout")
    let bw = UI.px(64)
    moveWindow(l["counter.targetLabel"]!, x0, y + (rowH - UI.px(16)) / 2, UI.px(50), UI.px(18))
    moveWindow(c[C.counterTarget]!, x0 + UI.px(52), y, cw - UI.px(52) - 2 * (bw + gap), rowH)
    moveWindow(c[C.counterStart]!, x0 + cw - 2 * bw - gap, y - 1, bw, rowH + 2)
    moveWindow(c[C.counterReset]!, x0 + cw - bw, y - 1, bw, rowH + 2)
    y += rowH + gap
    moveWindow(l["counter.paceLabel"]!, x0, y + (rowH - UI.px(16)) / 2, UI.px(50), UI.px(18))
    var x = x0 + UI.px(52)
    moveWindow(c[C.pace]!, x, y, UI.px(48), rowH); x += UI.px(52)
    moveWindow(c[C.paceDown]!, x, y - 1, UI.px(32), rowH + 2); x += UI.px(34)
    moveWindow(c[C.paceUp]!, x, y - 1, UI.px(32), rowH + 2); x += UI.px(38)
    moveWindow(l["counter.bpm"]!, x, y + (rowH - UI.px(16)) / 2, UI.px(30), UI.px(18))
    moveWindow(c[C.paceReset]!, x0 + cw - UI.px(84), y - 1, UI.px(84), rowH + 2)
    y += rowH + gap
    text("counter.caption")
    text("counter.warning")
    y += UI.px(10)

    header("h.sw", "line.sw")
    readout("sw.readout")
    moveWindow(c[C.swStart]!, x0, y, UI.px(90), rowH + 2)
    moveWindow(c[C.swReset]!, x0 + UI.px(96), y, bw, rowH + 2)
    moveWindow(l["sw.hint"]!, x0 + cw / 2, y + UI.px(5), cw - cw / 2, UI.px(16))
    y += rowH + 2 + gap
    text("sw.caption")
    y += UI.px(10)

    header("h.cd", "line.cd")
    moveWindow(l["cd.waitTitle"]!, x0, y, cw, UI.px(18)); y += UI.px(20)
    moveWindow(c[C.wait]!, x0, y, cw, rowH); y += rowH + gap
    moveWindow(l["cd.correctionLabel"]!, x0, y + (rowH - UI.px(16)) / 2, UI.px(80), UI.px(18))
    moveWindow(c[C.correction]!, x0 + UI.px(82), y, UI.px(70), rowH)
    moveWindow(c[C.correctionUnit]!, x0 + UI.px(158), y, UI.px(100), UI.px(200))
    y += rowH + UI.px(2)
    moveWindow(l["cd.correctionCaption"]!, x0, y, cw, UI.px(16)); y += UI.px(22)
    for name in ["cd.wait", "cd.sw", "cd.corr"] { result(name) }
    moveWindow(l["line.cdSum"]!, x0, y, cw, 2); y += UI.px(4)
    result("cd.total")
    readout("cd.readout")
    moveWindow(l["cd.frames"]!, x0, y - UI.px(4), cw, UI.px(16)); y += UI.px(16)
    text("cd.error")
    moveWindow(c[C.cdStart]!, x0, y, UI.px(120), rowH + 2)
    moveWindow(c[C.cdReset]!, x0 + UI.px(126), y, bw, rowH + 2)
    moveWindow(l["cd.hint"]!, x0 + UI.px(126) + bw, y + UI.px(5), cw - UI.px(126) - bw, UI.px(16))
    y += rowH + 2 + gap
    text("cd.caption")
    y += UI.px(8)

    // Scroll bar
    contentHeight = y + scrollPos
    var info = SCROLLINFO()
    info.cbSize = UINT(MemoryLayout<SCROLLINFO>.size)
    info.fMask = 0x1 | 0x2 | 0x4 | 0x8   // RANGE | PAGE | POS | DISABLENOSCROLL
    info.nMin = 0
    info.nMax = Int32(contentHeight)
    info.nPage = UINT(max(H, 0))
    info.nPos = Int32(scrollPos)
    _ = SetScrollInfo(hwnd, 1 /* SB_VERT */, &info, true)
    let maxPos = max(0, contentHeight - H)
    if scrollPos > maxPos { scrollPos = maxPos; layout() }
  }

  func scroll(_ msg: UINT, _ wp: WPARAM) {
    let (_, H) = clientSize(hwnd)
    var pos = scrollPos
    if msg == WM.mouseWheel {
      let delta = Int(Int16(truncatingIfNeeded: hi(wp)))
      pos -= delta * UI.px(48) / 120
    } else {
      switch lo(wp) {
      case 0: pos -= UI.px(20)                         // SB_LINEUP
      case 1: pos += UI.px(20)                         // SB_LINEDOWN
      case 2: pos -= H                                 // SB_PAGEUP
      case 3: pos += H                                 // SB_PAGEDOWN
      case 4, 5: pos = hi(wp)                          // SB_THUMBPOSITION, SB_THUMBTRACK
      case 6: pos = 0                                  // SB_TOP
      case 7: pos = contentHeight                      // SB_BOTTOM
      default: return
      }
    }
    pos = max(0, min(pos, max(0, contentHeight - H)))
    if pos != scrollPos {
      scrollPos = pos
      layout()
      _ = InvalidateRect(hwnd, nil, true)
    }
  }

  // MARK: Refreshing the labels

  private func set(_ name: String, _ text: String) {
    guard let h = l[name] else { return }
    let key = Int(bitPattern: h)
    if cache[key] != text { cache[key] = text; setText(h, text) }
  }

  private func setColor(_ name: String, _ color: COLORREF?) {
    guard let h = l[name] else { return }
    let key = Int(bitPattern: h)
    if app.textColors[key] != color {
      app.textColors[key] = color
      _ = InvalidateRect(h, nil, true)
    }
  }

  private func setInput(_ id: Int, _ text: String) {
    guard let h = c[id], getText(h) != text else { return }
    suppress = true
    setText(h, text)
    suppress = false
  }

  /// Update everything shown from the current state. Re-lays out if a wrapping text changed.
  func refresh() {
    let before = ["calc.error", "counter.warning", "cd.error"].map { cache[Int(bitPattern: l[$0]!)] ?? "" }
    let calcValid = calcTarget > 3600
    let k = calc
    set("calc.error", calcValid ? "" : "The target frame must be above 3600.")
    set("calc.advances", calcValid ? fixed(k.advancesWithSpare, 2) : "—")
    set("calc.timeLabel", "Time at \(bpm) BPM")
    set("calc.time", calcValid ? SnipeMath.clockString(k.minutes * 60) : "—")
    set("calc.frames", calcValid ? fixed(k.framesAdvanced, 1) : "—")
    set("calc.poogieRow", "−\(ContinueCalc.poogieCycles)")
    set("calc.needed", calcValid ? "\(fixed(k.needed, 2)) → \(k.neededWhole)" : "—")
    set("calc.caption", poogie ? "Rounded down, minus 5 cycles to remove Poogie. Sets the counter target."
                               : "Rounded down so you don't overshoot. Sets the counter target.")
    set("h.counter", "Continue Counter · \(bpm) BPM")
    set("counter.warning", bpm > SnipeMath.reliableMaxBpm
        ? "⚠ Above \(SnipeMath.reliableMaxBpm) BPM the next screen may not finish loading in time: a B press can be missed and the following A press confirms instead."
        : "")
    setText(c[C.counterStart]!, counterRunning ? "Stop" : "Start")
    for id in [C.counterTarget, C.pace, C.paceDown, C.paceUp, C.paceReset] { enable(c[id]!, !counterRunning) }
    enable(c[C.counterStart]!, counterRunning || counterTarget > 0)
    show(c[C.paceReset]!, bpm != Int(SnipeMath.bpm))
    setText(c[C.swStart]!, swRunning ? "Stop" : "Start")
    enable(c[C.swReset]!, !swRunning)
    setText(c[C.cdStart]!, cdRunning ? "Cancel" : "Start Countdown")
    show(c[C.cdReset]!, !cdRunning && (cdFinished || cdEnd != nil))
    for id in [C.wait, C.correction, C.correctionUnit] { enable(c[id]!, !cdRunning) }
    set("cd.error", cdError ?? "")
    tick()
    let after = ["calc.error", "counter.warning", "cd.error"].map { cache[Int(bitPattern: l[$0]!)] ?? "" }
    if before != after { layout(); _ = InvalidateRect(hwnd, nil, true) }
    updateTicker()
  }

  /// Update the clocks (called ~60 times a second while something is running).
  func tick() {
    let t = now()
    set("counter.readout", "\(counterValue(at: t)) / \(counterTarget)")
    setColor("counter.readout", counterFinished ? TimerPanel.green : nil)
    set("sw.readout", SnipeMath.clockString(swElapsed(at: t)))

    let wait = waitFrames.map { Double($0) / SnipeMath.fps }
    set("cd.wait", wait.map(SnipeMath.clockString) ?? "invalid")
    set("cd.sw", SnipeMath.clockString(cdEnd != nil ? cdUsedStopwatch : swElapsed(at: t)))
    set("cd.corr", SnipeMath.clockString(correctionSeconds))
    set("cd.total", cdEnd != nil ? SnipeMath.clockString(cdTotal) : (plannedTotal(at: t).map(SnipeMath.clockString) ?? "—"))
    let remaining = cdRemaining(at: t)
    set("cd.readout", SnipeMath.clockString(remaining))
    setColor("cd.readout", cdFinished ? TimerPanel.green : (cdRunning && remaining <= 10 ? TimerPanel.orange : nil))
    set("cd.frames", "\(fixed((remaining * SnipeMath.fps).rounded(.up), 0)) frames")
  }

  private func updateTicker() {
    let busy = counterRunning || swRunning || cdRunning
    if busy != ticking {
      ticking = busy
      if busy { _ = SetTimer(hwnd, 1, 15, nil) } else { _ = KillTimer(hwnd, 1) }
    }
    // Keep the PC and display awake while the metronome or countdown runs.
    let needAwake = counterRunning || cdRunning
    if needAwake != awake {
      awake = needAwake
      // ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED, or just ES_CONTINUOUS to release.
      _ = SetThreadExecutionState(needAwake ? 0x8000_0003 : 0x8000_0000)
    }
  }

  // MARK: Commands

  func command(_ id: Int, _ code: Int) {
    switch id {
    case C.target where code == ES.enChange && !suppress:
      if let v = parseInt(getText(c[C.target]!)) { calcTarget = v; refresh() }
    case C.poogie where code == BS.clicked:
      poogie = isChecked(c[C.poogie]!)
      app.setMenuCheck(ID.menuPoogie, poogie)
      layout(); refresh()
    case C.counterTarget where code == ES.enChange && !suppress:
      if let v = parseInt(getText(c[C.counterTarget]!)) { counterTarget = max(0, v); refresh() }
    case C.pace where code == ES.enChange && !suppress:
      // A valid pace applies as you type; anything else waits until you leave the box or start.
      if let v = parseInt(getText(c[C.pace]!)), SnipeMath.bpmRange.contains(v), v != bpm { bpm = v; refresh() }
    case C.pace where code == ES.enKillFocus:
      commitPace()
    case C.paceDown, C.paceUp:
      setPace(bpm + (id == C.paceUp ? 5 : -5))
    case C.paceReset: setPace(Int(SnipeMath.bpm))
    case C.counterStart: counterRunning ? stopCounter() : startCounter()
    case C.counterReset: resetCounter()
    case C.swStart: toggleStopwatch()
    case C.swReset: resetStopwatch()
    case C.wait where code == ES.enChange && !suppress:
      waitText = getText(c[C.wait]!); refresh()
    case C.correction where code == ES.enChange && !suppress:
      if let v = parseDouble(getText(c[C.correction]!)) { correction = v; refresh() }
    case C.correctionUnit where code == CB.selChange:
      correctionInFrames = comboData(c[C.correctionUnit]!) == 1; refresh()
    case C.cdStart: cdRunning ? cancelCountdown() : startCountdown()
    case C.cdReset: cancelCountdown()
    default: break
    }
  }

  /// Menu and keyboard-shortcut versions of the panel's buttons.
  func menuCommand(_ id: Int) {
    switch id {
    case ID.menuPoogie:
      poogie.toggle()
      setChecked(c[C.poogie]!, poogie)
      app.setMenuCheck(ID.menuPoogie, poogie)
      layout(); refresh()
    case ID.menuCounter: counterRunning ? stopCounter() : startCounter()
    case ID.menuStopwatch: toggleStopwatch()
    case ID.menuResetStopwatch: if !swRunning { resetStopwatch() }
    case ID.menuCountdown: cdRunning ? cancelCountdown() : startCountdown()
    default: break
    }
  }

  /// Enter pressed in one of the panel's boxes: apply what's typed.
  func commitFocused() {
    if GetFocus() == c[C.pace] { commitPace() }
  }

  private func setPace(_ v: Int) {
    let r = SnipeMath.bpmRange
    bpm = min(max(v, r.lowerBound), r.upperBound)
    setInput(C.pace, String(bpm))
    refresh()
  }

  private func commitPace() {
    setPace(parseInt(getText(c[C.pace]!)) ?? bpm)
  }

  /// The calculator's result becomes the counter's target (not while it's counting).
  private func syncCounterTarget() {
    guard !counterRunning, c[C.counterTarget] != nil else { return }
    counterTarget = calc.neededWhole
    setInput(C.counterTarget, String(counterTarget))
  }

  func setCalcTarget(_ frame: Int) {
    calcTarget = frame
    setInput(C.target, String(frame))
    refresh()
  }

  /// Fill in the wait time from a frame count (used by the Frame → Wait Time tool).
  func setWaitFrames(_ frames: Int) {
    waitText = frameTime(frames)
    setInput(C.wait, waitText)
    refresh()
  }

  // MARK: Counter

  func counterValue(at t: Double) -> Int {
    if counterFinished { return counterTarget }
    guard let s = counterStart else { return 0 }
    let elapsed = t - s
    if elapsed < 0 { return 0 }
    return min(counterTarget, Int((elapsed * Double(counterBpm) / 60).rounded(.down)) + 1)
  }

  func startCounter() {
    commitPace()   // a pace still being typed applies before the beat is scheduled
    guard counterTarget > 0 else { return }
    counterBpm = bpm
    let start = now() + 0.15   // let the audio output settle before beat 1
    let period = 60 / Double(counterBpm)
    let events = (0..<counterTarget).map { n in
      BeepScheduler.Event(at: start + Double(n) * period, beep: n == counterTarget - 1 ? .beatFinal : .beat, channel: .counter)
    }
    counterStart = start
    counterRunning = true
    counterFinished = false
    counterGeneration = BeepScheduler.shared.start(.counter, events)
    refresh()
  }

  func stopCounter() {
    BeepScheduler.shared.cancel(.counter)
    counterRunning = false
    refresh()
  }

  func resetCounter() {
    BeepScheduler.shared.cancel(.counter)
    counterRunning = false
    counterStart = nil
    counterFinished = false
    syncCounterTarget()
    refresh()
  }

  /// The scheduler played a channel's last beep.
  func beepsDone(channel: Int, generation: Int) {
    if channel == BeepChannel.counter.rawValue, generation == counterGeneration, counterRunning {
      counterRunning = false
      counterFinished = true
    } else if channel == BeepChannel.countdown.rawValue, generation == cdGeneration, cdRunning {
      cdRunning = false
      cdFinished = true
    }
    refresh()
  }

  // MARK: Stopwatch

  func swElapsed(at t: Double) -> Double { swAccumulated + (swStart.map { t - $0 } ?? 0) }

  func toggleStopwatch() {
    if let s = swStart {
      swAccumulated += now() - s
      swStart = nil
    } else {
      swStart = now()
    }
    refresh()
  }

  func resetStopwatch() {
    swStart = nil
    swAccumulated = 0
    refresh()
  }

  // MARK: Countdown

  var waitFrames: Int? { SnipeMath.parseWaitTime(waitText) }
  var correctionSeconds: Double { correctionInFrames ? correction / SnipeMath.fps : correction }

  func plannedTotal(at t: Double) -> Double? {
    guard let f = waitFrames else { return nil }
    return countdownSeconds(waitFrames: f, stopwatchSeconds: swElapsed(at: t), correctionSeconds: correctionSeconds)
  }

  func cdRemaining(at t: Double) -> Double {
    if cdFinished { return 0 }
    guard let end = cdEnd else { return plannedTotal(at: t) ?? 0 }
    return max(0, end - t)
  }

  func startCountdown() {
    cdError = nil
    let t = now()
    guard waitFrames != nil else {
      cdError = "Wait time must look like \"0d 1h 40m 6s 15f\" or be a frame count."
      refresh(); return
    }
    // Freeze the stopwatch at the moment the countdown starts and use that value.
    if let s = swStart { swAccumulated += t - s; swStart = nil }
    let used = swElapsed(at: t)
    guard let total = plannedTotal(at: t), total > 0 else {
      cdError = "Nothing to count down: the stopwatch and correction already cover the wait time."
      refresh(); return
    }
    let end = t + total
    var events: [BeepScheduler.Event] = []
    for k in 1...10 where Double(k) < total {
      events.append(.init(at: end - Double(k), beep: .tick, channel: .countdown))
    }
    events.append(.init(at: end, beep: .finalMain, channel: .countdown))
    cdUsedStopwatch = used
    cdTotal = total
    cdEnd = end
    cdRunning = true
    cdFinished = false
    cdGeneration = BeepScheduler.shared.start(.countdown, events)
    refresh()
  }

  func cancelCountdown() {
    BeepScheduler.shared.cancel(.countdown)
    cdRunning = false
    cdEnd = nil
    cdFinished = false
    refresh()
  }

  /// A plain-text summary of the panel (smoke test).
  func describe() -> String {
    let names = ["calc.advances", "calc.time", "calc.needed", "counter.readout", "sw.readout", "cd.wait", "cd.total", "cd.readout"]
    return names.map { "\($0): \(cache[Int(bitPattern: l[$0]!)] ?? "")" }.joined(separator: "\n")
  }
}

