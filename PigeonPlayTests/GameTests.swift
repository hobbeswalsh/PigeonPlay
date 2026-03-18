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
