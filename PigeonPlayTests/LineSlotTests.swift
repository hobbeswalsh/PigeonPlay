import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

extension StoreTests {
@Suite struct LineSlotStorage {

// The live models, unversioned: these tests are about delete rules, not
// about migration, so they do not depend on the schema plan.
private func makeContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Player.self, Game.self, GamePoint.self, PointPlayer.self,
            SavedPlay.self, Season.self, LineSlot.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

@Test func deletingGameDeletesItsLineSlots() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let player = Player(name: "Alex", gender: .b)
    let game = Game(opponent: "Hawks", date: Date())
    context.insert(player)
    context.insert(game)
    game.lineSlots = [LineSlot(kind: .selected, position: 0, player: player, matching: .bx)]
    try context.save()

    context.delete(game)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<LineSlot>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<Player>()).count == 1)
}

@Test func deletingPlayerKeepsTheSlotAndClearsItsPlayer() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let player = Player(name: "Alex", gender: .b)
    let game = Game(opponent: "Hawks", date: Date())
    context.insert(player)
    context.insert(game)
    game.lineSlots = [LineSlot(kind: .queued, position: 0, player: player, matching: .bx)]
    try context.save()

    context.delete(player)
    try context.save()

    let slots = try context.fetch(FetchDescriptor<LineSlot>())
    #expect(slots.count == 1)
    #expect(slots.first?.player == nil)
}

}
}
