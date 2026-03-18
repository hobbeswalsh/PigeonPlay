import SwiftUI
import SwiftData

struct AvailabilityView: View {
    @Bindable var game: Game
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Environment(\.dismiss) private var dismiss

    private var availableIDs: Set<PersistentIdentifier> {
        Set(game.availablePlayers.map(\.persistentModelID))
    }

    var body: some View {
        List {
            ForEach(allPlayers) { player in
                Button {
                    toggle(player)
                } label: {
                    HStack {
                        Image(systemName: availableIDs.contains(player.persistentModelID) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(availableIDs.contains(player.persistentModelID) ? .green : .secondary)
                        Text(player.name)
                        Spacer()
                        Text(player.gender.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
        }
        .navigationTitle("Available Players")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func toggle(_ player: Player) {
        if let index = game.availablePlayers.firstIndex(where: { $0.persistentModelID == player.persistentModelID }) {
            game.availablePlayers.remove(at: index)
        } else {
            game.availablePlayers.append(player)
        }
    }
}
