import Testing
import SwiftData
@testable import PigeonPlay

@Test func playerRequiredFields() {
    let player = Player(name: "Alex", gender: .x, defaultMatching: .bx)
    #expect(player.name == "Alex")
    #expect(player.gender == .x)
    #expect(player.defaultMatching == .bx)
}

@Test func playerOptionalFields() {
    let player = Player(name: "Jordan", gender: .b)
    #expect(player.parentName == nil)
    #expect(player.parentPhone == nil)
    #expect(player.parentEmail == nil)
    #expect(player.defaultMatching == nil)
}

@Test func playerWithParentInfo() {
    let player = Player(
        name: "Sam",
        gender: .g,
        parentName: "Pat",
        parentPhone: "555-1234",
        parentEmail: "pat@example.com"
    )
    #expect(player.parentName == "Pat")
    #expect(player.parentPhone == "555-1234")
    #expect(player.parentEmail == "pat@example.com")
}

@Test func genderDisplayValues() {
    #expect(Gender.b.displayName == "B")
    #expect(Gender.g.displayName == "G")
    #expect(Gender.x.displayName == "X")
}

@Test func matchingDisplayValues() {
    #expect(GenderMatching.bx.displayName == "Bx")
    #expect(GenderMatching.gx.displayName == "Gx")
}
