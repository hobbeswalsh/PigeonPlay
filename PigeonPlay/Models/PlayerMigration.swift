import SwiftData

// V2 is the schema baseline. The original V1 schema (parentName /
// parentPhone / parentEmail on Player) and its migration stage were
// removed: the stage could never run. V1's models list reused the live
// Game/GamePoint/PointPlayer classes, whose relationships pulled in the
// live Player and made "V1" alias to V2 ("Duplicate version checksums"
// at container init), and the stage itself failed Core Data validation
// because a migration cannot add the required contactIdentifiers column
// to existing rows. Any real V1 store was already destroyed by the old
// delete-and-retry fallback in PigeonPlayApp before this plan was ever
// consulted, so there is nothing left for a V1 stage to migrate.
//
// Future schema changes: freeze the current models as a fully nested
// snapshot here (every model, so no live class leaks into the old
// version), add PlayerSchemaV3 with a stage, and keep V2 frozen.
enum PlayerSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self]
    }
}

enum PlayerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PlayerSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
