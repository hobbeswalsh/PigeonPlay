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
    static let currentFormatVersion = 1

    var formatVersion: Int
    var exportedAt: Date
    var players: [PlayerRecord]
    var games: [GameRecord]
    var plays: [PlayRecord]

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

        self.formatVersion = Self.currentFormatVersion
        self.exportedAt = Date()
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
                }
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
            let game = Game(opponent: record.opponent, date: record.date)
            context.insert(game)
            game.isActive = record.isActive
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

        try context.save()
    }
}
