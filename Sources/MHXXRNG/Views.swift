import AppKit
import RNGCore
import SwiftUI

@main
struct MHXXRNGApp: App {
  @StateObject private var state = AppState()

  var body: some Scene {
    WindowGroup("MHGU Charms RNG") {
      ContentView()
        .environmentObject(state)
        .frame(minWidth: 1180, minHeight: 680)
    }
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandMenu("Timer") { TimerCommands(state: state, timers: state.timers) }
    }
    Settings {
      SettingsView().environmentObject(state)
    }
  }
}

struct ContentView: View {
  @EnvironmentObject var state: AppState

  var body: some View {
    NavigationSplitView {
      List(Tool.allCases, selection: $state.tool) { tool in
        Label(tool.title, systemImage: tool.symbol).tag(tool)
      }
      .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    } detail: {
      // The timer panel is a plain right-hand column. (A SwiftUI .inspector put its scrolling
      // content under the toolbar with click targets ~60 pt above where it was drawn.)
      HStack(spacing: 0) {
      VSplitView {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            if let tool = state.tool {
              Text(tool.title).font(.title2.bold())
              Text(tool.help).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
              ToolForm(tool: tool)
            }
          }
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 220, idealHeight: 300)

        VStack(spacing: 0) {
          HStack {
            Text(state.status).font(.callout).foregroundStyle(.secondary)
            if state.isRunning { ProgressView().controlSize(.small) }
            Spacer()
            Button("Copy") {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(state.output.string, forType: .string)
            }
            .disabled(state.output.length == 0)
            Button("Clear") { state.output = NSAttributedString(string: "") }
              .disabled(state.output.length == 0)
          }
          .padding(.horizontal, 12).padding(.vertical, 6)
          Divider()
          OutputTextView(text: state.output)
        }
        .frame(minHeight: 200)
      }
      if state.showTimer {
        Divider()
        TimerPanel(timers: state.timers)
          .frame(width: 360)
          .background(.background.secondary)
      }
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          state.showTimer.toggle()
        } label: {
          Label("Snipe Timer", systemImage: "timer")
        }
        .help("Show or hide the snipe timer panel (⌥⌘T)")
      }
      ToolbarItemGroup(placement: .primaryAction) {
        Picker("Charm", selection: $state.kind) {
          ForEach(CharmKind.allCases) { Text(state.kindName($0)).tag($0) }
        }
        .help("Charm kind (set_blue / set_red / set_yellow / set_white)")
        .onChange(of: state.kind) { state.kindChanged() }

        Picker("Language", selection: $state.language) {
          ForEach(Language.allCases) { Text($0.displayName).tag($0) }
        }
        .help("Skill-name language")
      }
    }
  }
}

// MARK: - Forms

struct ToolForm: View {
  @EnvironmentObject var state: AppState
  let tool: Tool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Form { fields }
        .formStyle(.columns)
      HStack {
        Button(action: run) { Label("Run", systemImage: "play.fill") }
          .keyboardShortcut(.return, modifiers: .command)
          .buttonStyle(.borderedProminent)
          .disabled(state.isRunning)
        if state.isRunning {
          Button("Stop", role: .cancel) { state.stop() }
            .keyboardShortcut(.escape, modifiers: [])
        }
        Text("⌘↩ to run").font(.caption).foregroundStyle(.tertiary)
      }
    }
  }

  @ViewBuilder var fields: some View {
    switch tool {
    case .search:
      LabeledContent("Presets") {
        Menu {
          ForEach(PresetSection.allCases, id: \.self) { section in
            Section(section.rawValue) {
              ForEach(CharmPresets.groups.filter { $0.section == section }, id: \.name) { group in
                Menu(group.name) {
                  ForEach(group.presets, id: \.self) { p in
                    Button(p.label(state.lang)) { state.applyPreset(p) }
                  }
                }
              }
            }
          }
        } label: {
          Label("God charms", systemImage: "star")
        }
        .fixedSize()
        .help("Fill in the search with a top charm for your weapon")
      }
      Picker("Match", selection: $state.search.mode) {
        ForEach(SearchMode.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented).fixedSize()
      HStack {
        SkillPicker(label: "First skill", selection: $state.search.skill1, second: false)
        NumField("points", $state.search.points1, width: 60)
      }
      HStack {
        SkillPicker(label: "Second skill", selection: $state.search.skill2, second: true)
        NumField("points", $state.search.points2, width: 60)
      }
      SlotsPicker(value: $state.search.slots, allowZero: true)
      OriginPicker(value: $state.search.origin)
      FrameRange(start: $state.search.start, count: $state.search.count)
      if let problem = state.searchProblem {
        LabeledContent("") {
          Label(problem, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 440, alignment: .leading)
        }
      }
      Toggle("Set Continue Cycles target to the frame found", isOn: $state.sendFoundToCalc)
        .help("After a search, copy the first frame found into the timer panel's Continue Cycles calculator.")
    case .around:
      NumField("Frame", $state.around.frame)
      NumField("Frames either side", $state.around.num)
      OriginPicker(value: $state.around.origin)
    case .time:
      NumField("Target frame", $state.time.target)
      Toggle("Subtract a baseline frame", isOn: $state.time.useBaseline)
      if state.time.useBaseline { NumField("Baseline frame", $state.time.baseline) }
    case .melding:
      Picker("Meld", selection: $state.melding.halcyon) {
        Text(state.lang.melding[1]).tag(true)
        Text(state.lang.melding[0]).tag(false)
      }
      .pickerStyle(.segmented).fixedSize()
      NumField("Frame", $state.melding.frame)
      Picker("Rank", selection: $state.melding.rank) {
        ForEach([4, 3, 2, 1], id: \.self) { Text("Rank \($0)").tag($0) }
      }
      .fixedSize()
    case .sequence:
      NumField("Start frame", $state.sequence.frame)
      NumField("Number of charms", $state.sequence.count)
    case .fillSlot:
      Picker("Fill", selection: $state.fill.fill) {
        ForEach(1...20, id: \.self) { Text("\($0)").tag($0) }
      }
      .fixedSize()
      SlotsPicker(value: $state.fill.slots, allowZero: false)
      OriginPicker(value: $state.fill.origin)
      FrameRange(start: $state.fill.start, count: $state.fill.count)
    case .combo:
      LabeledContent("Combination results") {
        TextEditor(text: $state.combo.text)
          .font(.system(.body, design: .monospaced))
          .frame(width: 440, height: 80)
          .border(Color.secondary.opacity(0.3))
      }
      FrameRange(start: $state.combo.start, count: $state.combo.count)
    case .reward:
      LabeledContent("Reward table") {
        TextField("", text: $state.reward.table, axis: .vertical)
          .font(.system(.body, design: .monospaced)).frame(width: 440).lineLimit(2...4)
      }
      LabeledContent("Rewards received") {
        TextField("", text: $state.reward.sequence, axis: .vertical)
          .font(.system(.body, design: .monospaced)).frame(width: 440).lineLimit(1...3)
      }
      NumField("Bonus threshold", $state.reward.bonusTh)
      FrameRange(start: $state.reward.start, count: $state.reward.count)
    case .dump:
      NumField("Frame", $state.dump.frame)
      NumField("Frames to show", $state.dump.count)
      Toggle("Show skills and mod 100", isOn: $state.dump.showAll)
    }
  }

  func run() {
    switch tool {
    case .search:
      let f = state.search
      if f.mode == .exact && f.skill1 == nil {
        state.status = "Exact search needs a first skill."; return
      }
      if f.skill1 == nil && f.skill2 == nil {
        state.status = "Pick at least one skill."; return
      }
      if let problem = state.searchProblem {
        // Don't search for a charm that can't exist; explain why instead.
        state.output = OutputRenderer.render({ let o = Output(); o.print("Not searched: this charm can't exist."); o.print(problem); return o }())
        state.status = "Not searched: this charm can't exist"
        return
      }
      state.run("search") { e in
        let p = try e.parameter(skill1: f.skill1, points1: f.points1, skill2: f.skill2,
                                points2: f.points2, slots: f.slots, origin: f.origin)
        if f.mode == .exact { try e.search(start: f.start, step: f.count, p) }
        else { try e.searchGreater(start: f.start, step: f.count, p) }
      } onFound: { frames in
        guard state.sendFoundToCalc, let first = frames.first else { return }
        state.timers.calcTarget = first
        state.status += " · Continue Cycles target set to \(first)"
          + (frames.count > 1 ? " (first of \(frames.count) found)" : "")
      }
    case .around:
      let f = state.around
      state.run("around") { e in e.around(frame: f.frame, num: max(f.num, 1), origin: f.origin) }
    case .time:
      let f = state.time
      state.timers.setWaitFrames(f.useBaseline ? f.target - f.baseline : f.target)
      state.run("wait time") { e in
        let frames = f.useBaseline ? f.target - f.baseline : f.target
        e.out.print("\(frames) frames")
        e.out.print(frameTime(frames))
      }
    case .melding:
      let f = state.melding
      state.run("meld") { e in e.meldingPush(frame: f.frame, halcyon: f.halcyon, rank: f.rank) }
    case .sequence:
      let f = state.sequence
      state.run("sequence") { e in e.sequenceCharm(frame: f.frame, count: f.count) }
    case .fillSlot:
      let f = state.fill
      state.run("slot & fill search") { e in
        try e.searchFillSlot(start: f.start, step: f.count, fill: f.fill, slot: f.slots, origin: f.origin)
      }
    case .combo:
      let f = state.combo
      state.run("combo search") { e in
        try e.searchCombo(start: f.start, step: f.count, combo: f.text)
        try e.checkCombo(start: f.start, step: f.count, combo: f.text)
      }
    case .reward:
      let f = state.reward
      state.run("reward search") { e in
        var table: [(String, Int)] = []
        for part in f.table.split(whereSeparator: { $0.isWhitespace || $0 == "," }) {
          let kv = part.split(separator: ":")
          guard kv.count == 2, let v = Int(kv[1]) else {
            throw RNGError("Reward table entries must look like Name:threshold (got \"\(part)\").")
          }
          table.append((String(kv[0]), v))
        }
        try e.searchReward(start: f.start, step: f.count, bonusTh: f.bonusTh,
                           target: f.sequence, table: table)
      }
    case .dump:
      let f = state.dump
      state.run("RNG dump") { e in try e.allPush(frame: f.frame, count: f.count, showAll: f.showAll) }
    }
  }
}

struct NumField: View {
  let label: String
  @Binding var value: Int
  var width: CGFloat = 180
  init(_ label: String, _ value: Binding<Int>, width: CGFloat = 180) {
    self.label = label; self._value = value; self.width = width
  }
  var body: some View {
    // Size the input box itself (not label + box), so large frame numbers stay visible.
    LabeledContent(label) {
      TextField(label, value: $value, format: .number.grouping(.never))
        .labelsHidden()
        .multilineTextAlignment(.trailing)
        .font(.body.monospacedDigit())
        .frame(width: width)
    }
  }
}

struct FrameRange: View {
  @Binding var start: Int
  @Binding var count: Int
  var body: some View {
    NumField("Start frame", $start)
    NumField("Frames to search", $count)
  }
}

struct SkillPicker: View {
  @EnvironmentObject var state: AppState
  let label: String
  @Binding var selection: Int?
  let second: Bool
  var body: some View {
    Picker(label, selection: $selection) {
      Text("(none)").tag(Int?.none)
      Divider()
      ForEach(state.skillChoices(second: second), id: \.id) { s in
        Text(s.name).tag(Int?.some(s.id))
      }
    }
    .frame(width: 320)
  }
}

struct SlotsPicker: View {
  @Binding var value: Int
  let allowZero: Bool
  var body: some View {
    Picker("Slots", selection: $value) {
      ForEach(allowZero ? Array(0...3) : Array(1...3), id: \.self) { Text("\($0)").tag($0) }
    }
    .pickerStyle(.segmented).fixedSize()
  }
}

struct OriginPicker: View {
  @EnvironmentObject var state: AppState
  @Binding var value: Origin
  var body: some View {
    Picker("Source", selection: $value) {
      ForEach(Origin.allCases) { Text(state.originName($0)).tag($0) }
    }
    .pickerStyle(.segmented).fixedSize()
  }
}

// MARK: - Settings

struct SettingsView: View {
  @EnvironmentObject var state: AppState
  var body: some View {
    Form {
      Toggle("Show rarity after each charm", isOn: $state.showRare)
      Toggle("Show Halcyon/Juju aim points for every rank", isOn: $state.showAllRank)
      TextField("Quest charm count (aim points)", value: $state.numOfCharms, format: .number)
    }
    .padding(20)
    .frame(width: 420)
  }
}

// MARK: - Output view

struct OutputTextView: NSViewRepresentable {
  let text: NSAttributedString

  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSTextView.scrollableTextView()
    let tv = scroll.documentView as! NSTextView
    tv.isEditable = false
    tv.isSelectable = true
    tv.isRichText = true
    tv.textContainerInset = NSSize(width: 10, height: 10)
    tv.backgroundColor = .textBackgroundColor
    // Wrap long lines to the panel width (no horizontal scrolling).
    tv.isHorizontallyResizable = false
    tv.textContainer?.widthTracksTextView = true
    scroll.hasHorizontalScroller = false
    return scroll
  }

  func updateNSView(_ scroll: NSScrollView, context: Context) {
    guard let tv = scroll.documentView as? NSTextView else { return }
    if tv.textStorage?.isEqual(to: text) != true {
      tv.textStorage?.setAttributedString(text)
      tv.scrollToBeginningOfDocument(nil)
    }
  }
}

// MARK: - Timer menu

/// Menu-bar versions of the timer panel's controls, so they work without clicking in the panel.
struct TimerCommands: View {
  @ObservedObject var state: AppState
  @ObservedObject var timers: SnipeTimers

  var body: some View {
    Toggle("Show Timer Panel", isOn: $state.showTimer)
      .keyboardShortcut("t", modifiers: [.command, .option])
    Divider()
    Toggle("Poogie in Room (−5 cycles)", isOn: $timers.poogie)
      .keyboardShortcut("p", modifiers: [.command, .option])
    Divider()
    Button(timers.counterRunning ? "Stop Continue Counter" : "Start Continue Counter") {
      timers.counterRunning ? timers.stopCounter() : timers.startCounter()
    }
    .keyboardShortcut("c", modifiers: [.command, .option])
    Button(timers.swRunning ? "Stop Stopwatch" : "Start Stopwatch") { timers.toggleStopwatch() }
      .keyboardShortcut("s", modifiers: [.command, .shift])
    Button("Reset Stopwatch") { timers.resetStopwatch() }
      .disabled(timers.swRunning)
    Divider()
    Button(timers.cdRunning ? "Cancel Countdown" : "Start Countdown") {
      timers.cdRunning ? timers.cancelCountdown() : timers.startCountdown()
    }
    .keyboardShortcut(.return, modifiers: [.command, .shift])
  }
}
