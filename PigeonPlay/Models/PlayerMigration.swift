import Foundation
import SwiftData

// V2 is the schema the app shipped with, frozen. Every model and every
// enum it stores is a nested copy: the first attempt at versioning reused
// the live Game/GamePoint/PointPlayer classes, whose relationships pulled
// in the live Player and made the old version alias to the new one
// ("Duplicate version checksums" at container init). The enums are copied
// for the same reason - the roadmap renames Gender and GenderMatching,
// and that rename must not silently redefine what V2 meant.
//
// The original V1 schema (parentName / parentPhone / parentEmail on
// Player) has no stage here because it could never run, and any real V1
// store was destroyed by the old delete-and-retry fallback in
// PigeonPlayApp before this plan was ever consulted.
enum PlayerSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self]
    }

    enum Gender: String, Codable {
        case b, g, x
    }

    enum GenderMatching: String, Codable {
        case bx, gx
    }

    enum GenderRatio: String, Codable {
        case twoBThreeG
        case threeBTwoG
    }

    enum PointOutcome: String, Codable {
        case us, them, dead
    }

    enum DrawingElement: Codable {
        case stroke(points: [CGPoint], color: String, lineWidth: CGFloat)
        case arrow(from: CGPoint, to: CGPoint, color: String)
        case circle(center: CGPoint, color: String)
    }

    @Model
    final class Player {
        var name: String
        var gender: Gender
        var defaultMatching: GenderMatching?
        var phoneNumber: String?
        var contactIdentifiers: [String] = []

        init(
            name: String,
            gender: Gender,
            defaultMatching: GenderMatching? = nil,
            phoneNumber: String? = nil,
            contactIdentifiers: [String] = []
        ) {
            self.name = name
            self.gender = gender
            self.defaultMatching = defaultMatching
            self.phoneNumber = phoneNumber
            self.contactIdentifiers = contactIdentifiers
        }
    }

    @Model
    final class PointPlayer {
        var player: Player
        var effectiveGender: GenderMatching

        init(player: Player, effectiveGender: GenderMatching) {
            self.player = player
            self.effectiveGender = effectiveGender
        }
    }

    @Model
    final class GamePoint {
        var number: Int
        var ratio: GenderRatio
        var outcome: PointOutcome
        @Relationship(deleteRule: .cascade) var onFieldPlayers: [PointPlayer]
        var scorer: Player?
        var assist: Player?

        init(
            number: Int,
            ratio: GenderRatio,
            outcome: PointOutcome,
            onFieldPlayers: [PointPlayer] = [],
            scorer: Player? = nil,
            assist: Player? = nil
        ) {
            self.number = number
            self.ratio = ratio
            self.outcome = outcome
            self.onFieldPlayers = onFieldPlayers
            self.scorer = scorer
            self.assist = assist
        }
    }

    @Model
    final class Game {
        var opponent: String
        var date: Date
        @Relationship(deleteRule: .cascade) var points: [GamePoint]
        var availablePlayers: [Player]
        var isActive: Bool

        init(opponent: String, date: Date) {
            self.opponent = opponent
            self.date = date
            self.points = []
            self.availablePlayers = []
            self.isActive = true
        }
    }

    @Model
    final class SavedPlay {
        var name: String
        var elements: [DrawingElement]
        var dateCreated: Date

        init(name: String, elements: [DrawingElement] = [], dateCreated: Date = Date()) {
            self.name = name
            self.elements = elements
            self.dateCreated = dateCreated
        }
    }
}

// V3 makes the schema mirrorable to CloudKit: every attribute carries a
// default, every to-one relationship is optional, and every relationship
// declares an inverse. Frozen as a nested snapshot for the same reason V2
// is - V4 adds Season, and a V3 that still pointed at the live models
// would checksum identically to V4 and break the plan at container init.
enum PlayerSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self]
    }

    enum Gender: String, Codable {
        case b, g, x
    }

    enum GenderMatching: String, Codable {
        case bx, gx
    }

    enum GenderRatio: String, Codable {
        case twoBThreeG
        case threeBTwoG
    }

    enum PointOutcome: String, Codable {
        case us, them, dead
    }

    enum DrawingElement: Codable {
        case stroke(points: [CGPoint], color: String, lineWidth: CGFloat)
        case arrow(from: CGPoint, to: CGPoint, color: String)
        case circle(center: CGPoint, color: String)
    }

    @Model
    final class Player {
        var name: String = ""
        var gender: Gender = Gender.x
        var defaultMatching: GenderMatching?
        var phoneNumber: String?
        var contactIdentifiers: [String] = []

        var games: [Game]?
        var appearances: [PointPlayer]?
        var pointsScored: [GamePoint]?
        var pointsAssisted: [GamePoint]?

        init(
            name: String,
            gender: Gender,
            defaultMatching: GenderMatching? = nil,
            phoneNumber: String? = nil,
            contactIdentifiers: [String] = []
        ) {
            self.name = name
            self.gender = gender
            self.defaultMatching = defaultMatching
            self.phoneNumber = phoneNumber
            self.contactIdentifiers = contactIdentifiers
        }
    }

    @Model
    final class PointPlayer {
        @Relationship(inverse: \Player.appearances) var player: Player?
        var effectiveGender: GenderMatching = GenderMatching.bx
        var point: GamePoint?

        init(player: Player, effectiveGender: GenderMatching) {
            self.player = player
            self.effectiveGender = effectiveGender
        }
    }

    @Model
    final class GamePoint {
        var number: Int = 0
        var ratio: GenderRatio = GenderRatio.twoBThreeG
        var outcome: PointOutcome = PointOutcome.dead
        @Relationship(deleteRule: .cascade, inverse: \PointPlayer.point)
        var onFieldPlayers: [PointPlayer]?
        @Relationship(inverse: \Player.pointsScored) var scorer: Player?
        @Relationship(inverse: \Player.pointsAssisted) var assist: Player?
        var game: Game?

        init(
            number: Int,
            ratio: GenderRatio,
            outcome: PointOutcome,
            onFieldPlayers: [PointPlayer] = [],
            scorer: Player? = nil,
            assist: Player? = nil
        ) {
            self.number = number
            self.ratio = ratio
            self.outcome = outcome
            self.onFieldPlayers = onFieldPlayers
            self.scorer = scorer
            self.assist = assist
        }
    }

    @Model
    final class Game {
        var opponent: String = ""
        var date: Date = Date.distantPast
        @Relationship(deleteRule: .cascade, inverse: \GamePoint.game)
        var points: [GamePoint]?
        @Relationship(inverse: \Player.games) var availablePlayers: [Player]?
        var isActive: Bool = true

        init(opponent: String, date: Date) {
            self.opponent = opponent
            self.date = date
            self.points = []
            self.availablePlayers = []
            self.isActive = true
        }
    }

    @Model
    final class SavedPlay {
        var name: String = ""
        var elements: [DrawingElement] = []
        var dateCreated: Date = Date.distantPast

        init(name: String, elements: [DrawingElement] = [], dateCreated: Date = Date()) {
            self.name = name
            self.elements = elements
            self.dateCreated = dateCreated
        }
    }
}

// V4 adds Season and files every game under one, so that a coach can
// close a season by name and start again without losing what came
// before. Frozen as a nested snapshot the way V2 and V3 are, because V5
// adds per-game rules to Game and a V4 that still pointed at the live
// models would checksum identically to V5 and break the plan at container
// init.
enum PlayerSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self, Season.self]
    }

    enum Gender: String, Codable {
        case b, g, x
    }

    enum GenderMatching: String, Codable {
        case bx, gx
    }

    enum GenderRatio: String, Codable {
        case twoBThreeG
        case threeBTwoG
    }

    enum PointOutcome: String, Codable {
        case us, them, dead
    }

    enum DrawingElement: Codable {
        case stroke(points: [CGPoint], color: String, lineWidth: CGFloat)
        case arrow(from: CGPoint, to: CGPoint, color: String)
        case circle(center: CGPoint, color: String)
    }

    @Model
    final class Player {
        var name: String = ""
        var gender: Gender = Gender.x
        var defaultMatching: GenderMatching?
        var phoneNumber: String?
        var contactIdentifiers: [String] = []

        var games: [Game]?
        var appearances: [PointPlayer]?
        var pointsScored: [GamePoint]?
        var pointsAssisted: [GamePoint]?

        init(
            name: String,
            gender: Gender,
            defaultMatching: GenderMatching? = nil,
            phoneNumber: String? = nil,
            contactIdentifiers: [String] = []
        ) {
            self.name = name
            self.gender = gender
            self.defaultMatching = defaultMatching
            self.phoneNumber = phoneNumber
            self.contactIdentifiers = contactIdentifiers
        }
    }

    @Model
    final class PointPlayer {
        @Relationship(inverse: \Player.appearances) var player: Player?
        var effectiveGender: GenderMatching = GenderMatching.bx
        var point: GamePoint?

        init(player: Player, effectiveGender: GenderMatching) {
            self.player = player
            self.effectiveGender = effectiveGender
        }
    }

    @Model
    final class GamePoint {
        var number: Int = 0
        var ratio: GenderRatio = GenderRatio.twoBThreeG
        var outcome: PointOutcome = PointOutcome.dead
        @Relationship(deleteRule: .cascade, inverse: \PointPlayer.point)
        var onFieldPlayers: [PointPlayer]?
        @Relationship(inverse: \Player.pointsScored) var scorer: Player?
        @Relationship(inverse: \Player.pointsAssisted) var assist: Player?
        var game: Game?

        init(
            number: Int,
            ratio: GenderRatio,
            outcome: PointOutcome,
            onFieldPlayers: [PointPlayer] = [],
            scorer: Player? = nil,
            assist: Player? = nil
        ) {
            self.number = number
            self.ratio = ratio
            self.outcome = outcome
            self.onFieldPlayers = onFieldPlayers
            self.scorer = scorer
            self.assist = assist
        }
    }

    @Model
    final class Game {
        var opponent: String = ""
        var date: Date = Date.distantPast
        @Relationship(deleteRule: .cascade, inverse: \GamePoint.game)
        var points: [GamePoint]?
        @Relationship(inverse: \Player.games) var availablePlayers: [Player]?
        var isActive: Bool = true
        @Relationship(inverse: \Season.games) var season: Season?

        init(opponent: String, date: Date) {
            self.opponent = opponent
            self.date = date
            self.points = []
            self.availablePlayers = []
            self.isActive = true
        }
    }

    @Model
    final class SavedPlay {
        var name: String = ""
        var elements: [DrawingElement] = []
        var dateCreated: Date = Date.distantPast

        init(name: String, elements: [DrawingElement] = [], dateCreated: Date = Date()) {
            self.name = name
            self.elements = elements
            self.dateCreated = dateCreated
        }
    }

    @Model
    final class Season {
        var name: String = ""
        var startedAt: Date = Date.distantPast
        var endedAt: Date?
        var games: [Game]?

        init(name: String, startedAt: Date = Date()) {
            self.name = name
            self.startedAt = startedAt
        }
    }
}

// V5 adds the rules a game is played under - line size, ratio sequence,
// and starting ratio - as defaulted attributes on Game, so an ABBA game
// on a seven-person line is expressible and history keeps the rules each
// game used. It uses the live models, so it must be frozen the way the
// earlier versions are before a V6 is added.
enum PlayerSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self, Season.self]
    }
}

enum PlayerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PlayerSchemaV2.self, PlayerSchemaV3.self, PlayerSchemaV4.self, PlayerSchemaV5.self]
    }

    // V2 -> V3 is lightweight because every change is one Core Data can
    // infer: added defaults, a relaxed to-one relationship, and new
    // inverse relationships it back-fills from the forward side.
    // MigrationTests asserts that back-fill actually happens rather than
    // assuming it.
    //
    // V3 -> V4 cannot be: adding the Season entity is inferable, but
    // every existing game needs filing under one, and only code can do
    // that. Without it History opens on the current season and finds it
    // empty, because every game the coach has belongs to no season.
    //
    // V4 -> V5 is lightweight again: the rules on Game are added
    // attributes that all carry a default, which Core Data infers.
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: PlayerSchemaV2.self, toVersion: PlayerSchemaV3.self),
            .custom(
                fromVersion: PlayerSchemaV3.self,
                toVersion: PlayerSchemaV4.self,
                willMigrate: nil,
                didMigrate: fileExistingGamesUnderASeason
            ),
            .lightweight(fromVersion: PlayerSchemaV4.self, toVersion: PlayerSchemaV5.self),
        ]
    }

    /// Names the season after the year the coach actually started
    /// playing, not the year they happened to install the update, and
    /// leaves it open so the next game joins it. Runs mid-chain at the V4
    /// shape, so it works in the V4 snapshot types rather than the live
    /// ones, which by now carry V5's extra Game attributes.
    private static func fileExistingGamesUnderASeason(_ context: ModelContext) throws {
        let games = try context.fetch(FetchDescriptor<PlayerSchemaV4.Game>())
        guard let earliest = games.map(\.date).min() else { return }

        let season = PlayerSchemaV4.Season(
            name: Seasons.defaultName(on: earliest),
            startedAt: earliest
        )
        context.insert(season)
        for game in games {
            game.season = season
        }
        try context.save()
    }
}
