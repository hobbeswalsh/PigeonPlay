import SwiftUI
import SwiftData

@main
struct PigeonPlayApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Schema(versionedSchema: PlayerSchemaV3.self),
                migrationPlan: PlayerMigrationPlan.self
            )
        } catch {
            // Never fall back to deleting the store: a failed migration
            // must surface as a crash, not as silent loss of every roster
            // and game on the device.
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
