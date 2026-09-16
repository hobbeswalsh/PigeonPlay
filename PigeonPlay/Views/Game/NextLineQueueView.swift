import SwiftUI

struct NextLineQueueView: View {
    let available: [Player]
    let lineSize: Int
    let pointsPlayed: [Player: Int]
    let lastPointOnBench: [Player: Int]
    @Binding var queuedLine: [LineSuggestion.Entry]
    @Binding var queuedRatio: GenderRatio

    var body: some View {
        VStack(spacing: 0) {
            Picker("Ratio", selection: $queuedRatio) {
                Text(GenderRatio.twoBThreeG.composition(lineSize: lineSize).displayName)
                    .tag(GenderRatio.twoBThreeG)
                Text(GenderRatio.threeBTwoG.composition(lineSize: lineSize).displayName)
                    .tag(GenderRatio.threeBTwoG)
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
                    lineSize: lineSize,
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
            lineSize: lineSize,
            pointsPlayed: pointsPlayed,
            lastPointOnBench: lastPointOnBench
        )
        queuedLine = suggestion.allEntries
    }
}
