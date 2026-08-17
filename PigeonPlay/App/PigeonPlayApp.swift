import SwiftUI
import SwiftData

@main
struct PigeonPlayApp: App {
    // Never fall back to deleting the store: a failed migration must not
    // become silent loss of every roster and game on the device. It used
    // to be a fatalError instead, which kept the data but left the coach
    // with an app that would not launch and no way to get it out.
    private let container: Result<ModelContainer, Error>

    init() {
        container = Result {
            try ModelContainer(
                for: Schema(versionedSchema: PlayerSchemaV3.self),
                migrationPlan: PlayerMigrationPlan.self,
                configurations: ModelConfiguration(
                    schema: Schema(versionedSchema: PlayerSchemaV3.self),
                    url: StoreLocation.url
                )
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                ContentView()
                    .modelContainer(container)
            case .failure(let error):
                StoreRecoveryView(error: error, storeURL: StoreLocation.url)
            }
        }
    }
}
