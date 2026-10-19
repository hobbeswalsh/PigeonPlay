import SwiftUI
import SwiftData

struct ActiveGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SaveFailureReporter.self) private var saveFailures
    @Bindable var game: Game

    // Built in `.task` because a view's init cannot read the environment
    // the session needs. Keyed on the game so a new game gets a new session.
    @State private var session: GameSession?
    @State private var showingAvailability = false
    @State private var showingQueue = false
    @State private var showingEndGameConfirmation = false

    var body: some View {
        Group {
            if let session {
                content(session)
            } else {
                ProgressView()
            }
        }
        .task(id: ObjectIdentifier(game)) {
            session = GameSession(game: game, context: modelContext, reporter: saveFailures)
        }
    }

    private func content(_ session: GameSession) -> some View {
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
                    Text("Point \(game.nextPointNumber)")
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

            switch session.phase {
            case .selectingLine:
                // Ratio picker
                Picker("Ratio", selection: Binding(
                    get: { session.currentRatio },
                    set: { newValue in
                        session.setCurrentRatio(newValue)
                        session.suggestLine()
                    }
                )) {
                    Text(GenderRatio.twoBThreeG.composition(lineSize: game.lineSize).displayName)
                        .tag(GenderRatio.twoBThreeG)
                    Text(GenderRatio.threeBTwoG.composition(lineSize: game.lineSize).displayName)
                        .tag(GenderRatio.threeBTwoG)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView {
                    LineSelectionView(
                        available: game.availablePlayers ?? [],
                        ratio: session.currentRatio,
                        lineSize: game.lineSize,
                        pointsPlayed: game.pointsPlayed,
                        lastPointOnBench: game.lastPointOnBench,
                        selectedLine: Binding(
                            get: { session.selectedLine },
                            set: { session.setSelectedLine($0) }
                        )
                    )
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button("Shuffle", systemImage: "shuffle") {
                            session.suggestLine()
                        }
                        .buttonStyle(.bordered)

                        Button("Lock In") {
                            session.lockIn()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!game.canLockIn(session.selectedLine))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }

            case .recordingPoint:
                offRatioNote(session)

                ScrollView {
                    RecordPointView(onFieldPlayers: session.selectedLine) { outcome, scorer, assist in
                        session.recordPoint(outcome: outcome, scorer: scorer, assist: assist)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Button {
                            withAnimation { showingQueue.toggle() }
                        } label: {
                            HStack {
                                Text("Next: \(session.queuedRatio.composition(lineSize: game.lineSize).displayName)")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("\(session.queuedLine.count)/\(game.lineSize) ready")
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
                                available: game.availablePlayers ?? [],
                                lineSize: game.lineSize,
                                pointsPlayed: session.pointsPlayedIncludingCurrentPoint,
                                lastPointOnBench: game.lastPointOnBench,
                                queuedLine: Binding(
                                    get: { session.queuedLine },
                                    set: { session.setQueuedLine($0) }
                                ),
                                queuedRatio: Binding(
                                    get: { session.queuedRatio },
                                    set: { session.setQueuedRatio($0) }
                                )
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
                    session.undoPoint()
                }
                .disabled((game.points ?? []).isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Players", systemImage: "person.badge.plus") {
                    showingAvailability = true
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("End Game", systemImage: "xmark.circle") {
                    showingEndGameConfirmation = true
                }
                .tint(.red)
            }
        }
        .alert("End Game?", isPresented: $showingEndGameConfirmation) {
            Button("End Game", role: .destructive) {
                game.isActive = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to end this game? This cannot be undone.")
        }
        .sheet(isPresented: $showingAvailability, onDismiss: { session.reconcileLines() }) {
            NavigationStack {
                AvailabilityView(game: game)
            }
        }
    }

    /// A small reminder when the line on the field does not match the
    /// called ratio, e.g. only boys were left to fill the G slots.
    @ViewBuilder
    private func offRatioNote(_ session: GameSession) -> some View {
        let called = session.currentRatio.composition(lineSize: game.lineSize)
        let playing = LineComposition(of: session.selectedLine)

        if playing != called {
            Label("Playing \(playing.displayName) (called \(called.displayName))",
                  systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.top, 4)
        }
    }
}
