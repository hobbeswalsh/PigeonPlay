import SwiftData

extension ModelContext {
    /// Writes pending changes to disk now rather than when autosave
    /// decides to. Call it after anything the coach would be upset to
    /// lose: iOS can kill a backgrounded app between points, and autosave
    /// makes no promise about having run by then.
    func saveNow() throws {
        guard hasChanges else { return }
        try save()
    }
}
