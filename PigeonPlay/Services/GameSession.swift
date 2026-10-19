import Foundation
import SwiftData

/// Owns the point-by-point flow of an active game: which line is picked,
/// which is queued behind it, the ratio each is built for, and whether the
/// coach is choosing or recording.
///
/// The flow lives here, not in the view, for two reasons. A view that holds
/// this state in `@State` loses it when iOS ends the app between "Lock In"
/// and "record point". And the transitions - lock in, record, undo - cannot
/// be tested while they are private methods of a `View`.
@MainActor
@Observable
final class GameSession {
    let game: Game
    private let context: ModelContext
    private let reporter: SaveFailureReporter

    private(set) var phase: GamePhase
    private(set) var currentRatio: GenderRatio
    private(set) var queuedRatio: GenderRatio
    private(set) var selectedLine: [LineSuggestion.Entry]
    private(set) var queuedLine: [LineSuggestion.Entry]

    /// Restores whatever the game stored. A game that never had a line
    /// stored starts empty, with each ratio derived from the sequence.
    init(game: Game, context: ModelContext, reporter: SaveFailureReporter) {
        self.game = game
        self.context = context
        self.reporter = reporter

        let selected = Self.entries(of: .selected, in: game)
        selectedLine = selected
        queuedLine = Self.entries(of: .queued, in: game)
        currentRatio = game.currentRatioOverride ?? game.nextRatio
        queuedRatio = game.queuedRatioOverride
            ?? game.ratio(forPointNumber: game.nextPointNumber + 1)

        // Recording a point for an empty field has no meaning. This happens
        // when every locked-in player was deleted while the app was closed.
        phase = game.inFlightPhase == .recordingPoint && selected.isEmpty
            ? .selectingLine
            : game.inFlightPhase
    }

    /// A slot whose player was deleted is dropped here on purpose: the
    /// relationship nullifies, so there is nobody left to put on the field.
    private static func entries(of kind: LineKind, in game: Game) -> [LineSuggestion.Entry] {
        (game.lineSlots ?? [])
            .filter { $0.kind == kind }
            .sorted { $0.position < $1.position }
            .compactMap { slot in
                slot.player.map { LineSuggestion.Entry(player: $0, matching: slot.matching) }
            }
    }

    /// Points played, with the players now on the field counted once more:
    /// the point in progress is not recorded yet, but it already counts
    /// against their rest when the next line is suggested.
    var pointsPlayedIncludingCurrentPoint: [Player: Int] {
        LineSuggester.countingCurrentPoint(
            pointsPlayed: game.pointsPlayed,
            onFieldPlayers: selectedLine.map(\.player)
        )
    }

    func setSelectedLine(_ line: [LineSuggestion.Entry]) {
        selectedLine = line
        persist()
    }

    func setQueuedLine(_ line: [LineSuggestion.Entry]) {
        queuedLine = line
        persist()
    }

    func setCurrentRatio(_ ratio: GenderRatio) {
        currentRatio = ratio
        persist()
    }

    func setQueuedRatio(_ ratio: GenderRatio) {
        queuedRatio = ratio
        persist()
    }

    func suggestLine() {
        let suggestion = LineSuggester.suggest(
            available: game.availablePlayers ?? [],
            ratio: currentRatio,
            lineSize: game.lineSize,
            pointsPlayed: game.pointsPlayed,
            lastPointOnBench: game.lastPointOnBench
        )
        setSelectedLine(suggestion.allEntries)
    }

    func lockIn() {
        phase = .recordingPoint
        queuedRatio = game.ratio(forPointNumber: game.nextPointNumber + 1)
        let suggestion = LineSuggester.suggest(
            available: game.availablePlayers ?? [],
            ratio: queuedRatio,
            lineSize: game.lineSize,
            pointsPlayed: pointsPlayedIncludingCurrentPoint,
            lastPointOnBench: game.lastPointOnBench,
            excluding: Set(selectedLine.map(\.player))
        )
        queuedLine = suggestion.allEntries
        persist()
    }

    /// Records the point on the field and moves the queued line up to take
    /// its place. The point and the new lines save together, so a relaunch
    /// never sees a recorded point with the old line still locked in.
    func recordPoint(outcome: PointOutcome, scorer: Player?, assist: Player?) {
        let pointPlayers = selectedLine.map { entry in
            PointPlayer(player: entry.player, effectiveGender: entry.matching)
        }
        let point = GamePoint(
            number: game.nextPointNumber,
            ratio: currentRatio,
            outcome: outcome,
            onFieldPlayers: pointPlayers,
            scorer: scorer,
            assist: assist
        )
        game.points = (game.points ?? []) + [point]

        if queuedLine.isEmpty {
            currentRatio = game.nextRatio
            selectedLine = []
        } else {
            currentRatio = queuedRatio
            selectedLine = queuedLine
            queuedLine = []
        }
        queuedRatio = game.ratio(forPointNumber: game.nextPointNumber + 1)
        phase = .selectingLine
        persist()
    }

    func undoPoint() {
        guard let undone = game.undoLastPoint() else { return }

        // Read before persisting: `undone` is deleted, and a deleted model
        // may not be read once the delete is saved.
        currentRatio = undone.ratio
        queuedRatio = game.ratio(forPointNumber: game.nextPointNumber + 1)
        selectedLine = []
        queuedLine = []
        phase = .selectingLine
        persist()
    }

    /// Drops players who were just marked unavailable from both lines.
    func reconcileLines() {
        let available = Set((game.availablePlayers ?? []).map(\.persistentModelID))
        selectedLine.removeAll { !available.contains($0.player.persistentModelID) }
        queuedLine.removeAll { !available.contains($0.player.persistentModelID) }
        persist()
    }

    /// Writes the whole flow state onto the game and saves at once. iOS can
    /// end a backgrounded app between taps, and autosave makes no promise
    /// to have run by then.
    private func persist() {
        game.inFlightPhase = phase
        game.currentRatioOverride = currentRatio
        game.queuedRatioOverride = queuedRatio
        replaceSlots()
        context.saveNow(reporting: reporter)
    }

    // Rewritten whole rather than diffed: a line is five or seven rows, and
    // a diff would have to track reorders and swaps for no gain.
    private func replaceSlots() {
        for slot in game.lineSlots ?? [] {
            context.delete(slot)
        }
        game.lineSlots = slots(for: selectedLine, kind: .selected)
            + slots(for: queuedLine, kind: .queued)
    }

    private func slots(for line: [LineSuggestion.Entry], kind: LineKind) -> [LineSlot] {
        line.enumerated().map { position, entry in
            LineSlot(kind: kind, position: position, player: entry.player, matching: entry.matching)
        }
    }
}
