import SwiftUI
import SwiftData

struct GameDetailView: View {
    let game: Game

    private var playerStats: [(player: Player, points: Int, goals: Int, assists: Int)] {
        var stats: [PersistentIdentifier: (points: Int, goals: Int, assists: Int)] = [:]
        var playerLookup: [PersistentIdentifier: Player] = [:]

        for point in game.points {
            for pp in point.onFieldPlayers {
                let id = pp.player.persistentModelID
                playerLookup[id] = pp.player
                stats[id, default: (0, 0, 0)].points += 1
            }
            if let scorer = point.scorer {
                let id = scorer.persistentModelID
                playerLookup[id] = scorer
                stats[id, default: (0, 0, 0)].goals += 1
            }
            if let assist = point.assist {
                let id = assist.persistentModelID
                playerLookup[id] = assist
                stats[id, default: (0, 0, 0)].assists += 1
            }
        }

        return stats.map { (playerLookup[$0.key]!, $0.value.points, $0.value.goals, $0.value.assists) }
            .sorted { $0.points > $1.points }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack {
                        Text("\(game.ourScore) - \(game.theirScore)")
                            .font(.largeTitle.bold().monospacedDigit())
                        Text("vs \(game.opponent)")
                        Text(game.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            Section("Player Stats") {
                HStack {
                    Text("Player").bold()
                    Spacer()
                    Text("Pts").bold().frame(width: 40)
                    Text("G").bold().frame(width: 30)
                    Text("A").bold().frame(width: 30)
                }
                .font(.caption)

                ForEach(playerStats, id: \.player.persistentModelID) { stat in
                    HStack {
                        Text(stat.player.name)
                        Spacer()
                        Text("\(stat.points)").frame(width: 40)
                        Text("\(stat.goals)").frame(width: 30)
                        Text("\(stat.assists)").frame(width: 30)
                    }
                    .font(.body.monospacedDigit())
                }
            }
        }
        .navigationTitle("Game Detail")
    }
}
