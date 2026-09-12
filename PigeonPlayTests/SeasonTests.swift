import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

extension StoreTests {
@Suite struct SeasonLifecycle {

    private func context() throws -> ModelContext {
        let schema = Schema(versionedSchema: PlayerSchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func currentCreatesAnOpenSeasonOnAnEmptyStore() throws {
        let context = try context()

        let season = try Seasons.current(in: context)

        #expect(season.isCurrent)
        #expect(season.name == Seasons.defaultName())
        #expect(try context.fetchCount(FetchDescriptor<Season>()) == 1)
    }

    @Test func currentReturnsTheSameSeasonTwice() throws {
        let context = try context()

        let first = try Seasons.current(in: context)
        let second = try Seasons.current(in: context)

        #expect(first.persistentModelID == second.persistentModelID)
        #expect(try context.fetchCount(FetchDescriptor<Season>()) == 1)
    }

    @Test func currentIgnoresAnArchivedSeason() throws {
        let context = try context()
        let old = Season(name: "2024", startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        old.endedAt = Date(timeIntervalSince1970: 1_710_000_000)
        context.insert(old)

        let season = try Seasons.current(in: context)

        #expect(season.persistentModelID != old.persistentModelID)
        #expect(season.isCurrent)
    }

    @Test func archivingNamesTheClosedSeasonAndOpensAFreshOne() throws {
        let context = try context()
        let closing = try Seasons.current(in: context)

        let change = try Seasons.archiveCurrent(named: "Spring 2026", in: context)
        let next = change.started

        #expect(change.archived.persistentModelID == closing.persistentModelID)
        #expect(closing.name == "Spring 2026")
        #expect(closing.endedAt != nil)
        #expect(!closing.isCurrent)
        #expect(next.isCurrent)
        #expect(next.persistentModelID != closing.persistentModelID)
        #expect(try context.fetchCount(FetchDescriptor<Season>()) == 2)
    }

    @Test func archivingLeavesLastSeasonsGamesWhereTheyWere() throws {
        let context = try context()
        let closing = try Seasons.current(in: context)
        let game = Game(opponent: "Hawks", date: Date())
        context.insert(game)
        game.isActive = false
        game.season = closing

        try Seasons.archiveCurrent(named: "Spring 2026", in: context)

        #expect(game.season?.name == "Spring 2026")
        #expect((closing.games ?? []).count == 1)
    }

    @Test func aFreshSeasonStartsWithNoGames() throws {
        let context = try context()
        let closing = try Seasons.current(in: context)
        let game = Game(opponent: "Hawks", date: Date())
        context.insert(game)
        game.isActive = false
        game.season = closing

        let next = try Seasons.archiveCurrent(named: "Spring 2026", in: context).started

        #expect((next.games ?? []).isEmpty)
    }

    // Ending a season mid-game would strand the game in the archived
    // season while the coach is still recording points into it.
    @Test func archivingRefusesWhileAGameIsInProgress() throws {
        let context = try context()
        let season = try Seasons.current(in: context)
        let game = Game(opponent: "Hawks", date: Date())
        context.insert(game)
        game.season = season

        #expect(throws: SeasonError.gameInProgress) {
            try Seasons.archiveCurrent(named: "Spring 2026", in: context)
        }
        #expect(season.isCurrent)
        #expect(try context.fetchCount(FetchDescriptor<Season>()) == 1)
    }

    @Test func archivingRefusesAnEmptyName() throws {
        let context = try context()
        _ = try Seasons.current(in: context)

        #expect(throws: SeasonError.emptyName) {
            try Seasons.archiveCurrent(named: "   ", in: context)
        }
    }

    @Test func archivingTrimsTheName() throws {
        let context = try context()
        let closing = try Seasons.current(in: context)

        try Seasons.archiveCurrent(named: "  Spring 2026  ", in: context)

        #expect(closing.name == "Spring 2026")
    }

    // Two devices can each open a season before CloudKit reconciles them.
    // Whichever started later wins, so the answer is at least stable.
    @Test func currentPicksTheNewestOpenSeason() throws {
        let context = try context()
        let older = Season(name: "older", startedAt: Date(timeIntervalSince1970: 1_000_000))
        let newer = Season(name: "newer", startedAt: Date(timeIntervalSince1970: 2_000_000))
        context.insert(older)
        context.insert(newer)

        #expect(try Seasons.current(in: context).persistentModelID == newer.persistentModelID)
    }

    // The sequence the coach actually performs: finish last season, name
    // it, then start playing again. The new game must not land in the
    // archived season.
    @Test func aGameStartedAfterArchivingJoinsTheNewSeason() throws {
        let context = try context()
        let closing = try Seasons.current(in: context)
        let lastYear = Game(opponent: "Hawks", date: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(lastYear)
        lastYear.isActive = false
        lastYear.season = closing

        let next = try Seasons.archiveCurrent(named: "Spring 2026", in: context).started

        let fresh = Game(opponent: "Ravens", date: Date())
        context.insert(fresh)
        fresh.season = try Seasons.current(in: context)

        #expect(fresh.season?.persistentModelID == next.persistentModelID)
        #expect((next.games ?? []).map(\.opponent) == ["Ravens"])
        #expect((closing.games ?? []).map(\.opponent) == ["Hawks"])
    }

    @Test func defaultNameIsTheYear() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let year = Calendar.current.component(.year, from: date)
        #expect(Seasons.defaultName(on: date) == String(year))
    }
}
}
