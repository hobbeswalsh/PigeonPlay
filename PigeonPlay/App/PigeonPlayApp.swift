import SwiftUI
import SwiftData

@main
struct PigeonPlayApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self,
                migrationPlan: PlayerMigrationPlan.self
            )
        } catch {
            // Migration failed — likely a fresh install or corrupted store.
            // Delete the store and retry without migration.
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: url)
            do {
                container = try ModelContainer(
                    for: Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self
                )
            } catch {
                fatalError("Failed to initialize ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
