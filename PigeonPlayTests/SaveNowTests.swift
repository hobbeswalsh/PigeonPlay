import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

extension StoreTests {
@Suite struct SaveNow {

// The app relied entirely on autosave, whose timing is SwiftData's to
// choose. On a sideline, iOS can kill a backgrounded app between points,
// and anything autosave has not yet written is gone. These tests pin the
// behaviour that makes a write durable at the moment the coach performs
// it: after saveNow, a container opened fresh on the same file sees it.

private func makeStoreURL() -> URL {
    URL.temporaryDirectory.appending(path: "savenow-\(UUID().uuidString).store")
}

private func removeStore(at url: URL) {
    for suffix in ["", "-shm", "-wal"] {
        try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
    }
}

private func makeContainer(at url: URL) throws -> ModelContainer {
    try ModelContainer(
        for: Schema(versionedSchema: PlayerSchemaV3.self),
        migrationPlan: PlayerMigrationPlan.self,
        configurations: ModelConfiguration(
            schema: Schema(versionedSchema: PlayerSchemaV3.self),
            url: url
        )
    )
}

@Test func saveNowMakesAnInsertVisibleToAFreshContainer() throws {
    let url = makeStoreURL()
    defer { removeStore(at: url) }

    do {
        let context = ModelContext(try makeContainer(at: url))
        context.autosaveEnabled = false
        context.insert(Player(name: "Alex", gender: .b, phoneNumber: "555-0100"))
        try context.saveNow()
    }

    let reopened = ModelContext(try makeContainer(at: url))
    let players = try reopened.fetch(FetchDescriptor<Player>())
    #expect(players.count == 1)
    #expect(players.first?.name == "Alex")
}

@Test func withoutSaveNowAnInsertIsLostWhenAutosaveIsOff() throws {
    let url = makeStoreURL()
    defer { removeStore(at: url) }

    do {
        let context = ModelContext(try makeContainer(at: url))
        context.autosaveEnabled = false
        context.insert(Player(name: "Alex", gender: .b))
    }

    let reopened = ModelContext(try makeContainer(at: url))
    #expect(try reopened.fetch(FetchDescriptor<Player>()).isEmpty)
}

@Test func saveNowMakesADeleteVisibleToAFreshContainer() throws {
    let url = makeStoreURL()
    defer { removeStore(at: url) }

    do {
        let context = ModelContext(try makeContainer(at: url))
        context.autosaveEnabled = false
        context.insert(Player(name: "Alex", gender: .b))
        try context.saveNow()
    }

    do {
        let context = ModelContext(try makeContainer(at: url))
        context.autosaveEnabled = false
        let player = try #require(try context.fetch(FetchDescriptor<Player>()).first)
        context.delete(player)
        try context.saveNow()
    }

    let reopened = ModelContext(try makeContainer(at: url))
    #expect(try reopened.fetch(FetchDescriptor<Player>()).isEmpty)
}

@Test func saveNowPersistsAWholeGameIncludingItsPoints() throws {
    let url = makeStoreURL()
    defer { removeStore(at: url) }

    do {
        let context = ModelContext(try makeContainer(at: url))
        context.autosaveEnabled = false
        let player = Player(name: "Alex", gender: .b)
        let game = Game(opponent: "Hawks", date: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(player)
        context.insert(game)
        game.availablePlayers = [player]
        game.points = [GamePoint(
            number: 1,
            ratio: .twoBThreeG,
            outcome: .us,
            onFieldPlayers: [PointPlayer(player: player, effectiveGender: .bx)],
            scorer: player
        )]
        try context.saveNow()
    }

    let reopened = ModelContext(try makeContainer(at: url))
    let game = try #require(try reopened.fetch(FetchDescriptor<Game>()).first)
    #expect(game.opponent == "Hawks")
    #expect((game.points ?? []).count == 1)
    #expect(game.sortedPoints.first?.scorer?.name == "Alex")
    #expect(game.ourScore == 1)
}

@Test func saveNowIsAgreeableWhenThereIsNothingToSave() throws {
    let url = makeStoreURL()
    defer { removeStore(at: url) }

    let context = ModelContext(try makeContainer(at: url))
    context.autosaveEnabled = false
    try context.saveNow()
    try context.saveNow()

    #expect(try context.fetch(FetchDescriptor<Player>()).isEmpty)
}

}
}