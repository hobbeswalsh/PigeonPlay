import SwiftUI
import SwiftData

struct GameView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Game> { $0.isActive }) private var activeGames: [Game]
    @Query(sort: \Player.name) private var allPlayers: [Player]

    @State private var showingNewGame = false
    @State private var opponentName = ""
    @State private var checkedInPlayerIDs: Set<PersistentIdentifier> = []

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
                    checkedInPlayerIDs: $checkedInPlayerIDs,
                    onCreate: createGame
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingNewGame = false
                            opponentName = ""
                            checkedInPlayerIDs = []
                        }
                    }
                }
            }
        }
    }

    private func createGame() {
        let game = Game(opponent: opponentName, date: Date())
        game.availablePlayers = allPlayers.filter {
            checkedInPlayerIDs.contains($0.persistentModelID)
        }
        modelContext.insert(game)
        showingNewGame = false
        opponentName = ""
        checkedInPlayerIDs = []
    }
}
