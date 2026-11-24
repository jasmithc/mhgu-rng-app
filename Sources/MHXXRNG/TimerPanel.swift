import RNGCore
import SwiftUI

/// Right-side panel: continue-cycle calculator, continue counter (metronome), stopwatch, final countdown.
struct TimerPanel: View {
  @ObservedObject var timers: SnipeTimers

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        CalculatorSection(timers: timers)
        CounterSection(timers: timers)
        StopwatchSection(timers: timers)
        CountdownSection(timers: timers)
      }
      .padding(14)
    }
    .frame(minWidth: 320)
  }
}

private struct SectionBox<Content: View>: View {
  let title: String
  let symbol: String
  @ViewBuilder var content: Content
  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 8) { content }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
    } label: {
      Label(title, systemImage: symbol).font(.headline)
    }
  }
}

private struct ResultRow: View {
  let label: String
  let value: String
  var emphasized = false
  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label).foregroundStyle(.secondary)
      Spacer(minLength: 8)
      Text(value).monospacedDigit().fontWeight(emphasized ? .semibold : .regular)
    }
    .font(.callout)
  }
}

private struct BigReadout: View {
  let text: String
  var color: Color = .primary
  var body: some View {
    Text(text)
      .font(.system(size: 30, weight: .medium, design: .monospaced))
      .monospacedDigit()
      .foregroundStyle(color)
      .frame(maxWidth: .infinity, alignment: .center)
      .lineLimit(1)
      .minimumScaleFactor(0.5)
  }
}

private func intField(_ title: String, _ value: Binding<Int>) -> some View {
  TextField(title, value: value, format: .number.grouping(.never))
    .multilineTextAlignment(.trailing)
    .frame(width: 140)
}

// MARK: - Calculator

private struct CalculatorSection: View {
  @ObservedObject var timers: SnipeTimers
  var body: some View {
    let c = timers.calc
    SectionBox(title: "Continue Cycles", symbol: "function") {
      HStack {
        Text("Target frame")
        Spacer()
        intField("Target frame", $timers.calcTarget)
      }
      if timers.calcTarget <= 3600 {
        Text("The target frame must be above 3600.").font(.caption).foregroundStyle(.red)
      } else {
        ResultRow(label: "Advances (2 min to spare)", value: String(format: "%.2f", c.advancesWithSpare))
        ResultRow(label: "Time at \(timers.bpm) BPM", value: SnipeTimers.clockString(c.minutes * 60))
        ResultRow(label: "Frames advanced meanwhile", value: String(format: "%.1f", c.framesAdvanced))
        // A plain button drawn as a checkbox: the whole row is clickable.
        Button {
          timers.poogie.toggle()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: timers.poogie ? "checkmark.square.fill" : "square")
              .foregroundStyle(timers.poogie ? Color.accentColor : Color.secondary)
              .font(.system(size: 15))
            Text("Poogie?")
            Spacer()
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Poogie is in your room: do 5 fewer cycles, leaving time to remove it.")
        if timers.poogie {
          ResultRow(label: "Poogie in room", value: "−\(ContinueCalc.poogieCycles)")
        }
        ResultRow(label: "Continue cycles needed",
                  value: String(format: "%.2f → %d", c.needed, c.neededWhole), emphasized: true)
        Text(timers.poogie
             ? "Rounded down, minus 5 cycles to remove Poogie. Sets the counter target."
             : "Rounded down so you don't overshoot. Sets the counter target.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

// MARK: - Counter

private struct CounterSection: View {
  @ObservedObject var timers: SnipeTimers
  var body: some View {
    SectionBox(title: "Continue Counter · \(timers.bpm) BPM", symbol: "metronome") {
      TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !timers.counterRunning)) { ctx in
        let n = timers.counterValue(at: timers.now)
        BigReadout(text: "\(n) / \(timers.counterTarget)",
                   color: timers.counterFinished ? .green : .primary)
      }
      HStack {
        Text("Target")
        intField("Target", $timers.counterTarget).disabled(timers.counterRunning)
        Spacer()
        if timers.counterRunning {
          Button("Stop") { timers.stopCounter() }
        } else {
          Button("Start") { timers.startCounter() }
            .buttonStyle(.borderedProminent)
            .disabled(timers.counterTarget <= 0)
        }
        Button("Reset") { timers.resetCounter() }
      }
      HStack {
        Text("Pace")
        TextField("BPM", value: $timers.bpm, format: .number.grouping(.never))
          .multilineTextAlignment(.trailing)
          .frame(width: 50)
          .onSubmit { clampBpm() }
        Stepper("", value: $timers.bpm, in: SnipeMath.bpmRange, step: 5)
          .labelsHidden()
        Text("BPM").foregroundStyle(.secondary)
        Spacer()
        if timers.bpm != Int(SnipeMath.bpm) {
          Button("Reset to 60") { timers.bpm = Int(SnipeMath.bpm) }
            .buttonStyle(.link)
        }
      }
      .disabled(timers.counterRunning)
      .onChange(of: timers.bpm) { clampBpm() }
      Text("Continue presses per minute. The calculator above uses the same pace.")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  func clampBpm() {
    let r = SnipeMath.bpmRange
    if !r.contains(timers.bpm) { timers.bpm = min(max(timers.bpm, r.lowerBound), r.upperBound) }
  }
}

// MARK: - Stopwatch

private struct StopwatchSection: View {
  @ObservedObject var timers: SnipeTimers
  var body: some View {
    SectionBox(title: "Stopwatch", symbol: "stopwatch") {
      TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !timers.swRunning)) { _ in
        BigReadout(text: SnipeTimers.clockString(timers.swElapsed(at: timers.now)))
      }
      HStack {
        Button(timers.swRunning ? "Stop" : "Start") { timers.toggleStopwatch() }
          .buttonStyle(.borderedProminent)
          .tint(timers.swRunning ? .red : .accentColor)
        Button("Reset") { timers.resetStopwatch() }.disabled(timers.swRunning)
        Spacer()
        Text("⇧⌘S").font(.caption).foregroundStyle(.tertiary)
      }
      Text("Start it when you press Combine; it's subtracted from the countdown.")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}

// MARK: - Countdown

private struct CountdownSection: View {
  @ObservedObject var timers: SnipeTimers

  var body: some View {
    SectionBox(title: "Final Countdown", symbol: "timer") {
      VStack(alignment: .leading, spacing: 3) {
        Text("Wait time (from Frame → Wait Time)").font(.callout)
        TextField("0d 1h 40m 6s 15f", text: $timers.waitText)
          .font(.system(.body, design: .monospaced))
          .disabled(timers.cdRunning)
      }
      HStack {
        Text("Correction")
        TextField("0", value: $timers.correction, format: .number.precision(.fractionLength(0...3)))
          .multilineTextAlignment(.trailing)
          .frame(width: 70)
          .disabled(timers.cdRunning)
        Picker("", selection: $timers.correctionUnit) {
          ForEach(CorrectionUnit.allCases) { Text($0.rawValue).tag($0) }
        }
        .labelsHidden()
        // A fixed width (fits "seconds") rather than .fixedSize(): the ideal-size measurement
        // could collapse the menu to just "f".
        .frame(width: 100)
        .disabled(timers.cdRunning)
      }
      Text("+ waits longer, − shorter.").font(.caption).foregroundStyle(.secondary)

      TimelineView(.animation(minimumInterval: 1.0 / 60,
                              paused: !(timers.cdRunning || timers.swRunning))) { _ in
        let t = timers.now
        VStack(spacing: 6) {
          breakdown(at: t)
          let remaining = timers.cdRemaining(at: t)
          BigReadout(text: SnipeTimers.clockString(remaining),
                     color: readoutColor(remaining))
          Text(String(format: "%.0f frames", (remaining * SnipeTimers.fps).rounded(.up)))
            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
      }

      if let err = timers.cdError {
        Text(err).font(.caption).foregroundStyle(.red)
      }
      HStack {
        if timers.cdRunning {
          Button("Cancel", role: .cancel) { timers.cancelCountdown() }
        } else {
          Button("Start Countdown") { timers.startCountdown() }
            .buttonStyle(.borderedProminent)
          if timers.cdFinished || timers.cdEnd != nil {
            Button("Reset") { timers.cancelCountdown() }
          }
        }
        Spacer()
        Text("⇧⌘↩").font(.caption).foregroundStyle(.tertiary)
      }
      Text("Beeps each of the last 10 seconds, then a long beep at zero. Starting it stops the stopwatch.")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  @ViewBuilder func breakdown(at t: ContinuousClock.Instant) -> some View {
    let wait = timers.waitFrames.map { Double($0) / SnipeTimers.fps }
    let sw = timers.cdEnd != nil ? timers.cdUsedStopwatch : timers.swElapsed(at: t)
    VStack(spacing: 2) {
      ResultRow(label: "Wait time", value: wait.map(SnipeTimers.clockString) ?? "invalid")
      ResultRow(label: "− Stopwatch", value: SnipeTimers.clockString(sw))
      ResultRow(label: "+ Correction", value: SnipeTimers.clockString(timers.correctionSeconds))
      Divider()
      ResultRow(label: "= Countdown",
                value: timers.cdEnd != nil ? SnipeTimers.clockString(timers.cdTotal)
                  : (timers.plannedTotal(at: t).map(SnipeTimers.clockString) ?? "—"),
                emphasized: true)
    }
  }

  func readoutColor(_ remaining: Double) -> Color {
    if timers.cdFinished { return .green }
    if timers.cdRunning && remaining <= 10 { return .orange }
    return .primary
  }
}
