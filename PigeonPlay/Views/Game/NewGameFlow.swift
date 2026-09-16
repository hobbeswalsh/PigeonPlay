import SwiftUI
import SwiftData

struct NewGameFlow: View {
    @Binding var opponentName: String
    @Binding var lineSize: Int
    @Binding var ratioSequence: RatioSequence
    @Binding var startingRatio: GenderRatio
    @Binding var checkedInPlayerIDs: Set<PersistentIdentifier>
    let onCreate: () -> Void

    @State private var showingCheckIn = false

    var body: some View {
        Form {
            Section("Opponent") {
                TextField("Team name", text: $opponentName)
            }
            Section("Rules") {
                Stepper("Line size: \(lineSize)", value: $lineSize, in: 3...7)

                Picker("Starting ratio", selection: $startingRatio) {
                    Text(GenderRatio.twoBThreeG.composition(lineSize: lineSize).displayName)
                        .tag(GenderRatio.twoBThreeG)
                    Text(GenderRatio.threeBTwoG.composition(lineSize: lineSize).displayName)
                        .tag(GenderRatio.threeBTwoG)
                }

                Picker("Ratio pattern", selection: $ratioSequence) {
                    ForEach(RatioSequence.allCases, id: \.self) { sequence in
                        Text(sequence.displayName).tag(sequence)
                    }
                }
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
