import Foundation
import SwiftData

enum SeasonError: Error, Equatable, LocalizedError {
    case gameInProgress
    case emptyName

    var errorDescription: String? {
        switch self {
        case .gameInProgress:
            "Finish or end the game in progress before starting a new season."
        case .emptyName:
            "Give the season a name."
        }
    }
}

/// What archiving did: the season that closed and the one now open.
/// Both, because the coach's confirmation names each and the stored name
/// is the trimmed one, not what they typed.
struct SeasonChange {
    let archived: Season
    let started: Season
}

/// Season lifecycle. Static methods on an enum, as LineSuggester is.
enum Seasons {
    /// The open season, created on demand. A store that has never had one
    /// - a fresh install, or one whose migration found no games to file -
    /// gets it here rather than at launch, so nothing has to remember to
    /// seed it.
    static func current(in context: ModelContext) throws -> Season {
        if let open = try openSeason(in: context) { return open }

        let season = Season(name: defaultName(), startedAt: Date())
        context.insert(season)
        return season
    }

    /// Closes the open season under `name` and opens an empty one. Games
    /// keep pointing at the season they were played in, which is the
    /// whole point: History can still show them.
    @discardableResult
    static func archiveCurrent(named name: String, in context: ModelContext) throws -> SeasonChange {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SeasonError.emptyName }

        // A game still being recorded belongs to the season the coach is
        // closing, and would carry on collecting points inside it.
        let inProgress = FetchDescriptor<Game>(predicate: #Predicate { $0.isActive })
        guard try context.fetchCount(inProgress) == 0 else { throw SeasonError.gameInProgress }

        let closing = try current(in: context)
        closing.name = trimmed
        closing.endedAt = Date()

        let next = Season(name: defaultName(), startedAt: Date())
        context.insert(next)
        try context.saveNow()
        return SeasonChange(archived: closing, started: next)
    }

    /// Files games that belong to no season under one named for the
    /// earliest of them. Shared by the V3 -> V4 migration and by restoring
    /// an archive written before seasons existed, which are the same
    /// problem: games that predate the concept.
    @discardableResult
    static func fileUnderABackfilledSeason(_ games: [Game], in context: ModelContext) -> Season? {
        guard let earliest = games.map(\.date).min() else { return nil }

        let season = Season(name: defaultName(on: earliest), startedAt: earliest)
        context.insert(season)
        for game in games {
            game.season = season
        }
        return season
    }

    static func defaultName(on date: Date = Date()) -> String {
        String(Calendar.current.component(.year, from: date))
    }

    /// Newest first, so that two devices each opening a season before
    /// CloudKit reconciles them at least resolve to the same one.
    private static func openSeason(in context: ModelContext) throws -> Season? {
        var descriptor = FetchDescriptor<Season>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
