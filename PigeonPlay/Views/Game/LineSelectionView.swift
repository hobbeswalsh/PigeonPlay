import SwiftUI

struct LineSelectionView: View {
    let available: [Player]
    let ratio: GenderRatio
    let pointsPlayed: [Player: Int]
    let lastPointOnBench: [Player: Int]
    @Binding var selectedLine: [LineSuggestion.Entry]

    var body: some View {
        VStack(spacing: 0) {
            Text(ratio.displayName)
                .font(.headline)
                .padding(.vertical, 8)

            LineBuilderView(
                available: available,
                pointsPlayed: pointsPlayed,
                header: "On Field",
                entries: $selectedLine
            )
        }
        .padding()
        .onAppear { autoSuggest() }
    }

    private func autoSuggest() {
        let suggestion = LineSuggester.suggest(
            available: available,
            ratio: ratio,
            pointsPlayed: pointsPlayed,
            lastPointOnBench: lastPointOnBench
        )
        selectedLine = suggestion.allEntries
    }
}
