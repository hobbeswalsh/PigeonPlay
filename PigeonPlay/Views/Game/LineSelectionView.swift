import SwiftUI

struct LineSelectionView: View {
    let available: [Player]
    let ratio: GenderRatio
    let pointsPlayed: [Player: Int]
    let lastPointOnBench: [Player: Int]
    @Binding var selectedLine: [LineSuggestion.Entry]
    @State private var suggestion: LineSuggestion?

    private var onField: Set<ObjectIdentifier> {
        Set(selectedLine.map { ObjectIdentifier($0.player) })
    }

    private var bench: [Player] {
        available.filter { !onField.contains(ObjectIdentifier($0)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Ratio display
            Text(ratio.displayName)
                .font(.headline)
                .padding(.vertical, 8)

            // On field
            Section {
                ForEach(Array(selectedLine.enumerated()), id: \.offset) { index, entry in
                    HStack {
                        Text(entry.player.name)
                        Spacer()
                        if entry.player.gender == .x {
                            Button(entry.matching.displayName) {
                                toggleMatching(at: index)
                            }
                            .buttonStyle(.bordered)
                            .tint(entry.matching == .bx ? .blue : .pink)
                        } else {
                            Text(entry.player.gender.displayName)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(pointsPlayed[entry.player] ?? 0)pts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            removeFromLine(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("On Field (\(selectedLine.count)/5)")
                    .font(.subheadline.bold())
            }

            Divider().padding(.vertical, 8)

            // Bench
            Section {
                ForEach(bench) { player in
                    Button {
                        addToLine(player)
                    } label: {
                        HStack {
                            Text(player.name)
                            Spacer()
                            Text(player.gender.displayName)
                                .foregroundStyle(.secondary)
                            Text("\(pointsPlayed[player] ?? 0)pts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .tint(.primary)
                }
            } header: {
                Text("Bench")
                    .font(.subheadline.bold())
            }
        }
        .padding()
        .onAppear { autoSuggest() }
    }

    private func autoSuggest() {
        let s = LineSuggester.suggest(
            available: available,
            ratio: ratio,
            pointsPlayed: pointsPlayed,
            lastPointOnBench: lastPointOnBench
        )
        selectedLine = s.allEntries
        suggestion = s
    }

    private func toggleMatching(at index: Int) {
        let current = selectedLine[index]
        let newMatching: GenderMatching = current.matching == .bx ? .gx : .bx
        selectedLine[index] = LineSuggestion.Entry(player: current.player, matching: newMatching)
    }

    private func removeFromLine(at index: Int) {
        selectedLine.remove(at: index)
    }

    private func addToLine(_ player: Player) {
        guard selectedLine.count < 5 else { return }
        let matching: GenderMatching = switch player.gender {
        case .b: .bx
        case .g: .gx
        case .x: player.defaultMatching ?? .bx
        }
        selectedLine.append(LineSuggestion.Entry(player: player, matching: matching))
    }
}
