import RNGCore
import SwiftUI

/// The other tools from the Mac app, one screen each.
struct ToolsView: View {
  var body: some View {
    List {
      NavigationLink { AroundView() } label: { Label("Around a Frame", systemImage: "list.bullet.indent") }
      NavigationLink { WaitTimeView() } label: { Label("Frame → Wait Time", systemImage: "timer") }
      NavigationLink { MeldView() } label: { Label("Halcyon / Juju Meld", systemImage: "flame") }
      NavigationLink { SequenceView() } label: { Label("Quest Charm Sequence", systemImage: "list.number") }
      NavigationLink { FillSlotView() } label: { Label("Slot & Fill Search", systemImage: "circle.grid.3x3") }
      NavigationLink { ComboView() } label: { Label("Item Combo Search", systemImage: "flask") }
      NavigationLink { RewardView() } label: { Label("Quest Reward Search", systemImage: "gift") }
      NavigationLink { DumpView() } label: { Label("Raw RNG Dump", systemImage: "number") }
    }
    .navigationTitle("Tools")
  }
}

/// Common layout: inputs, Run, results.
struct ToolScreen<Inputs: View>: View {
  let title: String
  let help: String
  let run: () -> Void
  @ViewBuilder var inputs: Inputs

  var body: some View {
    Form {
      Section { inputs } footer: { Text(help) }
      Section { RunControls { hideKeyboard(); run() } }
      ResultsSection()
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .scrollDismissesKeyboard(.interactively)
  }
}

struct AroundView: View {
  @EnvironmentObject var state: PhoneState
  @State private var frame = 4723
  @State private var num = 60
  @State private var origin: Origin = .melding
  var body: some View {
    ToolScreen(title: "Around a Frame", help: "Every charm within N frames either side of a frame.", run: {
      let (f, n, o) = (frame, max(num, 1), origin)
      state.run("around") { e in e.around(frame: f, num: n, origin: o) }
    }) {
      NumberRow(label: "Frame", value: $frame)
      NumberRow(label: "Frames either side", value: $num)
      OriginPicker(value: $origin)
    }
  }
}

struct WaitTimeView: View {
  @EnvironmentObject var state: PhoneState
  @State private var target = 4723
  @State private var baseline = 1717
  @State private var useBaseline = true
  var body: some View {
    ToolScreen(title: "Frame → Wait Time", help: "Frames to a waiting time at 30 frames per second. The result is also filled into the Timer tab's Final Countdown.", run: {
      let frames = useBaseline ? target - baseline : target
      state.timers.setWaitFrames(frames)
      state.run("wait time") { e in
        e.out.print("\(frames) frames")
        e.out.print(frameTime(frames))
      }
    }) {
      NumberRow(label: "Target frame", value: $target)
      Toggle("Subtract a baseline frame", isOn: $useBaseline)
      if useBaseline { NumberRow(label: "Baseline frame", value: $baseline) }
    }
  }
}

struct MeldView: View {
  @EnvironmentObject var state: PhoneState
  @State private var frame = 1730
  @State private var halcyon = true
  @State private var rank = 4
  var body: some View {
    ToolScreen(title: "Halcyon / Juju Meld", help: "The charms a Halcyon or Juju meld gives at a frame.", run: {
      let (f, h, r) = (frame, halcyon, rank)
      state.run("meld") { e in e.meldingPush(frame: f, halcyon: h, rank: r) }
    }) {
      Picker("Meld", selection: $halcyon) {
        Text(state.lang.melding[1]).tag(true)
        Text(state.lang.melding[0]).tag(false)
      }
      .pickerStyle(.segmented)
      NumberRow(label: "Frame", value: $frame)
      Picker("Rank", selection: $rank) { ForEach([4, 3, 2, 1], id: \.self) { Text("Rank \($0)").tag($0) } }
    }
  }
}

struct SequenceView: View {
  @EnvironmentObject var state: PhoneState
  @State private var frame = 221_014
  @State private var count = 40
  var body: some View {
    ToolScreen(title: "Quest Charm Sequence", help: "The run of quest-reward charms starting at a frame.", run: {
      let (f, c) = (frame, count)
      state.run("sequence") { e in e.sequenceCharm(frame: f, count: c) }
    }) {
      NumberRow(label: "Start frame", value: $frame)
      NumberRow(label: "Number of charms", value: $count)
    }
  }
}

struct FillSlotView: View {
  @EnvironmentObject var state: PhoneState
  @State private var fill = 20
  @State private var slots = 3
  @State private var origin: Origin = .melding
  @State private var start = 0
  @State private var count = 1_000_000
  var body: some View {
    ToolScreen(title: "Slot & Fill Search", help: "Charms with a given fill value and slot count.", run: {
      let (fl, sl, o, s, c) = (fill, slots, origin, start, count)
      state.run("slot & fill search") { e in try e.searchFillSlot(start: s, step: c, fill: fl, slot: sl, origin: o) }
    }) {
      Picker("Fill", selection: $fill) { ForEach(1...20, id: \.self) { Text("\($0)").tag($0) } }
      Picker("Slots", selection: $slots) { ForEach(1...3, id: \.self) { Text("\($0)").tag($0) } }
        .pickerStyle(.segmented)
      OriginPicker(value: $origin)
      NumberRow(label: "Start frame", value: $start)
      NumberRow(label: "Frames to search", value: $count)
    }
  }
}

struct ComboView: View {
  @EnvironmentObject var state: PhoneState
  @State private var text = ""
  @State private var start = 0
  @State private var count = 10_000_000
  var body: some View {
    ToolScreen(title: "Item Combo Search", help: "Enter every ammo count up to the 99, separated by spaces. Also shows how likely a chance match is, and checks for a 1–2 frame stutter if nothing matches exactly.", run: {
      let (t, s, c) = (text, start, count)
      state.run("combo search") { e in
        try e.searchCombo(start: s, step: c, combo: t)
        try e.checkCombo(start: s, step: c, combo: t)
      }
    }) {
      TextField("00 02 04 07 10 …", text: $text, axis: .vertical)
        .font(.system(.body, design: .monospaced))
        .keyboardType(.numbersAndPunctuation)
        .autocorrectionDisabled()
        .lineLimit(3...8)
      NumberRow(label: "Start frame", value: $start)
      NumberRow(label: "Frames to search", value: $count)
    }
  }
}

struct RewardView: View {
  @EnvironmentObject var state: PhoneState
  @State private var table = "MysteryBone:20 Fishing:40 RawMeat:65 Whetstone:85 PowerBait:90 HeavyBait:95 SpeedBait:100"
  @State private var sequence = "PowerBait Fishing RawMeat MysteryBone MysteryBone RawMeat Fishing"
  @State private var bonusTh = 28
  @State private var start = 0
  @State private var count = 10_000_000
  var body: some View {
    ToolScreen(title: "Quest Reward Search", help: "Find your RNG position from a sequence of quest rewards. Table entries look like Name:threshold.", run: {
      let (tb, sq, b, s, c) = (table, sequence, bonusTh, start, count)
      state.run("reward search") { e in
        var t: [(String, Int)] = []
        for part in tb.split(whereSeparator: { $0.isWhitespace || $0 == "," }) {
          let kv = part.split(separator: ":")
          guard kv.count == 2, let v = Int(kv[1]) else {
            throw RNGError("Reward table entries must look like Name:threshold (got \"\(part)\").")
          }
          t.append((String(kv[0]), v))
        }
        try e.searchReward(start: s, step: c, bonusTh: b, target: sq, table: t)
      }
    }) {
      TextField("Reward table", text: $table, axis: .vertical)
        .font(.system(.footnote, design: .monospaced)).autocorrectionDisabled().textInputAutocapitalization(.never)
      TextField("Rewards received", text: $sequence, axis: .vertical)
        .font(.system(.footnote, design: .monospaced)).autocorrectionDisabled().textInputAutocapitalization(.never)
      NumberRow(label: "Bonus threshold", value: $bonusTh)
      NumberRow(label: "Start frame", value: $start)
      NumberRow(label: "Frames to search", value: $count)
    }
  }
}

struct DumpView: View {
  @EnvironmentObject var state: PhoneState
  @State private var frame = 1600
  @State private var count = 200
  @State private var showAll = true
  var body: some View {
    ToolScreen(title: "Raw RNG Dump", help: "Raw RNG state values.", run: {
      let (f, c, a) = (frame, count, showAll)
      state.run("RNG dump") { e in try e.allPush(frame: f, count: c, showAll: a) }
    }) {
      NumberRow(label: "Frame", value: $frame)
      NumberRow(label: "Frames to show", value: $count)
      Toggle("Show skills and mod 100", isOn: $showAll)
    }
  }
}
