import SwiftUI
import SwiftData

struct GameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SaveFailureReporter.self) private var saveFailures
    @Query(filter: #Predicate<Game> { $0.isActive }) private var activeGames: [Game]
    @Query(sort: \Player.name) private var allPlayers: [Player]

    @State private var showingNewGame = false
    @State private var opponentName = ""
    @State private var checkedInPlayerIDs: Set<PersistentIdentifier> = []
    @State private var lineSize = 5
    @State private var ratioSequence: RatioSequence = .alternating
    @State private var startingRatio: GenderRatio = .twoBThreeG

    private var activeGame: Game? { activeGames.first }

    var body: some View {
        NavigationStack {
            if let game = activeGame {
                ActiveGameView(game: game)
            } else {
                ContentUnavailableView {
                    Label("No Active Game", systemImage: "sportscourt")
                } description: {
                    Text("Start a new game to begin tracking.")
                } actions: {
                    Button("New Game") { showingNewGame = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Game")
        .sheet(isPresented: $showingNewGame) {
            NavigationStack {
                NewGameFlow(
                    opponentName: $opponentName,
                    lineSize: $lineSize,
                    ratioSequence: $ratioSequence,
                    startingRatio: $startingRatio,
                    checkedInPlayerIDs: $checkedInPlayerIDs,
                    onCreate: createGame
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingNewGame = false
                            resetNewGameForm()
                        }
                    }
                }
            }
        }
    }

    private func createGame() {
        // Resolved before the game exists, so a failure here cannot leave
        // a game filed under no season and hidden from History.
        let season: Season
        do {
            season = try Seasons.current(in: modelContext)
        } catch {
            saveFailures.failure = error
            return
        }

        let game = Game(
            opponent: opponentName,
            date: Date(),
            lineSize: lineSize,
            ratioSequence: ratioSequence,
            startingRatio: startingRatio
        )
        game.availablePlayers = allPlayers.filter {
            checkedInPlayerIDs.contains($0.persistentModelID)
        }
        game.season = season
        modelContext.insert(game)
        modelContext.saveNow(reporting: saveFailures)
        showingNewGame = false
        resetNewGameForm()
    }

    private func resetNewGameForm() {
        opponentName = ""
        checkedInPlayerIDs = []
        lineSize = 5
        ratioSequence = .alternating
        startingRatio = .twoBThreeG
    }
}
