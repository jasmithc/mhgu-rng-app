import RNGCore
import SnipeKit
import SwiftUI

@main
struct MHGUCharmsRNGApp: App {
  @StateObject private var state = PhoneState()

  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(state)
    }
  }
}

struct RootView: View {
  @EnvironmentObject var state: PhoneState
  /// Reopens on the tab you were last using (e.g. the Timer mid-snipe).
  @AppStorage("selectedTab") private var tab = 0

  var body: some View {
    TabView(selection: $tab) {
      NavigationStack { SearchView() }
        .tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(0)
      NavigationStack { ToolsView() }
        .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }.tag(1)
      NavigationStack {
        ScrollView { TimerPanel(timers: state.timers) }
          .navigationTitle("Snipe Timer")
          .scrollDismissesKeyboard(.interactively)
      }
      .tabItem { Label("Timer", systemImage: "timer") }.tag(2)
      NavigationStack { SettingsView() }
        .tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
    }
  }
}

// MARK: - Shared pieces

/// A labelled whole-number field with a number pad.
struct NumberRow: View {
  let label: String
  @Binding var value: Int
  var allowMinus = false

  var body: some View {
    LabeledContent(label) {
      TextField(label, value: $value, format: .number.grouping(.never))
        .multilineTextAlignment(.trailing)
        .keyboardType(allowMinus ? .numbersAndPunctuation : .numberPad)
        .font(.body.monospacedDigit())
    }
  }
}

/// Run / Stop button plus the status line.
struct RunControls: View {
  @EnvironmentObject var state: PhoneState
  let action: () -> Void

  var body: some View {
    if state.isRunning {
      Button(role: .cancel) { state.stop() } label: {
        HStack { ProgressView(); Text("Stop") }
      }
    } else {
      Button(action: action) { Label("Run", systemImage: "play.fill").frame(maxWidth: .infinity) }
        .buttonStyle(.borderedProminent)
    }
    if !state.status.isEmpty {
      Text(state.status).font(.footnote).foregroundStyle(.secondary)
    }
  }
}

/// The last tool's output: monospaced, scrolls sideways so columns stay aligned.
struct ResultsSection: View {
  @EnvironmentObject var state: PhoneState

  var body: some View {
    if !state.output.characters.isEmpty {
      Section("Results") {
        ScrollView(.horizontal) {
          Text(state.output)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, 4)
        }
        Button("Copy results") { UIPasteboard.general.string = String(state.output.characters) }
          .font(.footnote)
      }
    }
  }
}

struct OriginPicker: View {
  @EnvironmentObject var state: PhoneState
  @Binding var value: Origin
  var body: some View {
    Picker("Source", selection: $value) {
      ForEach(Origin.allCases) { Text(state.originName($0)).tag($0) }
    }
    .pickerStyle(.segmented)
  }
}
