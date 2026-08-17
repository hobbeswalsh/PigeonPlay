import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

// CloudKit mirroring refuses a model that breaks any of these rules, and
// it reports the breakage when the container initializes on a user's
// device rather than when we build. Asserting the rules against the live
// models keeps a later schema change from shipping a store that silently
// cannot sync.
//
// Taken from the migration plan's newest schema rather than a list of
// model types written out here. The constraint belongs to whatever the
// app currently persists, and PigeonPlayApp builds its container from
// that same newest schema, so this follows a version bump on its own and
// cannot drift out of date by omitting a model someone added later.
// Force-unwrapped on purpose: a migration plan with no schemas is a
// broken app, and these tests should say so rather than quietly check
// nothing.
private let liveSchema = Schema(versionedSchema: PlayerMigrationPlan.schemas.last!)

@Test func everyAttributeIsOptionalOrCarriesADefault() {
    for entity in liveSchema.entities {
        for attribute in entity.attributes {
            #expect(
                attribute.isOptional || attribute.defaultValue != nil,
                "\(entity.name).\(attribute.name) is neither optional nor defaulted"
            )
        }
    }
}

@Test func everyToOneRelationshipIsOptional() {
    for entity in liveSchema.entities {
        for relationship in entity.relationships where relationship.isToOneRelationship {
            #expect(
                relationship.isOptional,
                "\(entity.name).\(relationship.name) is a required to-one relationship"
            )
        }
    }
}

@Test func everyRelationshipDeclaresAnInverse() {
    for entity in liveSchema.entities {
        for relationship in entity.relationships {
            #expect(
                relationship.inverseName != nil,
                "\(entity.name).\(relationship.name) has no inverse"
            )
        }
    }
}

@Test func noEntityDeclaresAUniquenessConstraint() {
    for entity in liveSchema.entities {
        #expect(
            entity.uniquenessConstraints.isEmpty,
            "\(entity.name) declares a uniqueness constraint"
        )
    }
}

@Test func noRelationshipUsesTheDenyDeleteRule() {
    for entity in liveSchema.entities {
        for relationship in entity.relationships {
            #expect(
                relationship.deleteRule != .deny,
                "\(entity.name).\(relationship.name) uses the .deny delete rule"
            )
        }
    }
}
