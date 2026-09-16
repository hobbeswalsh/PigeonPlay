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

    private func writeV3Store(at url: URL) throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: PlayerSchemaV3.self),
            configurations: ModelConfiguration(schema: Schema(versionedSchema: PlayerSchemaV3.self), url: url)
        )
        let context = ModelContext(container)

        let fielder = PlayerSchemaV3.Player(name: "Alex", gender: .b)
        context.insert(fielder)

        let older = PlayerSchemaV3.Game(opponent: "Hawks", date: Date(timeIntervalSince1970: 1_700_000_000))
        let newer = PlayerSchemaV3.Game(opponent: "Ravens", date: Date(timeIntervalSince1970: 1_730_000_000))
        context.insert(older)
        context.insert(newer)
        older.isActive = false
        newer.isActive = false
        older.availablePlayers = [fielder]
        try context.save()
    }

    private func writeV4Store(at url: URL) throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: PlayerSchemaV4.self),
            configurations: ModelConfiguration(schema: Schema(versionedSchema: PlayerSchemaV4.self), url: url)
        )
        let context = ModelContext(container)

        let season = PlayerSchemaV4.Season(name: "2025", startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(season)

        let game = PlayerSchemaV4.Game(opponent: "Hawks", date: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(game)
        game.season = season
        game.points = [PlayerSchemaV4.GamePoint(number: 1, ratio: .threeBTwoG, outcome: .them)]
        try context.save()
    }

    private func openCurrentStore(at url: URL) throws -> ModelContext {
        let schema = Schema(versionedSchema: PlayerSchemaV5.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PlayerMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url)
        )
        return ModelContext(container)
    }

    @Test func v2StoreOpensUnderCurrentSchema() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            _ = try openCurrentStore(at: url)
        }
    }

    @Test func v2RosterSurvivesMigrationToCurrent() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            let context = try openCurrentStore(at: url)

            let players = try context.fetch(FetchDescriptor<Player>()).sorted { $0.name < $1.name }
            #expect(players.map(\.name) == ["Alex", "Sam"])
            #expect(players.first?.gender == .b)
            #expect(players.first?.phoneNumber == "555-0100")
            #expect(players.first?.contactIdentifiers == [])
        }
    }

    @Test func v2GameAndPointSurviveMigrationToCurrent() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            let context = try openCurrentStore(at: url)

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
            // A V2 store runs both stages, so it lands filed under a season too.
            #expect(game.season != nil)
        }
    }

    // The inverses V3 adds are new properties, so lightweight migration
    // leaves them empty unless Core Data back-fills them from the forward
    // relationship. Reading a game's points back through the inverse proves
    // which happened.
    @Test func inversesAreLiveAfterMigration() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            let context = try openCurrentStore(at: url)

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

    // The V3 -> V4 stage is the only custom one in the plan. Without it
    // an upgrading coach keeps every game but sees none of them, because
    // History only shows games filed under a season.
    @Test func v3GamesAreFiledUnderASeason() throws {
        try withTemporaryStore { url in
            try writeV3Store(at: url)
            let context = try openCurrentStore(at: url)

            let games = try context.fetch(FetchDescriptor<Game>())
            #expect(games.count == 2)
            #expect(games.allSatisfy { $0.season != nil })

            let seasons = try context.fetch(FetchDescriptor<Season>())
            #expect(seasons.count == 1)
            #expect(Set(games.compactMap { $0.season?.persistentModelID }).count == 1)
        }
    }

    // Named for when the coach was playing, not for when they happened to
    // install the update.
    @Test func theBackfilledSeasonIsNamedForTheEarliestGame() throws {
        try withTemporaryStore { url in
            try writeV3Store(at: url)
            let context = try openCurrentStore(at: url)

            let season = try #require(try context.fetch(FetchDescriptor<Season>()).first)
            let earliest = Date(timeIntervalSince1970: 1_700_000_000)
            #expect(season.name == Seasons.defaultName(on: earliest))
            #expect(season.startedAt == earliest)
        }
    }

    @Test func theBackfilledSeasonIsStillOpen() throws {
        try withTemporaryStore { url in
            try writeV3Store(at: url)
            let context = try openCurrentStore(at: url)

            let season = try #require(try context.fetch(FetchDescriptor<Season>()).first)
            #expect(season.isCurrent)
            #expect(try Seasons.current(in: context).persistentModelID == season.persistentModelID)
        }
    }

    @Test func v3GameDataSurvivesTheSeasonBackfill() throws {
        try withTemporaryStore { url in
            try writeV3Store(at: url)
            let context = try openCurrentStore(at: url)

            let games = try context.fetch(FetchDescriptor<Game>()).sorted { $0.date < $1.date }
            #expect(games.map(\.opponent) == ["Hawks", "Ravens"])
            #expect((games.first?.availablePlayers ?? []).first?.name == "Alex")
        }
    }

    // An empty store has nothing to file, so the stage leaves it alone and
    // the first season is minted on demand at its real start date.
    @Test func anEmptyV3StoreGetsNoBackfilledSeason() throws {
        try withTemporaryStore { url in
            let container = try ModelContainer(
                for: Schema(versionedSchema: PlayerSchemaV3.self),
                configurations: ModelConfiguration(schema: Schema(versionedSchema: PlayerSchemaV3.self), url: url)
            )
            _ = ModelContext(container)

            let context = try openCurrentStore(at: url)
            #expect(try context.fetchCount(FetchDescriptor<Season>()) == 0)
        }
    }

    // V4 -> V5 adds the per-game rules. A game written before they existed
    // must open carrying the defaults every V4 game was already assuming: a
    // five-person alternating line starting 2B/3G. The recorded ratio, set
    // to the B-majority side, must survive untouched.
    @Test func v4GameGainsDefaultRulesAfterMigration() throws {
        try withTemporaryStore { url in
            try writeV4Store(at: url)
            let context = try openCurrentStore(at: url)

            let game = try #require(try context.fetch(FetchDescriptor<Game>()).first)
            #expect(game.lineSize == 5)
            #expect(game.ratioSequence == .alternating)
            #expect(game.startingRatio == .twoBThreeG)
            #expect(game.opponent == "Hawks")
            #expect(game.season?.name == "2025")
            #expect(game.sortedPoints.first?.ratio == .threeBTwoG)
        }
    }

    @Test func v2SavedPlaySurvivesMigrationToCurrent() throws {
        try withTemporaryStore { url in
            try writeV2Store(at: url)
            let context = try openCurrentStore(at: url)

            let plays = try context.fetch(FetchDescriptor<SavedPlay>())
            #expect(plays.count == 1)
            #expect(plays.first?.name == "Vertical stack")
        }
    }
}
}
