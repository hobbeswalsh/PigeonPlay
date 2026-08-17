import Foundation

/// Where the SwiftData store lives. Named explicitly rather than left to
/// SwiftData's default so that the recovery screen can hand the file to
/// the user when the store will not open.
enum StoreLocation {
    /// Must stay "default.store": that is the name SwiftData picks when a
    /// container is created without an explicit configuration, which is
    /// how every already-installed copy of the app wrote its data. Naming
    /// it anything else silently strands the existing season and starts
    /// the coach with an empty roster.
    static let fileName = "default.store"

    static var url: URL {
        URL.applicationSupportDirectory.appending(path: fileName)
    }

    /// The store plus the write-ahead log and shared-memory files SQLite
    /// keeps beside it. A copy without these can be missing the most
    /// recent writes, which are exactly the ones worth recovering.
    static func sidecarURLs(for storeURL: URL) -> [URL] {
        ["", "-shm", "-wal"].map { URL(filePath: storeURL.path + $0) }
    }
}
