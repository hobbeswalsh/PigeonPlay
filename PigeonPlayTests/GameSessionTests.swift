import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

extension StoreTests {
@MainActor @Suite struct GameSessionFlow {

// Four B-matching and four G-matching players, all available, so every
// ratio and a line of five can be filled from either side.
@MainActor private struct Fixture {
    let container: ModelContainer
    let context: ModelContext
    let game: Game
    let players: [Player]
    let reporter = SaveFailureReporter()

    func makeSession() -> GameSession {
        GameSession(game: game, context: context, reporter: reporter)
    }
}

private func makeFixture() throws -> Fixture {
    let container = try ModelContainer(
        for: Player.self, Game.self, GamePoint.self, PointPlayer.self,
            SavedPlay.self, Season.self, LineSlot.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)

    let names = ["Alex", "Ben", "Cal", "Dan", "Dee", "Eve", "Fay", "Gia"]
    let players = names.enumerated().map { index, name in
        Player(name: name, gender: index < 4 ? .b : .g)
    }
    for player in players { context.insert(player) }

    let game = Game(opponent: "Hawks", date: Date())
    context.insert(game)
    game.availablePlayers = players
    try context.save()

    return Fixture(container: container, context: context, game: game, players: players)
}

private func names(_ line: [LineSuggestion.Entry]) -> [String] {
    line.map(\.player.name)
}

private func matchings(_ line: [LineSuggestion.Entry]) -> [GenderMatching] {
    line.map(\.matching)
}

@Test func freshGameStartsSelectingWithNoLines() throws {
    let fixture = try makeFixture()

    let session = fixture.makeSession()

    #expect(session.phase == .selectingLine)
    #expect(session.selectedLine.isEmpty)
    #expect(session.queuedLine.isEmpty)
    #expect(session.currentRatio == fixture.game.nextRatio)
    #expect(session.queuedRatio == fixture.game.ratio(forPointNumber: 2))
}

@Test func lockedInLinesSurviveARestore() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.suggestLine()
    session.lockIn()
    #expect(session.selectedLine.count == 5)
    #expect(session.queuedLine.count == 5)

    let restored = fixture.makeSession()

    #expect(restored.phase == .recordingPoint)
    #expect(names(restored.selectedLine) == names(session.selectedLine))
    #expect(matchings(restored.selectedLine) == matchings(session.selectedLine))
    #expect(names(restored.queuedLine) == names(session.queuedLine))
    #expect(matchings(restored.queuedLine) == matchings(session.queuedLine))
    #expect(restored.currentRatio == session.currentRatio)
    #expect(restored.queuedRatio == session.queuedRatio)
}

// The sequence prescribes 2B/3G for point 1, so a restore that only
// re-derived the ratio would lose this override.
@Test func aManualRatioOverrideSurvivesARestore() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.setCurrentRatio(.threeBTwoG)
    session.suggestLine()

    let restored = fixture.makeSession()

    #expect(fixture.game.nextRatio == .twoBThreeG)
    #expect(restored.currentRatio == .threeBTwoG)
    #expect(names(restored.selectedLine) == names(session.selectedLine))
}

@Test func reconcileDropsAnUnavailablePlayerFromBothLinesAndTheStore() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.suggestLine()
    session.lockIn()
    let benched = try #require(session.selectedLine.first?.player)

    fixture.game.availablePlayers?.removeAll { $0 == benched }
    session.reconcileLines()

    #expect(!names(session.selectedLine).contains(benched.name))
    #expect(!names(session.queuedLine).contains(benched.name))

    let restored = fixture.makeSession()
    #expect(restored.selectedLine.count == 4)
    #expect(!names(restored.selectedLine).contains(benched.name))
    #expect(!names(restored.queuedLine).contains(benched.name))
}

@Test func recordingAPointPromotesTheQueuedLineAndSurvivesARestore() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.suggestLine()
    session.lockIn()
    let playedNames = names(session.selectedLine)
    let queuedNames = names(session.queuedLine)

    session.recordPoint(outcome: .them, scorer: nil, assist: nil)

    #expect(fixture.game.sortedPoints.count == 1)
    let point = try #require(fixture.game.sortedPoints.first)
    #expect(Set((point.onFieldPlayers ?? []).compactMap { $0.player?.name }) == Set(playedNames))
    #expect(session.phase == .selectingLine)
    #expect(names(session.selectedLine) == queuedNames)
    #expect(session.queuedLine.isEmpty)
    #expect(session.currentRatio == fixture.game.ratio(forPointNumber: 2))

    let restored = fixture.makeSession()
    #expect(restored.phase == .selectingLine)
    #expect(names(restored.selectedLine) == queuedNames)
    #expect(restored.currentRatio == session.currentRatio)
}

@Test func recordingAScoredPointKeepsScorerAndAssist() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.suggestLine()
    session.lockIn()
    let scorer = try #require(session.selectedLine.first?.player)
    let assist = try #require(session.selectedLine.last?.player)

    session.recordPoint(outcome: .us, scorer: scorer, assist: assist)

    let point = try #require(fixture.game.sortedPoints.first)
    #expect(point.scorer?.name == scorer.name)
    #expect(point.assist?.name == assist.name)
    #expect(fixture.game.ourScore == 1)
}

// Without a queued line the next point starts from nothing, on the ratio
// the sequence prescribes for it.
@Test func recordingWithNothingQueuedLeavesTheNextLineEmpty() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.suggestLine()
    session.lockIn()
    session.setQueuedLine([])

    session.recordPoint(outcome: .dead, scorer: nil, assist: nil)

    #expect(session.selectedLine.isEmpty)
    #expect(session.currentRatio == fixture.game.nextRatio)
    #expect(fixture.makeSession().selectedLine.isEmpty)
}

@Test func undoingAPointClearsBothLinesAndRestoresItsRatio() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.suggestLine()
    session.lockIn()
    session.recordPoint(outcome: .them, scorer: nil, assist: nil)
    #expect(session.currentRatio == .threeBTwoG)

    session.undoPoint()

    #expect(fixture.game.sortedPoints.isEmpty)
    #expect(session.selectedLine.isEmpty)
    #expect(session.queuedLine.isEmpty)
    #expect(session.phase == .selectingLine)
    #expect(session.currentRatio == .twoBThreeG)

    let restored = fixture.makeSession()
    #expect(restored.selectedLine.isEmpty)
    #expect(restored.currentRatio == .twoBThreeG)
}

@Test func undoingWithNoPointsChangesNothing() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.suggestLine()
    let line = names(session.selectedLine)

    session.undoPoint()

    #expect(names(session.selectedLine) == line)
    #expect(session.phase == .selectingLine)
}

// The closest a test gets to iOS ending the app mid-game: the store is
// closed with nothing saved after the lock-in except what the session
// saved itself, then opened again through the app's own plan.
@Test func aLockedInLineSurvivesClosingAndReopeningTheStore() throws {
    let url = URL.temporaryDirectory.appending(path: "session-\(UUID().uuidString).store")
    defer {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
        }
    }
    func openStore() throws -> ModelContext {
        let schema = Schema(versionedSchema: PlayerSchemaV6.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PlayerMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url)
        )
        return ModelContext(container)
    }

    var playedNames: [String] = []
    var queuedNames: [String] = []
    do {
        let context = try openStore()
        let players = ["Alex", "Ben", "Cal", "Dan", "Dee", "Eve", "Fay", "Gia"]
            .enumerated().map { Player(name: $1, gender: $0 < 4 ? .b : .g) }
        for player in players { context.insert(player) }
        let game = Game(opponent: "Hawks", date: Date())
        context.insert(game)
        game.availablePlayers = players
        try context.save()

        let session = GameSession(game: game, context: context, reporter: SaveFailureReporter())
        session.suggestLine()
        session.lockIn()
        playedNames = names(session.selectedLine)
        queuedNames = names(session.queuedLine)
    }
    #expect(playedNames.count == 5)

    let context = try openStore()
    let game = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    let restored = GameSession(game: game, context: context, reporter: SaveFailureReporter())

    #expect(restored.phase == .recordingPoint)
    #expect(names(restored.selectedLine) == playedNames)
    #expect(names(restored.queuedLine) == queuedNames)
}

@Test func aDeletedPlayerIsDroppedFromTheLineOnRestore() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.suggestLine()
    session.lockIn()
    let deleted = try #require(session.selectedLine.first?.player)
    let deletedName = deleted.name

    fixture.context.delete(deleted)
    try fixture.context.save()
    let restored = fixture.makeSession()

    #expect(!names(restored.selectedLine).contains(deletedName))
    #expect(restored.selectedLine.count == 4)
}

@Test func restoringWithNobodyLeftOnTheFieldFallsBackToSelecting() throws {
    let fixture = try makeFixture()
    let session = fixture.makeSession()
    session.suggestLine()
    session.lockIn()

    for entry in session.selectedLine { fixture.context.delete(entry.player) }
    try fixture.context.save()
    let restored = fixture.makeSession()

    #expect(restored.selectedLine.isEmpty)
    #expect(restored.phase == .selectingLine)
}

}
}
