import Testing
import SwiftData
@testable import PigeonPlay

@Test func playerRequiredFields() {
    let player = Player(name: "Alex", gender: .x, defaultMatching: .bx)
    #expect(player.name == "Alex")
    #expect(player.gender == .x)
    #expect(player.defaultMatching == .bx)
}

@Test func playerOptionalFieldsV2() {
    let player = Player(name: "Jordan", gender: .b)
    #expect(player.phoneNumber == nil)
    #expect(player.contactIdentifiers == [])
    #expect(player.defaultMatching == nil)
}

@Test func playerPhoneNumber() {
    let player = Player(name: "Sam", gender: .g, phoneNumber: "555-0100")
    #expect(player.phoneNumber == "555-0100")
}

@Test func playerContactIdentifiers() {
    let player = Player(name: "Alex", gender: .x, contactIdentifiers: ["ABC123", "DEF456"])
    #expect(player.contactIdentifiers.count == 2)
    #expect(player.contactIdentifiers.contains("ABC123"))
    #expect(player.contactIdentifiers.contains("DEF456"))
}

@Test func playerContactIdentifiersDefault() {
    let player = Player(name: "Pat", gender: .b)
    #expect(player.contactIdentifiers.isEmpty)
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

@Test func effectiveMatchingBoy() {
    let player = Player(name: "Tom", gender: .b)
    #expect(player.effectiveMatching == .bx)
}

@Test func effectiveMatchingGirl() {
    let player = Player(name: "Jane", gender: .g)
    #expect(player.effectiveMatching == .gx)
}

@Test func effectiveMatchingXWithDefault() {
    let player = Player(name: "Alex", gender: .x, defaultMatching: .gx)
    #expect(player.effectiveMatching == .gx)
}

@Test func effectiveMatchingXWithoutDefault() {
    let player = Player(name: "Sam", gender: .x)
    #expect(player.effectiveMatching == .bx)
}
