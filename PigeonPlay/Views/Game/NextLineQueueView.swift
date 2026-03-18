import SwiftUI

struct NextLineQueueView: View {
    let available: [Player]
    let pointsPlayed: [Player: Int]
    let lastPointOnBench: [Player: Int]
    @Binding var queuedLine: [LineSuggestion.Entry]
    @Binding var queuedRatio: GenderRatio

    var body: some View {
        VStack(spacing: 0) {
            Picker("Ratio", selection: $queuedRatio) {
                Text("2B / 3G").tag(GenderRatio.twoBThreeG)
                Text("3B / 2G").tag(GenderRatio.threeBTwoG)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: queuedRatio) {
                resuggest()
            }

            ScrollView {
                LineBuilderView(
                    available: available,
                    pointsPlayed: pointsPlayed,
                    header: "Next Up",
                    entries: $queuedLine
                )
                .padding()
            }

            Button("Shuffle", systemImage: "shuffle") {
                resuggest()
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }

    private func resuggest() {
        let suggestion = LineSuggester.suggest(
            available: available,
            ratio: queuedRatio,
            pointsPlayed: pointsPlayed,
            lastPointOnBench: lastPointOnBench
        )
        queuedLine = suggestion.allEntries
    }
}
