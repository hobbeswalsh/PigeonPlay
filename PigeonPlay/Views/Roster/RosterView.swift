import SwiftUI
import SwiftData

struct RosterView: View {
    @Query(sort: \Player.name) private var players: [Player]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddPlayer = false

    private var boyPlayers: [Player] { players.filter { $0.gender == .b } }
    private var girlPlayers: [Player] { players.filter { $0.gender == .g } }
    private var xPlayers: [Player] { players.filter { $0.gender == .x } }

    var body: some View {
        NavigationStack {
            List {
                if !boyPlayers.isEmpty {
                    Section("Boys") {
                        ForEach(boyPlayers) { player in
                            NavigationLink(value: player) {
                                PlayerRow(player: player)
                            }
                        }
                        .onDelete { offsets in
                            delete(offsets, from: boyPlayers)
                        }
                    }
                }
                if !girlPlayers.isEmpty {
                    Section("Girls") {
                        ForEach(girlPlayers) { player in
                            NavigationLink(value: player) {
                                PlayerRow(player: player)
                            }
                        }
                        .onDelete { offsets in
                            delete(offsets, from: girlPlayers)
                        }
                    }
                }
                if !xPlayers.isEmpty {
                    Section("X") {
                        ForEach(xPlayers) { player in
                            NavigationLink(value: player) {
                                PlayerRow(player: player)
                            }
                        }
                        .onDelete { offsets in
                            delete(offsets, from: xPlayers)
                        }
                    }
                }
            }
            .navigationTitle("Roster")
            .navigationDestination(for: Player.self) { player in
                PlayerFormView(player: player)
            }
            .toolbar {
                Button("Add Player", systemImage: "plus") {
                    showingAddPlayer = true
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                NavigationStack {
                    PlayerFormView(player: nil)
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet, from group: [Player]) {
        for index in offsets {
            modelContext.delete(group[index])
        }
    }
}

struct PlayerRow: View {
    let player: Player

    var body: some View {
        HStack {
            Text(player.name)
            Spacer()
            if let matching = player.defaultMatching {
                Text(matching.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
