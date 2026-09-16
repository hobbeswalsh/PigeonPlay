import SwiftUI

struct LineSelectionView: View {
    let available: [Player]
    let ratio: GenderRatio
    let lineSize: Int
    let pointsPlayed: [Player: Int]
    let lastPointOnBench: [Player: Int]
    @Binding var selectedLine: [LineSuggestion.Entry]

    var body: some View {
        VStack(spacing: 0) {
            Text(ratio.composition(lineSize: lineSize).displayName)
                .font(.headline)
                .padding(.vertical, 8)

            LineBuilderView(
                available: available,
                pointsPlayed: pointsPlayed,
                header: "On Field",
                lineSize: lineSize,
                entries: $selectedLine
            )
        }
        .padding()
        .onAppear { autoSuggest() }
    }

    private func autoSuggest() {
        guard selectedLine.isEmpty else { return }
        let suggestion = LineSuggester.suggest(
            available: available,
            ratio: ratio,
            lineSize: lineSize,
            pointsPlayed: pointsPlayed,
            lastPointOnBench: lastPointOnBench
        )
        selectedLine = suggestion.allEntries
    }
}
