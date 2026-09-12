import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<Game> { !$0.isActive },
        sort: \Game.date,
        order: .reverse
    ) private var games: [Game]
    @Query(sort: \Season.startedAt, order: .reverse) private var seasons: [Season]
    @Environment(\.modelContext) private var modelContext
    @Environment(SaveFailureReporter.self) private var saveFailures

    /// Nil means every season. Set on appear to the current one, so the
    /// coach opens History on the season they are actually playing.
    @State private var selectedSeasonID: PersistentIdentifier?

    private var visibleGames: [Game] {
        guard let selectedSeasonID else { return games }
        return games.filter { $0.season?.persistentModelID == selectedSeasonID }
    }

    private var selectedSeasonName: String {
        seasons.first { $0.persistentModelID == selectedSeasonID }?.name ?? "All seasons"
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleGames.isEmpty {
                    ContentUnavailableView {
                        Label("No Games", systemImage: "clock")
                    } description: {
                        Text("Games you finish in \(selectedSeasonName) will appear here.")
                    }
                } else {
                    gameList
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !seasons.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        seasonMenu
                    }
                }
            }
            .navigationDestination(for: Game.self) { game in
                GameDetailView(game: game)
            }
        }
        .task {
            guard selectedSeasonID == nil else { return }
            selectedSeasonID = seasons.first { $0.isCurrent }?.persistentModelID
        }
    }

    private var gameList: some View {
        List {
            ForEach(visibleGames) { game in
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
                // Indexes are into the filtered list, not the query.
                for game in offsets.map({ visibleGames[$0] }) {
                    modelContext.delete(game)
                }
                modelContext.saveNow(reporting: saveFailures)
            }
        }
    }

    private var seasonMenu: some View {
        Menu {
            Picker("Season", selection: $selectedSeasonID) {
                Text("All seasons").tag(PersistentIdentifier?.none)
                ForEach(seasons) { season in
                    Text(season.isCurrent ? "\(season.name) (current)" : season.name)
                        .tag(PersistentIdentifier?.some(season.persistentModelID))
                }
            }
        } label: {
            Label(selectedSeasonName, systemImage: "calendar")
        }
    }
}
