import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

@Test func gameCreation() {
    let game = Game(opponent: "Hawks", date: Date())
    #expect(game.opponent == "Hawks")
    #expect(game.points.isEmpty)
    #expect(game.availablePlayers.isEmpty)
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
    #expect(game.points.count == 2)

    let removed = game.undoLastPoint()
    #expect(removed?.outcome == .them)
    #expect(game.points.count == 1)
    #expect(game.ourScore == 1)
    #expect(game.theirScore == 0)
}

@Test func undoLastPointWhenEmpty() {
    let game = Game(opponent: "Hawks", date: Date())
    let removed = game.undoLastPoint()
    #expect(removed == nil)
    #expect(game.points.isEmpty)
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

    #expect(game.points[0].onFieldPlayers.count == 1)
    #expect(game.points[0].onFieldPlayers[0].player === alice)
}

@Test func gamePointStoresStartAndEndTimestamps() {
    let start = Date(timeIntervalSince1970: 1_000)
    let end = Date(timeIntervalSince1970: 1_090)
    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .dead,
        onFieldPlayers: [],
        startedAt: start,
        endedAt: end
    )
    #expect(point.startedAt == start)
    #expect(point.endedAt == end)
    #expect(end.timeIntervalSince(start) == 90)
}

@Test func gamePointTimestampsDefaultToNil() {
    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .dead
    )
    #expect(point.startedAt == nil)
    #expect(point.endedAt == nil)
}

@Test func secondsPlayedSumsCompletedPointDurations() {
    let game = Game(opponent: "Test", date: Date())
    let p1 = Player(name: "P1", gender: .b)
    let p2 = Player(name: "P2", gender: .g)
    game.availablePlayers = [p1, p2]

    let pp1 = PointPlayer(player: p1, effectiveGender: .bx)
    let pp2 = PointPlayer(player: p2, effectiveGender: .gx)
    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .dead,
        onFieldPlayers: [pp1, pp2],
        startedAt: Date(timeIntervalSince1970: 0),
        endedAt: Date(timeIntervalSince1970: 45)
    )
    game.points = [point]

    let totals = game.secondsPlayed()
    #expect(totals[p1] == 45)
    #expect(totals[p2] == 45)
}

@Test func secondsPlayedSkipsPointsWithNilTimestamps() {
    let game = Game(opponent: "Test", date: Date())
    let p1 = Player(name: "P1", gender: .b)
    game.availablePlayers = [p1]

    let pp1 = PointPlayer(player: p1, effectiveGender: .bx)
    let legacyPoint = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .dead,
        onFieldPlayers: [pp1]
    )
    let timedPoint = GamePoint(
        number: 2,
        ratio: .twoBThreeG,
        outcome: .dead,
        onFieldPlayers: [pp1],
        startedAt: Date(timeIntervalSince1970: 100),
        endedAt: Date(timeIntervalSince1970: 130)
    )
    game.points = [legacyPoint, timedPoint]

    let totals = game.secondsPlayed()
    #expect(totals[p1] == 30)
}

@Test func secondsPlayedSeedsAvailablePlayersToZero() {
    let game = Game(opponent: "Test", date: Date())
    let benched = Player(name: "Benched", gender: .b)
    game.availablePlayers = [benched]

    let totals = game.secondsPlayed()
    #expect(totals[benched] == 0)
}
