import SwiftUI

struct NextLineQueueView: View {
    let available: [Player]
    let pointsPlayed: [Player: Int]
    let lastPointOnBench: [Player: Int]
    @Binding var queuedLine: [LineSuggestion.Entry]
    @Binding var queuedRatio: GenderRatio

    private var onField: Set<ObjectIdentifier> {
        Set(queuedLine.map { ObjectIdentifier($0.player) })
    }

    private var bench: [Player] {
        available.filter { !onField.contains(ObjectIdentifier($0)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Next: \(queuedRatio.displayName)")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(queuedLine.count)/5 ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

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
                VStack(spacing: 0) {
                    Section {
                        ForEach(Array(queuedLine.enumerated()), id: \.offset) { index, entry in
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
                                    queuedLine.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    } header: {
                        Text("Next Up (\(queuedLine.count)/5)")
                            .font(.subheadline.bold())
                    }

                    Divider().padding(.vertical, 8)

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

    private func toggleMatching(at index: Int) {
        let current = queuedLine[index]
        let newMatching: GenderMatching = current.matching == .bx ? .gx : .bx
        queuedLine[index] = LineSuggestion.Entry(player: current.player, matching: newMatching)
    }

    private func addToLine(_ player: Player) {
        guard queuedLine.count < 5 else { return }
        let matching: GenderMatching = switch player.gender {
        case .b: .bx
        case .g: .gx
        case .x: player.defaultMatching ?? .bx
        }
        queuedLine.append(LineSuggestion.Entry(player: player, matching: matching))
    }
}
