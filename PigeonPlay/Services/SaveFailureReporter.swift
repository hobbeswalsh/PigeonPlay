import Foundation
import SwiftData

/// Carries a failed write from wherever it happened up to the one alert
/// that shows it. A save that fails silently is the exact thing this
/// milestone is trying to stop, so nothing may drop one on the floor.
@Observable
final class SaveFailureReporter {
    var failure: Error?
}

extension ModelContext {
    /// Saves immediately and reports a failure rather than discarding it.
    /// Views cannot throw, so this is how they call `saveNow`.
    func saveNow(reporting reporter: SaveFailureReporter) {
        do {
            try saveNow()
        } catch {
            reporter.failure = error
        }
    }
}
