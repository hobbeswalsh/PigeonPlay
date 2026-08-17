import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

// Naming the store explicitly is what lets StoreRecoveryView hand the
// file to the user, but it also means we now own a name that used to be
// SwiftData's to choose. Get it wrong and an existing install opens a
// brand new empty store while the real season sits beside it, unread and
// unmentioned - the exact failure this milestone is about.
//
// These assert the constant rather than comparing against a container
// built with SwiftData's implicit configuration. That comparison would be
// the stronger test, but building it opens the app's actual store and
// migrates it, which is not something a unit test should do to the
// device it runs on. So this is a tripwire: it cannot prove the name is
// right, only stop someone changing it without reading why they should
// not.
struct StoreLocationTests {

    @Test func storeKeepsTheNameSwiftDataGaveItBeforeWeNamedItOurselves() {
        #expect(StoreLocation.fileName == "default.store")
    }

    @Test func storeSitsInApplicationSupport() {
        #expect(StoreLocation.url.deletingLastPathComponent() == URL.applicationSupportDirectory)
        #expect(StoreLocation.url.lastPathComponent == "default.store")
    }

    @Test func sidecarsCoverTheWriteAheadLogAndSharedMemory() {
        let store = URL(filePath: "/tmp/example.store")
        let names = StoreLocation.sidecarURLs(for: store).map(\.lastPathComponent)
        #expect(names == ["example.store", "example.store-shm", "example.store-wal"])
    }
}
