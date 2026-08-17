import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

// A migration is only real if a store written by the previous shipped
// schema opens under the current one with its rows intact. These tests
// write through the frozen V2 models, close the store, and reopen it
// through the app's own container configuration.
//
// Every future schema version needs the equivalent. Freezing the outgoing
// version as a nested snapshot is what makes it possible to write the
// fixture in code instead of committing a binary .store.

// These are the only tests that build a container on the frozen V2
// schema, which is what makes StoreTests' serialization necessary rather
// than merely tidy. See the note there.
extension StoreTests {
@Suite struct Migration {

    private func withTemporaryStore(_ body: (URL) throws -> Void) rethrows {
        let url = URL.temporaryDirectory.appending(path: "migration-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
            }
        }
        try body(url)
    }

    private func writeV2Store(at url: URL) throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: PlayerSchemaV2.self),
            configurations: ModelConfiguration(schema: Schema(versionedSchema: PlayerSchemaV2.self), url: url)
        )
        let context = ModelContext(container)

        let fielder = PlayerSchemaV2.Player(name: "Alex", gender: .b, phoneNumber: "555-0100")
        let scorer = PlayerSchemaV2.Player(name: "Sam", gender: .g)
        context.insert(fielder)
        context.insert(scorer)

        let game = PlayerSchemaV2.Game(opponent: "Hawks", date: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(game)
        game.availablePlayers = [fielder, scorer]

        let point = PlayerSchemaV2.GamePoint(
            number: 1,
            ratio: .twoBThreeG,
            outcome: .us,
            onFieldPlayers: [PlayerSchemaV2.PointPlayer(player: fielder, effectiveGender: .bx)],
            scorer: scorer
        )
        game.points = [point]

        context.insert(PlayerSchemaV2.SavedPlay(name: "Vertical stack"))
        try context.save()
    }

    private func openV3Store(at url: URL) throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(versionedSchema: PlayerSchemaV3.self),
            migrationPlan: PlayerMigrationPlan.self,
            configurations: ModelConfiguration(schema: Schema(versionedSchema: PlayerSchemaV3.self), url: url)
        )
        return ModelContext(container)
    }

    @Test func v2StoreOpensUnderV3() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            _ = try openV3Store(at: url)
        }
    }

    @Test func v2RosterSurvivesMigrationToV3() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            let context = try openV3Store(at: url)

            let players = try context.fetch(FetchDescriptor<Player>()).sorted { $0.name < $1.name }
            #expect(players.map(\.name) == ["Alex", "Sam"])
            #expect(players.first?.gender == .b)
            #expect(players.first?.phoneNumber == "555-0100")
            #expect(players.first?.contactIdentifiers == [])
        }
    }

    @Test func v2GameAndPointSurviveMigrationToV3() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            let context = try openV3Store(at: url)

            let games = try context.fetch(FetchDescriptor<Game>())
            #expect(games.count == 1)
            let game = try #require(games.first)
            #expect(game.opponent == "Hawks")
            #expect(game.date == Date(timeIntervalSince1970: 1_700_000_000))
            #expect(game.isActive)
            #expect((game.availablePlayers ?? []).count == 2)

            #expect((game.points ?? []).count == 1)
            let point = try #require(game.sortedPoints.first)
            #expect(point.number == 1)
            #expect(point.outcome == .us)
            #expect(point.ratio == .twoBThreeG)
            #expect(point.scorer?.name == "Sam")
            #expect((point.onFieldPlayers ?? []).count == 1)
            #expect((point.onFieldPlayers ?? []).first?.player?.name == "Alex")
            #expect(game.ourScore == 1)
        }
    }

    // The inverses V3 adds are new properties, so lightweight migration
    // leaves them empty unless Core Data back-fills them from the forward
    // relationship. Reading a game's points back through the inverse proves
    // which happened.
    @Test func inversesAreLiveAfterMigration() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            let context = try openV3Store(at: url)

            let point = try #require(try context.fetch(FetchDescriptor<GamePoint>()).first)
            #expect(point.game?.opponent == "Hawks")

            let appearance = try #require(try context.fetch(FetchDescriptor<PointPlayer>()).first)
            #expect(appearance.point?.number == 1)
            #expect(appearance.player?.name == "Alex")

            let alex = try #require(
                try context.fetch(FetchDescriptor<Player>()).first { $0.name == "Alex" }
            )
            #expect((alex.games ?? []).count == 1)
            #expect((alex.appearances ?? []).count == 1)

            let sam = try #require(
                try context.fetch(FetchDescriptor<Player>()).first { $0.name == "Sam" }
            )
            #expect((sam.pointsScored ?? []).count == 1)
        }
    }

    @Test func v2SavedPlaySurvivesMigrationToV3() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            let context = try openV3Store(at: url)

            let plays = try context.fetch(FetchDescriptor<SavedPlay>())
            #expect(plays.count == 1)
            #expect(plays.first?.name == "Vertical stack")
        }
    }
}
}
