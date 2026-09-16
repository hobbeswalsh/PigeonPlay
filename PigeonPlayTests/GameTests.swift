import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

@Test func gameCreation() {
    let game = Game(opponent: "Hawks", date: Date())
    #expect(game.opponent == "Hawks")
    #expect((game.points ?? []).isEmpty)
    #expect((game.availablePlayers ?? []).isEmpty)
    #expect(game.isActive == true)
}

@Test func ratioDisplayValues() {
    #expect(GenderRatio.twoBThreeG.composition(lineSize: 5).displayName == "2B / 3G")
    #expect(GenderRatio.threeBTwoG.composition(lineSize: 5).displayName == "3B / 2G")
}

@Test func ratioAlternation() {
    #expect(GenderRatio.twoBThreeG.alternated == .threeBTwoG)
    #expect(GenderRatio.threeBTwoG.alternated == .twoBThreeG)
}

@Test func ratioCountsForAFivePersonLine() {
    #expect(GenderRatio.twoBThreeG.composition(lineSize: 5) == LineComposition(bCount: 2, gCount: 3))
    #expect(GenderRatio.threeBTwoG.composition(lineSize: 5) == LineComposition(bCount: 3, gCount: 2))
}

// The extra player on an odd line goes to the named majority side; an
// even line splits evenly, so the two ratios coincide.
@Test func ratioCountsFollowLineSize() {
    #expect(GenderRatio.threeBTwoG.composition(lineSize: 7) == LineComposition(bCount: 4, gCount: 3))
    #expect(GenderRatio.twoBThreeG.composition(lineSize: 7) == LineComposition(bCount: 3, gCount: 4))
    #expect(GenderRatio.threeBTwoG.composition(lineSize: 4) == LineComposition(bCount: 2, gCount: 2))
    #expect(GenderRatio.twoBThreeG.composition(lineSize: 4) == LineComposition(bCount: 2, gCount: 2))
    #expect(GenderRatio.threeBTwoG.composition(lineSize: 3) == LineComposition(bCount: 2, gCount: 1))
}

@Test func pointCreation() {
    let scorer = Player(name: "Alex", gender: .b)
    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .us,
        scorer: scorer
    )
    #expect(point.number == 1)
    #expect(point.ratio == .twoBThreeG)
    #expect(point.outcome == .us)
    #expect(point.scorer === scorer)
    #expect(point.assist == nil)
}

@Test func themPointAllowsNilScorer() {
    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .them
    )
    #expect(point.scorer == nil)
}

@Test func gameScore() {
    let game = Game(opponent: "Hawks", date: Date())
    let scorer = Player(name: "Alex", gender: .b)
    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .us, scorer: scorer)
    let p2 = GamePoint(number: 2, ratio: .threeBTwoG, outcome: .them)
    let p3 = GamePoint(number: 3, ratio: .twoBThreeG, outcome: .us, scorer: scorer)
    game.points = [p1, p2, p3]
    #expect(game.ourScore == 2)
    #expect(game.theirScore == 1)
}

@Test func undoLastPoint() {
    let game = Game(opponent: "Hawks", date: Date())
    let scorer = Player(name: "Alex", gender: .b)
    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .us, scorer: scorer)
    let p2 = GamePoint(number: 2, ratio: .threeBTwoG, outcome: .them)
    game.points = [p1, p2]
    #expect((game.points ?? []).count == 2)

    let removed = game.undoLastPoint()
    #expect(removed?.outcome == .them)
    #expect((game.points ?? []).count == 1)
    #expect(game.ourScore == 1)
    #expect(game.theirScore == 0)
}

@Test func undoLastPointWhenEmpty() {
    let game = Game(opponent: "Hawks", date: Date())
    let removed = game.undoLastPoint()
    #expect(removed == nil)
    #expect((game.points ?? []).isEmpty)
}

@Test func deadPointCreation() {
    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .dead
    )
    #expect(point.outcome == .dead)
    #expect(point.scorer == nil)
    #expect(point.assist == nil)
}

@Test func deadPointDoesNotAffectScore() {
    let game = Game(opponent: "Hawks", date: Date())
    let scorer = Player(name: "Alex", gender: .b)
    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .us, scorer: scorer)
    let p2 = GamePoint(number: 2, ratio: .threeBTwoG, outcome: .dead)
    let p3 = GamePoint(number: 3, ratio: .twoBThreeG, outcome: .them)
    game.points = [p1, p2, p3]
    #expect(game.ourScore == 1)
    #expect(game.theirScore == 1)
}

@Test func deadPointCountsAsPlayed() {
    let game = Game(opponent: "Hawks", date: Date())
    let alice = Player(name: "Alice", gender: .g)
    let pp = PointPlayer(player: alice, effectiveGender: .gx)

    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .dead, onFieldPlayers: [pp])
    game.points = [p1]

    #expect((game.points ?? [])[0].onFieldPlayers?.count == 1)
    #expect((game.points ?? [])[0].onFieldPlayers?[0].player === alice)
}

// MARK: - Point ordering
// SwiftData does not guarantee to-many relationship order across fetches,
// so everything chronological must go through GamePoint.number. These
// tests scramble the array to simulate an out-of-order fetch.

@Test func sortedPointsOrdersByNumber() {
    let game = Game(opponent: "Hawks", date: Date())
    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .them)
    let p2 = GamePoint(number: 2, ratio: .threeBTwoG, outcome: .dead)
    let p3 = GamePoint(number: 3, ratio: .twoBThreeG, outcome: .them)
    game.points = [p2, p3, p1]

    #expect(game.sortedPoints.map(\.number) == [1, 2, 3])
}

@Test func undoLastPointRemovesHighestNumberedPoint() {
    let game = Game(opponent: "Hawks", date: Date())
    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .them)
    let p2 = GamePoint(number: 2, ratio: .threeBTwoG, outcome: .dead)
    let p3 = GamePoint(number: 3, ratio: .twoBThreeG, outcome: .them)
    game.points = [p3, p1, p2]

    let undone = game.undoLastPoint()
    #expect(undone?.number == 3)
    #expect(Set((game.points ?? []).map(\.number)) == [1, 2])
}

@Test func nextPointNumberIncrementsFromHighest() {
    let game = Game(opponent: "Hawks", date: Date())
    #expect(game.nextPointNumber == 1)

    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .them)
    let p2 = GamePoint(number: 2, ratio: .threeBTwoG, outcome: .dead)
    game.points = [p2, p1]
    #expect(game.nextPointNumber == 3)

    game.undoLastPoint()
    #expect(game.nextPointNumber == 2)
}

// nextRatio follows the sequence by point number, not the last recorded
// ratio, so a coach who overrides one point does not shift the rest of the
// game and the pattern survives a relaunch.
@Test func nextRatioFollowsTheSequenceByPointNumber() {
    let game = Game(opponent: "Hawks", date: Date())
    // A fresh game's first point is the starting ratio.
    #expect(game.nextRatio == .twoBThreeG)

    // Coach deviated on point 2, but point 3 still follows the alternating
    // sequence from the start (2B/3G) rather than flipping the override.
    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .them)
    let p2 = GamePoint(number: 2, ratio: .twoBThreeG, outcome: .dead)
    game.points = [p2, p1]
    #expect(game.nextRatio == .twoBThreeG)
}

@Test func defaultGameRulesAreAFivePersonAlternatingLine() {
    let game = Game(opponent: "Hawks", date: Date())
    #expect(game.lineSize == 5)
    #expect(game.ratioSequence == .alternating)
    #expect(game.startingRatio == .twoBThreeG)
}

// MARK: - Per-player stats

@Test func pointsPlayedCountsOnFieldAppearances() {
    let a = Player(name: "A", gender: .b)
    let b = Player(name: "B", gender: .g)
    let benched = Player(name: "C", gender: .b)
    let game = Game(opponent: "Hawks", date: Date())
    game.availablePlayers = [a, b, benched]

    let p1 = GamePoint(
        number: 1, ratio: .twoBThreeG, outcome: .them,
        onFieldPlayers: [
            PointPlayer(player: a, effectiveGender: .bx),
            PointPlayer(player: b, effectiveGender: .gx),
        ]
    )
    let p2 = GamePoint(
        number: 2, ratio: .threeBTwoG, outcome: .dead,
        onFieldPlayers: [PointPlayer(player: a, effectiveGender: .bx)]
    )
    game.points = [p1, p2]

    let played = game.pointsPlayed
    #expect(played[a] == 2)
    #expect(played[b] == 1)
    #expect(played[benched] == 0)
}

@Test func lastPointOnBenchUsesPointNumbersNotArrayOrder() {
    let a = Player(name: "A", gender: .b)
    let b = Player(name: "B", gender: .g)
    let game = Game(opponent: "Hawks", date: Date())
    game.availablePlayers = [a, b]

    // a sat out point 1, b sat out point 3; array deliberately scrambled
    let p1 = GamePoint(
        number: 1, ratio: .twoBThreeG, outcome: .them,
        onFieldPlayers: [PointPlayer(player: b, effectiveGender: .gx)]
    )
    let p2 = GamePoint(
        number: 2, ratio: .threeBTwoG, outcome: .dead,
        onFieldPlayers: [
            PointPlayer(player: a, effectiveGender: .bx),
            PointPlayer(player: b, effectiveGender: .gx),
        ]
    )
    let p3 = GamePoint(
        number: 3, ratio: .twoBThreeG, outcome: .them,
        onFieldPlayers: [PointPlayer(player: a, effectiveGender: .bx)]
    )
    game.points = [p3, p1, p2]

    let bench = game.lastPointOnBench
    #expect(bench[a] == 1)
    #expect(bench[b] == 3)
}
