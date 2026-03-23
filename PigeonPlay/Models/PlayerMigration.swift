import SwiftData

enum PlayerSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Player.self] }

    @Model
    final class Player {
        var name: String
        var gender: PigeonPlay.Gender
        var defaultMatching: PigeonPlay.GenderMatching?
        var parentName: String?
        var parentPhone: String?
        var parentEmail: String?

        init(
            name: String,
            gender: PigeonPlay.Gender,
            defaultMatching: PigeonPlay.GenderMatching? = nil,
            parentName: String? = nil,
            parentPhone: String? = nil,
            parentEmail: String? = nil
        ) {
            self.name = name
            self.gender = gender
            self.defaultMatching = defaultMatching
            self.parentName = parentName
            self.parentPhone = parentPhone
            self.parentEmail = parentEmail
        }
    }
}

enum PlayerSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [PigeonPlay.Player.self] }

    // V2 live model is PigeonPlay.Player defined in Player.swift
}

enum PlayerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PlayerSchemaV1.self, PlayerSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [MigrationStage.lightweight(fromVersion: PlayerSchemaV1.self, toVersion: PlayerSchemaV2.self)]
    }
}
