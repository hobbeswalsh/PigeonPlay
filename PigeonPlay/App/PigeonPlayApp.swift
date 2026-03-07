import SwiftUI
import SwiftData

@main
struct PigeonPlayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Player.self, Game.self, SavedPlay.self])
    }
}
