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
    #expect(GenderRatio.twoBThreeG.displayName == "2B / 3G")
    #expect(GenderRatio.threeBTwoG.displayName == "3B / 2G")
}

@Test func ratioAlternation() {
    #expect(GenderRatio.twoBThreeG.alternated == .threeBTwoG)
    #expect(GenderRatio.threeBTwoG.alternated == .twoBThreeG)
}

@Test func ratioCounts() {
    let ratio = GenderRatio.twoBThreeG
    #expect(ratio.bSideCount == 2)
    #expect(ratio.gSideCount == 3)

    let other = GenderRatio.threeBTwoG
    #expect(other.bSideCount == 3)
    #expect(other.gSideCount == 2)
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

@Test func nextRatioAlternatesFromLatestPoint() {
    let game = Game(opponent: "Hawks", date: Date())
    #expect(game.nextRatio == nil)

    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .them)
    let p2 = GamePoint(number: 2, ratio: .threeBTwoG, outcome: .dead)
    game.points = [p2, p1]

    // Latest point (number 2) was 3B/2G, so the next point alternates back
    #expect(game.nextRatio == .twoBThreeG)
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
