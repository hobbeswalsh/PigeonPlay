import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

// Core Data validates a model against CloudKit's rules synchronously,
// inside ModelContainer.init, before it looks at entitlements or
// credentials. That means the real check runs here with no developer
// account and no iCloud container: build the store with mirroring turned
// on and see whether it loads.
//
// This replaced a set of hand-written assertions about what CloudKit
// requires. They were worth less than they looked: one of them checked
// that to-one relationships were optional, when the actual rule is that
// every relationship must be optional, and the schema shipped broken
// underneath a passing suite. Core Data knows the rules; ask it.
//
// The mirroring delegate does fail afterwards, asynchronously, because
// the container identifier below is not one we own. That failure is
// unrelated to schema shape and cannot affect this test, which has
// already returned by then.

@Test func schemaLoadsWithCloudKitMirroringEnabled() throws {
    let url = URL.temporaryDirectory.appending(path: "cloudkit-\(UUID().uuidString).store")
    defer {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
        }
    }

    // The newest schema in the plan is the one PigeonPlayApp persists, so
    // this follows a version bump without being edited. Force-unwrapped
    // deliberately: a plan with no schemas is a broken app, and this
    // should say so rather than quietly check nothing.
    let schema = Schema(versionedSchema: PlayerMigrationPlan.schemas.last!)

    _ = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .private("iCloud.com.pigeonplay.PigeonPlay")
        )
    )
}
