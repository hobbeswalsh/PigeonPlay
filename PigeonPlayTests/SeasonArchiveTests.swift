import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

// The archive is the answer to "my phone died". It has to survive a
// round trip with the relationships intact, which is the hard part:
// persistent IDs mean nothing on another device, so the archive carries
// its own identity for players and rebuilds the graph from it.
//
// Nested under StoreTests, which explains why anything that builds a
// container has to be serialized against everything else that does.
extension StoreTests {
@Suite struct Archive {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(versionedSchema: PlayerSchemaV4.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func populate(_ context: ModelContext) {
        let alex = Player(name: "Alex", gender: .b, phoneNumber: "555-0100", contactIdentifiers: ["c1"])
        let sam = Player(name: "Sam", gender: .g)
        let jo = Player(name: "Jo", gender: .x, defaultMatching: .gx)
        for player in [alex, sam, jo] { context.insert(player) }

        let game = Game(opponent: "Hawks", date: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(game)
        game.availablePlayers = [alex, sam, jo]
        game.points = [
            GamePoint(
                number: 1,
                ratio: .twoBThreeG,
                outcome: .us,
                onFieldPlayers: [
                    PointPlayer(player: alex, effectiveGender: .bx),
                    PointPlayer(player: sam, effectiveGender: .gx),
                ],
                scorer: sam,
                assist: alex
            ),
            GamePoint(number: 2, ratio: .threeBTwoG, outcome: .them),
        ]

        let finished = Game(opponent: "Ravens", date: Date(timeIntervalSince1970: 1_600_000_000))
        context.insert(finished)
        finished.isActive = false

        context.insert(SavedPlay(
            name: "Vertical stack",
            elements: [.circle(center: CGPoint(x: 3, y: 4), color: "red")],
            dateCreated: Date(timeIntervalSince1970: 1_500_000_000)
        ))
    }

    @Test func archiveCapturesEveryRoster() throws {
        let context = try makeContext()
        populate(context)

        let archive = try SeasonArchive(exporting: context)

        #expect(archive.players.map(\.name).sorted() == ["Alex", "Jo", "Sam"])
        let jo = try #require(archive.players.first { $0.name == "Jo" })
        #expect(jo.gender == .x)
        #expect(jo.defaultMatching == .gx)
        let alex = try #require(archive.players.first { $0.name == "Alex" })
        #expect(alex.phoneNumber == "555-0100")
        #expect(alex.contactIdentifiers == ["c1"])
    }

    @Test func archiveRoundTripsThroughJSON() throws {
        let context = try makeContext()
        populate(context)

        let data = try SeasonArchive(exporting: context).jsonData()
        let decoded = try SeasonArchive(jsonData: data)

        #expect(decoded.players.count == 3)
        #expect(decoded.games.count == 2)
        #expect(decoded.plays.count == 1)
    }

    @Test func importingRebuildsTheRosterAndGames() throws {
        let source = try makeContext()
        populate(source)
        let data = try SeasonArchive(exporting: source).jsonData()

        let destination = try makeContext()
        try SeasonArchive(jsonData: data).replaceContents(of: destination)

        let players = try destination.fetch(FetchDescriptor<Player>())
        #expect(players.count == 3)

        let games = try destination.fetch(FetchDescriptor<Game>()).sorted { $0.date < $1.date }
        #expect(games.map(\.opponent) == ["Ravens", "Hawks"])

        let hawks = try #require(games.last)
        #expect(hawks.isActive)
        #expect(hawks.date == Date(timeIntervalSince1970: 1_700_000_000))
        #expect((hawks.availablePlayers ?? []).count == 3)
        #expect((hawks.points ?? []).count == 2)
        #expect(hawks.ourScore == 1)
        #expect(hawks.theirScore == 1)
    }

    @Test func importingRelinksPlayersInsidePoints() throws {
        let source = try makeContext()
        populate(source)
        let data = try SeasonArchive(exporting: source).jsonData()

        let destination = try makeContext()
        try SeasonArchive(jsonData: data).replaceContents(of: destination)

        let hawks = try #require(
            try destination.fetch(FetchDescriptor<Game>()).first { $0.opponent == "Hawks" }
        )
        let first = try #require(hawks.sortedPoints.first)
        #expect(first.scorer?.name == "Sam")
        #expect(first.assist?.name == "Alex")
        #expect((first.onFieldPlayers ?? []).count == 2)
        #expect(Set((first.onFieldPlayers ?? []).compactMap { $0.player?.name }) == ["Alex", "Sam"])

        // The relinked player must be the stored Player, not a duplicate.
        let alexInRoster = try #require(
            try destination.fetch(FetchDescriptor<Player>()).first { $0.name == "Alex" }
        )
        #expect(first.assist === alexInRoster)
        #expect(try destination.fetch(FetchDescriptor<Player>()).count == 3)
    }

    @Test func importingPreservesEffectiveGenderPerAppearance() throws {
        let source = try makeContext()
        populate(source)
        let data = try SeasonArchive(exporting: source).jsonData()

        let destination = try makeContext()
        try SeasonArchive(jsonData: data).replaceContents(of: destination)

        let hawks = try #require(
            try destination.fetch(FetchDescriptor<Game>()).first { $0.opponent == "Hawks" }
        )
        let appearances = try #require(hawks.sortedPoints.first?.onFieldPlayers)
        let byName = Dictionary(uniqueKeysWithValues: appearances.compactMap { appearance in
            appearance.player.map { ($0.name, appearance.effectiveGender) }
        })
        #expect(byName["Alex"] == .bx)
        #expect(byName["Sam"] == .gx)
    }

    @Test func importingRestoresSavedPlays() throws {
        let source = try makeContext()
        populate(source)
        let data = try SeasonArchive(exporting: source).jsonData()

        let destination = try makeContext()
        try SeasonArchive(jsonData: data).replaceContents(of: destination)

        let play = try #require(try destination.fetch(FetchDescriptor<SavedPlay>()).first)
        #expect(play.name == "Vertical stack")
        #expect(play.dateCreated == Date(timeIntervalSince1970: 1_500_000_000))
        #expect(play.elements.count == 1)
    }

    @Test func importingReplacesRatherThanMergesWithExistingData() throws {
        let source = try makeContext()
        populate(source)
        let data = try SeasonArchive(exporting: source).jsonData()

        let destination = try makeContext()
        destination.insert(Player(name: "Stale", gender: .b))
        destination.insert(Game(opponent: "Old opponent", date: Date(timeIntervalSince1970: 1)))
        destination.insert(SavedPlay(name: "Old play"))
        try destination.save()

        try SeasonArchive(jsonData: data).replaceContents(of: destination)

        let names = try destination.fetch(FetchDescriptor<Player>()).map(\.name).sorted()
        #expect(names == ["Alex", "Jo", "Sam"])
        #expect(try destination.fetch(FetchDescriptor<Game>()).allSatisfy { $0.opponent != "Old opponent" })
        #expect(try destination.fetch(FetchDescriptor<SavedPlay>()).map(\.name) == ["Vertical stack"])
        // Nothing orphaned by the wipe.
        #expect(try destination.fetch(FetchDescriptor<PointPlayer>()).count == 2)
    }

    @Test func importingAnEmptyArchiveEmptiesTheStore() throws {
        let destination = try makeContext()
        populate(destination)
        try destination.save()

        let empty = try SeasonArchive(jsonData: try SeasonArchive(exporting: try makeContext()).jsonData())
        try empty.replaceContents(of: destination)

        #expect(try destination.fetch(FetchDescriptor<Player>()).isEmpty)
        #expect(try destination.fetch(FetchDescriptor<Game>()).isEmpty)
        #expect(try destination.fetch(FetchDescriptor<SavedPlay>()).isEmpty)
        #expect(try destination.fetch(FetchDescriptor<GamePoint>()).isEmpty)
        #expect(try destination.fetch(FetchDescriptor<PointPlayer>()).isEmpty)
    }

    // MARK: Seasons

    @Test func archiveCapturesSeasonsAndWhichOneEachGameBelongsTo() throws {
        let context = try makeContext()
        populate(context)
        let season = try Seasons.current(in: context)
        for game in try context.fetch(FetchDescriptor<Game>()) {
            game.season = season
        }

        let archive = try SeasonArchive(exporting: context)

        #expect(archive.seasons.count == 1)
        #expect(archive.seasons.first?.name == season.name)
        #expect(archive.games.allSatisfy { $0.seasonID != nil })
        #expect(archive.games.first?.seasonID == archive.seasons.first?.id)
    }

    @Test func importingRebuildsSeasonMembership() throws {
        let source = try makeContext()
        populate(source)
        let season = try Seasons.current(in: source)
        for game in try source.fetch(FetchDescriptor<Game>()) {
            game.season = season
        }
        let archive = try SeasonArchive(exporting: source)

        let target = try makeContext()
        try archive.replaceContents(of: target)

        let seasons = try target.fetch(FetchDescriptor<Season>())
        #expect(seasons.count == 1)
        let game = try #require(try target.fetch(FetchDescriptor<Game>()).first)
        #expect(game.season?.persistentModelID == seasons.first?.persistentModelID)
    }

    @Test func importingPreservesWhetherASeasonWasArchived() throws {
        let source = try makeContext()
        let closed = Season(name: "2024", startedAt: Date(timeIntervalSince1970: 1_600_000_000))
        closed.endedAt = Date(timeIntervalSince1970: 1_650_000_000)
        source.insert(closed)
        _ = try Seasons.current(in: source)
        let archive = try SeasonArchive(exporting: source)

        let target = try makeContext()
        try archive.replaceContents(of: target)

        let restored = try target.fetch(FetchDescriptor<Season>()).sorted { $0.startedAt < $1.startedAt }
        #expect(restored.count == 2)
        #expect(restored.first?.name == "2024")
        #expect(restored.first?.endedAt == Date(timeIntervalSince1970: 1_650_000_000))
        #expect(restored.last?.isCurrent == true)
    }

    // A backup taken before seasons existed carries none. Restoring it as
    // written would leave every game invisible in History, so the restore
    // files them the same way the V3 -> V4 migration does.
    @Test func importingAVersion1ArchiveFilesItsGamesUnderASeason() throws {
        let source = try makeContext()
        populate(source)
        var archive = try SeasonArchive(exporting: source)
        archive.formatVersion = 1
        archive.seasons = []
        archive.games = archive.games.map { game in
            var copy = game
            copy.seasonID = nil
            return copy
        }

        let target = try makeContext()
        try archive.replaceContents(of: target)

        let seasons = try target.fetch(FetchDescriptor<Season>())
        #expect(seasons.count == 1)
        #expect(seasons.first?.isCurrent == true)
        #expect(try target.fetch(FetchDescriptor<Game>()).allSatisfy { $0.season != nil })
    }

    @Test func aVersion1ArchiveDecodesWithoutASeasonsKey() throws {
        let json = Data("""
        {
          "exportedAt": "2026-01-02T03:04:05Z",
          "formatVersion": 1,
          "games": [],
          "players": [],
          "plays": []
        }
        """.utf8)

        let archive = try SeasonArchive(jsonData: json)

        #expect(archive.formatVersion == 1)
        #expect(archive.seasons.isEmpty)
    }

    @Test func decodingRejectsDataThatIsNotAnArchive() throws {
        #expect(throws: (any Error).self) {
            try SeasonArchive(jsonData: Data("not an archive".utf8))
        }
    }

    @Test func decodingRejectsAnArchiveFromANewerVersion() throws {
        var archive = try SeasonArchive(exporting: try makeContext())
        archive.formatVersion = SeasonArchive.currentFormatVersion + 1
        let data = try archive.jsonData()

        #expect(throws: SeasonArchiveError.unsupportedVersion) {
            try SeasonArchive(jsonData: data)
        }
    }
}
}
