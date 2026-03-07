import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<Game> { !$0.isActive },
        sort: \Game.date,
        order: .reverse
    ) private var games: [Game]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(games) { game in
                    NavigationLink(value: game) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("vs \(game.opponent)")
                                    .font(.headline)
                                Text(game.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(game.ourScore) - \(game.theirScore)")
                                .font(.title3.monospacedDigit())
                                .foregroundStyle(game.ourScore > game.theirScore ? .green : game.ourScore < game.theirScore ? .red : .secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(games[index])
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Game.self) { game in
                GameDetailView(game: game)
            }
        }
    }
}
