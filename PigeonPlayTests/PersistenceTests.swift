import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

extension StoreTests {
@Suite struct Persistence {

private func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Schema(versionedSchema: PlayerSchemaV5.self),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

// MARK: - Migration plan wiring

// Round-trips an on-disk store through the same container configuration
// the app uses (V2 schema + migration plan). Catches a plan that cannot
// be evaluated - the original plan crashed container init with
// "Duplicate version checksums detected" the first time a migration was
// actually attempted.
@Test func storeRoundTripsThroughMigrationPlan() throws {
    let url = URL.temporaryDirectory.appending(path: "roundtrip-\(UUID().uuidString).store")
    defer {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
        }
    }

    do {
        let container = try ModelContainer(
            for: Schema(versionedSchema: PlayerSchemaV5.self),
            migrationPlan: PlayerMigrationPlan.self,
            configurations: ModelConfiguration(schema: Schema(versionedSchema: PlayerSchemaV5.self), url: url)
        )
        let context = ModelContext(container)
        context.insert(Player(name: "Alex", gender: .b, phoneNumber: "555-0100"))
        try context.save()
    }

    do {
        let container = try ModelContainer(
            for: Schema(versionedSchema: PlayerSchemaV5.self),
            migrationPlan: PlayerMigrationPlan.self,
            configurations: ModelConfiguration(schema: Schema(versionedSchema: PlayerSchemaV5.self), url: url)
        )
        let context = ModelContext(container)
        let players = try context.fetch(FetchDescriptor<Player>())
        #expect(players.count == 1)
        #expect(players.first?.name == "Alex")
        #expect(players.first?.phoneNumber == "555-0100")
        #expect(players.first?.contactIdentifiers == [])
    }
}

// MARK: - Delete rules

@Test func deletingGameCascadesToPointsAndPointPlayers() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)

    let player = Player(name: "Alex", gender: .b)
    let game = Game(opponent: "Hawks", date: Date())
    context.insert(player)
    context.insert(game)
    let pp = PointPlayer(player: player, effectiveGender: .bx)
    let point = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .them, onFieldPlayers: [pp])
    game.points = (game.points ?? []) + [point]
    try context.save()

    context.delete(game)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<GamePoint>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<PointPlayer>()).isEmpty)
    // Roster players survive game deletion
    #expect(try context.fetch(FetchDescriptor<Player>()).count == 1)
}

@Test func undoLastPointDeletesThePointFromTheStore() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)

    let player = Player(name: "Alex", gender: .b)
    let game = Game(opponent: "Hawks", date: Date())
    context.insert(player)
    context.insert(game)
    let pp = PointPlayer(player: player, effectiveGender: .bx)
    let point = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .them, onFieldPlayers: [pp])
    game.points = (game.points ?? []) + [point]
    try context.save()

    let undone = game.undoLastPoint()
    try context.save()

    #expect(undone != nil)
    #expect((game.points ?? []).isEmpty)
    #expect(try context.fetch(FetchDescriptor<GamePoint>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<PointPlayer>()).isEmpty)
}

@Test func undoLastPointOutsideContextStillRemovesFromArray() {
    let game = Game(opponent: "Hawks", date: Date())
    let point = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .them)
    game.points = [point]

    let undone = game.undoLastPoint()
    #expect(undone === point)
    #expect((game.points ?? []).isEmpty)
}

// MARK: - Game.involves

@Test func involvesFindsOnFieldScorerAndAssistPlayers() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)

    let fielder = Player(name: "Fielder", gender: .g)
    let scorer = Player(name: "Scorer", gender: .b)
    let assist = Player(name: "Assist", gender: .g)
    let benched = Player(name: "Benched", gender: .b)
    let game = Game(opponent: "Hawks", date: Date())
    for player in [fielder, scorer, assist, benched] { context.insert(player) }
    context.insert(game)
    game.availablePlayers = [fielder, scorer, assist, benched]

    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .us,
        onFieldPlayers: [PointPlayer(player: fielder, effectiveGender: .gx)],
        scorer: scorer,
        assist: assist
    )
    game.points = (game.points ?? []) + [point]
    try context.save()

    #expect(game.involves(fielder))
    #expect(game.involves(scorer))
    #expect(game.involves(assist))
    // Available but never on a recorded point: safe to delete
    #expect(!game.involves(benched))
}

// MARK: - Deletion guard scopes to the current season

@Test func onlyCurrentSeasonAppearancesProtectAPlayerFromDeletion() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)

    let archived = Season(name: "2024", startedAt: Date(timeIntervalSince1970: 0))
    archived.endedAt = Date(timeIntervalSince1970: 1)
    let current = Season(name: "2025", startedAt: Date())
    context.insert(archived)
    context.insert(current)

    let departed = Player(name: "Departed", gender: .b)
    let returning = Player(name: "Returning", gender: .g)
    context.insert(departed)
    context.insert(returning)

    // Departed played only in last season's, now-archived, game.
    let oldGame = Game(opponent: "Hawks", date: Date(timeIntervalSince1970: 0))
    oldGame.season = archived
    oldGame.points = [GamePoint(
        number: 1, ratio: .twoBThreeG, outcome: .us,
        onFieldPlayers: [PointPlayer(player: departed, effectiveGender: .bx)],
        scorer: departed
    )]
    context.insert(oldGame)

    // Returning player is on a game in the open season.
    let newGame = Game(opponent: "Owls", date: Date())
    newGame.season = current
    newGame.points = [GamePoint(
        number: 1, ratio: .twoBThreeG, outcome: .us,
        onFieldPlayers: [PointPlayer(player: returning, effectiveGender: .gx)],
        scorer: returning
    )]
    context.insert(newGame)

    try context.save()

    let games = try context.fetch(FetchDescriptor<Game>())
    #expect(!departed.appearsInCurrentSeason(of: games))
    #expect(returning.appearsInCurrentSeason(of: games))
}

@Test func anUnfiledGameStillProtectsItsPlayers() throws {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)

    let player = Player(name: "Alex", gender: .b)
    context.insert(player)

    // No season set: not yet filed, so treated as current.
    let game = Game(opponent: "Hawks", date: Date())
    game.points = [GamePoint(
        number: 1, ratio: .twoBThreeG, outcome: .us,
        onFieldPlayers: [PointPlayer(player: player, effectiveGender: .bx)],
        scorer: player
    )]
    context.insert(game)
    try context.save()

    let games = try context.fetch(FetchDescriptor<Game>())
    #expect(player.appearsInCurrentSeason(of: games))
}

}
}