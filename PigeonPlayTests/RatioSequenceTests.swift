import Testing
import Foundation
@testable import PigeonPlay

// The ratio a point is played at is prescribed by its number, the game's
// starting ratio, and the sequence. These tests walk the first eight
// points of each pattern; A is the starting ratio, B its alternate.

private func pattern(
    _ sequence: RatioSequence,
    startingFrom start: GenderRatio,
    points: Int = 8
) -> [GenderRatio] {
    (1...points).map { sequence.ratio(startingFrom: start, pointNumber: $0) }
}

@Test func alternatingFlipsEveryPoint() {
    let a = GenderRatio.twoBThreeG
    let b = a.alternated
    #expect(pattern(.alternating, startingFrom: a) == [a, b, a, b, a, b, a, b])
}

@Test func abbaHoldsEachRatioForTwoPoints() {
    let a = GenderRatio.twoBThreeG
    let b = a.alternated
    #expect(pattern(.abba, startingFrom: a) == [a, b, b, a, a, b, b, a])
}

// The pattern is defined relative to the starting ratio, so starting from
// the other side simply mirrors it.
@Test func sequencesHonorTheStartingRatio() {
    let a = GenderRatio.threeBTwoG
    let b = a.alternated
    #expect(pattern(.alternating, startingFrom: a) == [a, b, a, b, a, b, a, b])
    #expect(pattern(.abba, startingFrom: a) == [a, b, b, a, a, b, b, a])
}

@Test func gameRatioForPointNumberUsesItsOwnSequence() {
    let alternating = Game(opponent: "Hawks", date: Date(), ratioSequence: .alternating, startingRatio: .twoBThreeG)
    #expect((1...4).map(alternating.ratio(forPointNumber:)) == [.twoBThreeG, .threeBTwoG, .twoBThreeG, .threeBTwoG])

    let abba = Game(opponent: "Ravens", date: Date(), ratioSequence: .abba, startingRatio: .threeBTwoG)
    #expect((1...4).map(abba.ratio(forPointNumber:)) == [.threeBTwoG, .twoBThreeG, .twoBThreeG, .threeBTwoG])
}

@Test func nextRatioAdvancesWithRecordedPoints() {
    let game = Game(opponent: "Hawks", date: Date(), ratioSequence: .abba, startingRatio: .twoBThreeG)
    // ABBA: point 1 A, so before any point nextRatio is A.
    #expect(game.nextRatio == .twoBThreeG)

    game.points = [
        GamePoint(number: 1, ratio: .twoBThreeG, outcome: .them),
        GamePoint(number: 2, ratio: .threeBTwoG, outcome: .them),
    ]
    // Next is point 3, which ABBA also plays as B.
    #expect(game.nextRatio == .threeBTwoG)
}
