import RNGCore
import SwiftUI

/// Charm Search with the God charms presets and the can-this-charm-exist check.
struct SearchView: View {
  @EnvironmentObject var state: PhoneState

  var body: some View {
    Form {
      Section {
        presetsMenu
        Picker("Charm", selection: $state.kind) {
          ForEach(CharmKind.allCases) { Text(state.kindName($0)).tag($0) }
        }
        Picker("Match", selection: $state.search.mode) {
          ForEach(SearchForm.Mode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
      }

      Section("First skill") {
        skillPicker($state.search.skill1, second: false)
        Stepper("Points: \(state.search.points1)", value: $state.search.points1, in: -10...20)
      }
      Section("Second skill") {
        skillPicker($state.search.skill2, second: true)
        Stepper("Points: \(state.search.points2)", value: $state.search.points2, in: -10...20)
      }

      Section {
        Picker("Slots", selection: $state.search.slots) {
          ForEach(0...3, id: \.self) { Text("\($0)").tag($0) }
        }
        .pickerStyle(.segmented)
        OriginPicker(value: $state.search.origin)
        NumberRow(label: "Start frame", value: $state.search.start)
        NumberRow(label: "Frames to search", value: $state.search.count)
        Toggle("Set Continue Cycles target to the frame found", isOn: $state.sendFoundToCalc)
      }

      if let problem = state.searchProblem {
        Section {
          Label(problem, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
      }

      Section { RunControls { hideKeyboard(); state.runSearch() } }
      ResultsSection()
    }
    .navigationTitle("Charm Search")
    .scrollDismissesKeyboard(.interactively)
  }

  var presetsMenu: some View {
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
      Label("God charm presets", systemImage: "star")
    }
  }

  func skillPicker(_ selection: Binding<Int?>, second: Bool) -> some View {
    Picker("Skill", selection: selection) {
      Text("(none)").tag(Int?.none)
      ForEach(state.skillChoices(second: second), id: \.id) { s in
        Text(s.name).tag(Int?.some(s.id))
      }
    }
    .pickerStyle(.navigationLink)
  }
}

func hideKeyboard() {
  UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
