import SwiftUI

struct LineBuilderView: View {
    let available: [Player]
    let pointsPlayed: [Player: Int]
    let header: String
    @Binding var entries: [LineSuggestion.Entry]

    private var onField: Set<ObjectIdentifier> {
        Set(entries.map { ObjectIdentifier($0.player) })
    }

    private var bench: [Player] {
        available.filter { !onField.contains(ObjectIdentifier($0)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Section {
                ForEach(entries, id: \.player.persistentModelID) { entry in
                    HStack {
                        Text(entry.player.name)
                        Spacer()
                        if entry.player.gender == .x {
                            Button(entry.matching.displayName) {
                                toggleMatching(entry)
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
                            removeFromLine(entry)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("\(header) (\(entries.count)/5)")
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
    }

    private func toggleMatching(_ entry: LineSuggestion.Entry) {
        guard let i = entries.firstIndex(where: { $0.player.persistentModelID == entry.player.persistentModelID }) else { return }
        let newMatching: GenderMatching = entry.matching == .bx ? .gx : .bx
        entries[i] = LineSuggestion.Entry(player: entry.player, matching: newMatching)
    }

    private func removeFromLine(_ entry: LineSuggestion.Entry) {
        entries.removeAll { $0.player.persistentModelID == entry.player.persistentModelID }
    }

    private func addToLine(_ player: Player) {
        guard entries.count < 5 else { return }
        entries.append(LineSuggestion.Entry(player: player, matching: player.effectiveMatching))
    }
}
