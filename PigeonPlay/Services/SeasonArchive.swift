import Foundation
import SwiftData

enum SeasonArchiveError: Error, Equatable {
    case unsupportedVersion
}

/// A whole season as plain data: roster, games with their points, and
/// saved plays. Persistent model IDs are local to one store, so the
/// archive mints its own player identity and rebuilds the object graph
/// from it on the way back in.
struct SeasonArchive: Codable {
    static let currentFormatVersion = 3

    var formatVersion: Int
    var exportedAt: Date
    var players: [PlayerRecord]
    var games: [GameRecord]
    var plays: [PlayRecord]
    var seasons: [SeasonRecord]

    struct SeasonRecord: Codable {
        var id: UUID
        var name: String
        var startedAt: Date
        var endedAt: Date?
    }

    struct PlayerRecord: Codable {
        var id: UUID
        var name: String
        var gender: Gender
        var defaultMatching: GenderMatching?
        var phoneNumber: String?
        var contactIdentifiers: [String]
    }

    struct GameRecord: Codable {
        var opponent: String
        var date: Date
        var isActive: Bool
        var availablePlayerIDs: [UUID]
        var points: [PointRecord]
        var seasonID: UUID?
        var lineSize: Int
        var ratioSequence: RatioSequence
        var startingRatio: GenderRatio

        init(
            opponent: String,
            date: Date,
            isActive: Bool,
            availablePlayerIDs: [UUID],
            points: [PointRecord],
            seasonID: UUID?,
            lineSize: Int,
            ratioSequence: RatioSequence,
            startingRatio: GenderRatio
        ) {
            self.opponent = opponent
            self.date = date
            self.isActive = isActive
            self.availablePlayerIDs = availablePlayerIDs
            self.points = points
            self.seasonID = seasonID
            self.lineSize = lineSize
            self.ratioSequence = ratioSequence
            self.startingRatio = startingRatio
        }

        // The rules arrived in format 3; a format 1 or 2 archive has none,
        // so they fall back to the defaults every earlier game assumed.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            opponent = try container.decode(String.self, forKey: .opponent)
            date = try container.decode(Date.self, forKey: .date)
            isActive = try container.decode(Bool.self, forKey: .isActive)
            availablePlayerIDs = try container.decode([UUID].self, forKey: .availablePlayerIDs)
            points = try container.decode([PointRecord].self, forKey: .points)
            seasonID = try container.decodeIfPresent(UUID.self, forKey: .seasonID)
            lineSize = try container.decodeIfPresent(Int.self, forKey: .lineSize) ?? 5
            ratioSequence = try container.decodeIfPresent(RatioSequence.self, forKey: .ratioSequence) ?? .alternating
            startingRatio = try container.decodeIfPresent(GenderRatio.self, forKey: .startingRatio) ?? .twoBThreeG
        }
    }

    struct PointRecord: Codable {
        var number: Int
        var ratio: GenderRatio
        var outcome: PointOutcome
        var onField: [AppearanceRecord]
        var scorerID: UUID?
        var assistID: UUID?
    }

    struct AppearanceRecord: Codable {
        var playerID: UUID?
        var effectiveGender: GenderMatching
    }

    struct PlayRecord: Codable {
        var name: String
        var elements: [DrawingElement]
        var dateCreated: Date
    }
}

extension SeasonArchive {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        players = try container.decode([PlayerRecord].self, forKey: .players)
        games = try container.decode([GameRecord].self, forKey: .games)
        plays = try container.decode([PlayRecord].self, forKey: .plays)
        seasons = try container.decodeIfPresent([SeasonRecord].self, forKey: .seasons) ?? []
    }
}

// MARK: - Export

extension SeasonArchive {
    init(exporting context: ModelContext) throws {
        let players = try context.fetch(FetchDescriptor<Player>())
        var identity: [PersistentIdentifier: UUID] = [:]
        for player in players {
            identity[player.persistentModelID] = UUID()
        }

        func id(of player: Player?) -> UUID? {
            player.flatMap { identity[$0.persistentModelID] }
        }

        let seasons = try context.fetch(FetchDescriptor<Season>())
        var seasonIdentity: [PersistentIdentifier: UUID] = [:]
        for season in seasons {
            seasonIdentity[season.persistentModelID] = UUID()
        }

        self.formatVersion = Self.currentFormatVersion
        self.exportedAt = Date()
        self.seasons = seasons.map { season in
            SeasonRecord(
                id: seasonIdentity[season.persistentModelID] ?? UUID(),
                name: season.name,
                startedAt: season.startedAt,
                endedAt: season.endedAt
            )
        }
        self.players = players.map { player in
            PlayerRecord(
                id: identity[player.persistentModelID] ?? UUID(),
                name: player.name,
                gender: player.gender,
                defaultMatching: player.defaultMatching,
                phoneNumber: player.phoneNumber,
                contactIdentifiers: player.contactIdentifiers
            )
        }
        self.games = try context.fetch(FetchDescriptor<Game>()).map { game in
            GameRecord(
                opponent: game.opponent,
                date: game.date,
                isActive: game.isActive,
                availablePlayerIDs: (game.availablePlayers ?? []).compactMap { id(of: $0) },
                points: game.sortedPoints.map { point in
                    PointRecord(
                        number: point.number,
                        ratio: point.ratio,
                        outcome: point.outcome,
                        onField: (point.onFieldPlayers ?? []).map { appearance in
                            AppearanceRecord(
                                playerID: id(of: appearance.player),
                                effectiveGender: appearance.effectiveGender
                            )
                        },
                        scorerID: id(of: point.scorer),
                        assistID: id(of: point.assist)
                    )
                },
                seasonID: game.season.flatMap { seasonIdentity[$0.persistentModelID] },
                lineSize: game.lineSize,
                ratioSequence: game.ratioSequence,
                startingRatio: game.startingRatio
            )
        }
        self.plays = try context.fetch(FetchDescriptor<SavedPlay>()).map { play in
            PlayRecord(name: play.name, elements: play.elements, dateCreated: play.dateCreated)
        }
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

// MARK: - Import

extension SeasonArchive {
    init(jsonData: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(SeasonArchive.self, from: jsonData)
        guard archive.formatVersion <= Self.currentFormatVersion else {
            throw SeasonArchiveError.unsupportedVersion
        }
        self = archive
    }

    /// Restore, not merge. Two stores have no shared identity to match
    /// on, so merging would either duplicate a roster or overwrite it on
    /// a name collision; replacing is the behaviour a coach restoring a
    /// backup actually expects.
    func replaceContents(of context: ModelContext) throws {
        try context.delete(model: PointPlayer.self)
        try context.delete(model: GamePoint.self)
        try context.delete(model: Game.self)
        try context.delete(model: SavedPlay.self)
        try context.delete(model: Player.self)
        try context.delete(model: Season.self)

        var restoredSeasons: [UUID: Season] = [:]
        for record in seasons {
            let season = Season(name: record.name, startedAt: record.startedAt)
            season.endedAt = record.endedAt
            context.insert(season)
            restoredSeasons[record.id] = season
        }

        var restored: [UUID: Player] = [:]
        for record in players {
            let player = Player(
                name: record.name,
                gender: record.gender,
                defaultMatching: record.defaultMatching,
                phoneNumber: record.phoneNumber,
                contactIdentifiers: record.contactIdentifiers
            )
            context.insert(player)
            restored[record.id] = player
        }

        for record in games {
            let game = Game(
                opponent: record.opponent,
                date: record.date,
                lineSize: record.lineSize,
                ratioSequence: record.ratioSequence,
                startingRatio: record.startingRatio
            )
            context.insert(game)
            game.isActive = record.isActive
            game.season = record.seasonID.flatMap { restoredSeasons[$0] }
            game.availablePlayers = record.availablePlayerIDs.compactMap { restored[$0] }
            game.points = record.points.map { point in
                GamePoint(
                    number: point.number,
                    ratio: point.ratio,
                    outcome: point.outcome,
                    onFieldPlayers: point.onField.compactMap { appearance in
                        appearance.playerID
                            .flatMap { restored[$0] }
                            .map { PointPlayer(player: $0, effectiveGender: appearance.effectiveGender) }
                    },
                    scorer: point.scorerID.flatMap { restored[$0] },
                    assist: point.assistID.flatMap { restored[$0] }
                )
            }
        }

        for record in plays {
            context.insert(SavedPlay(
                name: record.name,
                elements: record.elements,
                dateCreated: record.dateCreated
            ))
        }

        // A version 1 archive predates seasons. Restoring it as written
        // would leave every game filed under nothing and so invisible in
        // History, so it gets the same treatment the V3 -> V4 migration
        // gives an upgrading store.
        let orphans = try context.fetch(FetchDescriptor<Game>()).filter { $0.season == nil }
        Seasons.fileUnderABackfilledSeason(orphans, in: context)

        try context.save()
    }
}
