import SwiftUI
import SwiftData

enum GamePhase {
    case selectingLine
    case recordingPoint
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
    @State private var showingQueue = false

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

    /// Points played adjusted for the in-progress point: on-field players get +1.
    private var pointsPlayedIncludingCurrentPoint: [Player: Int] {
        LineSuggester.countingCurrentPoint(
            pointsPlayed: pointsPlayed,
            onFieldPlayers: selectedLine.map(\.player)
        )
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
                Picker("Ratio", selection: Binding(
                    get: { currentRatio },
                    set: { newValue in
                        currentRatio = newValue
                        suggestLine()
                    }
                )) {
                    Text("2B / 3G").tag(GenderRatio.twoBThreeG)
                    Text("3B / 2G").tag(GenderRatio.threeBTwoG)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

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
                                pointsPlayed: pointsPlayedIncludingCurrentPoint,
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
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Button {
                            withAnimation { showingQueue.toggle() }
                        } label: {
                            HStack {
                                Text("Next: \(queuedRatio.displayName)")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("\(queuedLine.count)/5 ready")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Image(systemName: showingQueue ? "chevron.down" : "chevron.up")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        .tint(.primary)

                        if showingQueue {
                            Divider()
                            NextLineQueueView(
                                available: game.availablePlayers,
                                pointsPlayed: pointsPlayedIncludingCurrentPoint,
                                lastPointOnBench: lastPointOnBench,
                                queuedLine: $queuedLine,
                                queuedRatio: $queuedRatio
                            )
                            .frame(maxHeight: 350)
                        }
                    }
                    .background(.ultraThinMaterial)
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
