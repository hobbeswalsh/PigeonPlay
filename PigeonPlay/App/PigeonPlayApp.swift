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
