import SwiftUI
import SwiftData

struct CheckInView: View {
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Binding var checkedInPlayers: Set<PersistentIdentifier>
    let onConfirm: () -> Void

    var body: some View {
        List {
            ForEach(allPlayers) { player in
                Button {
                    toggle(player)
                } label: {
                    HStack {
                        Image(systemName: checkedInPlayers.contains(player.persistentModelID) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkedInPlayers.contains(player.persistentModelID) ? .green : .secondary)
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
        .navigationTitle("Who's Here?")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Start Game") { onConfirm() }
                    .disabled(checkedInPlayers.isEmpty)
            }
        }
    }

    private func toggle(_ player: Player) {
        if checkedInPlayers.contains(player.persistentModelID) {
            checkedInPlayers.remove(player.persistentModelID)
        } else {
            checkedInPlayers.insert(player.persistentModelID)
        }
    }
}
