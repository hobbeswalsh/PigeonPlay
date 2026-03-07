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

struct NewGameFlow: View {
    @Binding var opponentName: String
    @Binding var checkedInPlayerIDs: Set<PersistentIdentifier>
    let onCreate: () -> Void

    @State private var showingCheckIn = false

    var body: some View {
        Form {
            Section("Opponent") {
                TextField("Team name", text: $opponentName)
            }
            Section {
                Button("Next: Check In Players") {
                    showingCheckIn = true
                }
                .disabled(opponentName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("New Game")
        .navigationDestination(isPresented: $showingCheckIn) {
            CheckInView(
                checkedInPlayers: $checkedInPlayerIDs,
                onConfirm: onCreate
            )
        }
    }
}

struct ActiveGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var game: Game

    @State private var currentRatio: GenderRatio = .twoBThreeG
    @State private var selectedLine: [LineSuggestion.Entry] = []
    @State private var phase: GamePhase = .selectingLine
    @State private var showingAvailability = false
    @State private var queuedLine: [LineSuggestion.Entry] = []
    @State private var queuedRatio: GenderRatio = .twoBThreeG

    enum GamePhase {
        case selectingLine
        case recordingPoint
    }

    private var pointsPlayed: [Player: Int] {
        var counts: [Player: Int] = [:]
        for player in game.availablePlayers {
            counts[player] = 0
        }
        for point in game.points {
            for pp in point.onFieldPlayers {
                counts[pp.player, default: 0] += 1
            }
        }
        return counts
    }

    private var lastPointOnBench: [Player: Int] {
        var last: [Player: Int] = [:]
        for (index, point) in game.points.enumerated() {
            let playedIDs = Set(point.onFieldPlayers.map { ObjectIdentifier($0.player) })
            for player in game.availablePlayers where !playedIDs.contains(ObjectIdentifier(player)) {
                last[player] = index + 1
            }
        }
        return last
    }

    var body: some View {
        VStack {
            // Scoreboard
            HStack {
                VStack {
                    Text("Us")
                        .font(.caption)
                    Text("\(game.ourScore)")
                        .font(.largeTitle.bold())
                }
                Spacer()
                VStack {
                    Text("Point \(game.points.count + 1)")
                        .font(.caption)
                    Text("vs \(game.opponent)")
                        .font(.headline)
                }
                Spacer()
                VStack {
                    Text("Them")
                        .font(.caption)
                    Text("\(game.theirScore)")
                        .font(.largeTitle.bold())
                }
            }
            .padding()

            Divider()

            switch phase {
            case .selectingLine:
                // Ratio picker
                Picker("Ratio", selection: $currentRatio) {
                    Text("2B / 3G").tag(GenderRatio.twoBThreeG)
                    Text("3B / 2G").tag(GenderRatio.threeBTwoG)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: currentRatio) {
                    suggestLine()
                }

                ScrollView {
                    LineSelectionView(
                        available: game.availablePlayers,
                        ratio: currentRatio,
                        pointsPlayed: pointsPlayed,
                        lastPointOnBench: lastPointOnBench,
                        selectedLine: $selectedLine
                    )
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button("Shuffle", systemImage: "shuffle") {
                            suggestLine()
                        }
                        .buttonStyle(.bordered)

                        Button("Lock In") {
                            phase = .recordingPoint
                            queuedRatio = currentRatio.alternated
                            let suggestion = LineSuggester.suggest(
                                available: game.availablePlayers,
                                ratio: queuedRatio,
                                pointsPlayed: pointsPlayed,
                                lastPointOnBench: lastPointOnBench,
                                excluding: Set(selectedLine.map(\.player))
                            )
                            queuedLine = suggestion.allEntries
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedLine.count != 5)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }

            case .recordingPoint:
                ScrollView {
                    RecordPointView(onFieldPlayers: selectedLine) { outcome, scorer, assist in
                        recordPoint(outcome: outcome, scorer: scorer, assist: assist)
                    }
                    .padding(.bottom, 80)
                }
                .sheet(isPresented: .constant(true)) {
                    NextLineQueueView(
                        available: game.availablePlayers,
                        pointsPlayed: pointsPlayed,
                        lastPointOnBench: lastPointOnBench,
                        queuedLine: $queuedLine,
                        queuedRatio: $queuedRatio
                    )
                    .presentationDetents([.fraction(0.08), .medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button("Undo Last Point", systemImage: "arrow.uturn.backward") {
                    undoPoint()
                }
                .disabled(game.points.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Players", systemImage: "person.badge.plus") {
                    showingAvailability = true
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("End Game", systemImage: "xmark.circle") {
                    game.isActive = false
                }
                .tint(.red)
            }
        }
        .sheet(isPresented: $showingAvailability) {
            NavigationStack {
                AvailabilityView(game: game)
            }
        }
    }

    private func suggestLine() {
        selectedLine = []
        let suggestion = LineSuggester.suggest(
            available: game.availablePlayers,
            ratio: currentRatio,
            pointsPlayed: pointsPlayed,
            lastPointOnBench: lastPointOnBench
        )
        selectedLine = suggestion.allEntries
    }

    private func undoPoint() {
        if let undone = game.undoLastPoint() {
            currentRatio = undone.ratio
            selectedLine = []
            queuedLine = []
            phase = .selectingLine
        }
    }

    private func recordPoint(outcome: PointOutcome, scorer: Player?, assist: Player?) {
        let pointPlayers = selectedLine.map { entry in
            PointPlayer(player: entry.player, effectiveGender: entry.matching)
        }
        let point = GamePoint(
            number: game.points.count + 1,
            ratio: currentRatio,
            outcome: outcome,
            onFieldPlayers: pointPlayers,
            scorer: scorer,
            assist: assist
        )
        game.points.append(point)

        if queuedLine.isEmpty {
            currentRatio = currentRatio.alternated
            selectedLine = []
        } else {
            currentRatio = queuedRatio
            selectedLine = queuedLine
            queuedLine = []
        }
        phase = .selectingLine
    }
}

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
