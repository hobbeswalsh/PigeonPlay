import SwiftUI
import SwiftData

struct NewGameFlow: View {
    @Binding var opponentName: String
    @Binding var checkedInPlayerIDs: Set<PersistentIdentifier>
    let onCreate: () -> Void

    @State private var showingCheckIn = false

    var body: some View {
        Form {
            Section("Opponent") {
                TextField("Team name", text: $opponentName)
            }
            Section {
                Button("Next: Check In Players") {
                    showingCheckIn = true
                }
                .disabled(opponentName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("New Game")
        .navigationDestination(isPresented: $showingCheckIn) {
            CheckInView(
                checkedInPlayers: $checkedInPlayerIDs,
                onConfirm: onCreate
            )
        }
    }
}
