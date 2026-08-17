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
// declares an inverse. CloudKitSchemaTests asserts those properties hold.
// It uses the live models, so it must be frozen the same way V2 is before
// a V4 is added.
enum PlayerSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self]
    }
}

enum PlayerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PlayerSchemaV2.self, PlayerSchemaV3.self]
    }

    // Lightweight because every V3 change is one Core Data can infer:
    // added defaults, a relaxed to-one relationship, and new inverse
    // relationships it back-fills from the forward side. MigrationTests
    // asserts that back-fill actually happens rather than assuming it.
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: PlayerSchemaV2.self, toVersion: PlayerSchemaV3.self)]
    }
}
