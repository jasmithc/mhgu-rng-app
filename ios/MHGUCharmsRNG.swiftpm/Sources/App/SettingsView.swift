import RNGCore
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var state: PhoneState

  var body: some View {
    Form {
      Section("Charms") {
        Picker("Charm kind", selection: $state.kind) {
          ForEach(CharmKind.allCases) { Text(state.kindName($0)).tag($0) }
        }
        Picker("Skill names", selection: $state.language) {
          ForEach(Language.allCases) { Text($0.displayName).tag($0) }
        }
      }
      Section("Results") {
        Toggle("Show rarity after each charm", isOn: $state.showRare)
        Toggle("Show Halcyon/Juju aim points for every rank", isOn: $state.showAllRank)
        Stepper("Quest charm count (aim points): \(state.numOfCharms)", value: $state.numOfCharms, in: 2...100)
      }
      Section {
        Link("Project page and guides", destination: URL(string: "https://github.com/jasmithc/mhgu-rng-app")!)
      } footer: {
        Text("Based on apmnnn/mhxx-rng and its English translation jasmithc/mhgu-rng. Unofficial fan tool, not affiliated with Capcom.")
      }
    }
    .navigationTitle("Settings")
  }
}
