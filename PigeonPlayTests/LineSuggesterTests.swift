import Testing
import Foundation
@testable import PigeonPlay

@Test func suggestsPlayersWithFewestPoints() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)
    let g4 = Player(name: "G4", gender: .g)

    let available = [b1, b2, g1, g2, g3, g4]
    // g1 has played 2 points, everyone else 0
    let pointsPlayed: [Player: Int] = [
        b1: 0, b2: 0, g1: 2, g2: 0, g3: 0, g4: 0
    ]
    let lastPointOnBench: [Player: Int] = [:]

    let suggestion = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )

    #expect(suggestion.bSide.count == 2)
    #expect(suggestion.gSide.count == 3)
    // g1 should NOT be suggested since she's played the most
    #expect(!suggestion.gSide.map(\.player).contains(where: { $0 === g1 }))
}

@Test func respectsGenderRatio() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let b3 = Player(name: "B3", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)

    let available = [b1, b2, b3, g1, g2, g3]
    let pointsPlayed: [Player: Int] = [:]
    let lastPointOnBench: [Player: Int] = [:]

    let twoBThreeG = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )
    #expect(twoBThreeG.bSide.count == 2)
    #expect(twoBThreeG.gSide.count == 3)

    let threeBTwoG = LineSuggester.suggest(
        available: available,
        ratio: .threeBTwoG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )
    #expect(threeBTwoG.bSide.count == 3)
    #expect(threeBTwoG.gSide.count == 2)
}

@Test func xPlayersUseDefaultMatching() {
    let b1 = Player(name: "B1", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)
    let x1 = Player(name: "X1", gender: .x, defaultMatching: .bx)

    let available = [b1, g1, g2, g3, x1]
    let pointsPlayed: [Player: Int] = [:]
    let lastPointOnBench: [Player: Int] = [:]

    let suggestion = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )

    // X1 defaults to Bx, so should be on B-side
    #expect(suggestion.bSide.map(\.player).contains(where: { $0 === x1 }))
    #expect(suggestion.bSide.first(where: { $0.player === x1 })?.matching == .bx)
}

@Test func tieBreaksByBenchTime() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let b3 = Player(name: "B3", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)

    let available = [b1, b2, b3, g1, g2, g3]
    // Three points at 2B/3G: each boy sat exactly one of them, so the boys are
    // level on two apiece, and the three girls played every point.
    let pointsPlayed: [Player: Int] = [
        b1: 2, b2: 2, b3: 2, g1: 3, g2: 3, g3: 3
    ]
    // b1 sat the most recent point and b3 the oldest, so b1 is owed the next one.
    let lastPointOnBench: [Player: Int] = [
        b1: 3, b2: 2, b3: 1
    ]

    let suggestion = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )

    #expect(Set(suggestion.bSide.map(\.player.name)) == ["B1", "B2"])
}

@Test func excludesCurrentLine() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let b3 = Player(name: "B3", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)
    let g4 = Player(name: "G4", gender: .g)

    let available = [b1, b2, b3, g1, g2, g3, g4]
    // b3 and g4 have played a point so the first suggestion deterministically
    // picks b1, b2 and g1, g2, g3 (the shuffle only randomizes ties)
    let pointsPlayed: [Player: Int] = [
        b1: 0, b2: 0, b3: 1,
        g1: 0, g2: 0, g3: 0, g4: 1
    ]
    let lastPointOnBench: [Player: Int] = [:]

    let first = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )
    let firstPlayers = Set(first.allEntries.map { ObjectIdentifier($0.player) })
    #expect(!firstPlayers.contains(ObjectIdentifier(b3)))
    #expect(!firstPlayers.contains(ObjectIdentifier(g4)))

    // Shuffle with exclusion prefers the non-excluded players despite their
    // higher points played
    let shuffled = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench,
        excluding: Set(first.allEntries.map { $0.player })
    )
    let shuffledPlayers = Set(shuffled.allEntries.map { ObjectIdentifier($0.player) })

    #expect(shuffledPlayers.contains(ObjectIdentifier(b3)))
    #expect(shuffledPlayers.contains(ObjectIdentifier(g4)))
    #expect(shuffledPlayers != firstPlayers)
}

@Test func countingCurrentPointAddsOneForOnFieldPlayers() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)

    let pointsPlayed: [Player: Int] = [b1: 1, b2: 0, g1: 2, g2: 1]
    let onField: [Player] = [b1, g1]

    let adjusted = LineSuggester.countingCurrentPoint(
        pointsPlayed: pointsPlayed,
        onFieldPlayers: onField
    )

    #expect(adjusted[b1] == 2)  // was 1, on field → 2
    #expect(adjusted[b2] == 0)  // not on field, unchanged
    #expect(adjusted[g1] == 3)  // was 2, on field → 3
    #expect(adjusted[g2] == 1)  // not on field, unchanged
}

@Test func countingCurrentPointAffectsSuggestion() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let b3 = Player(name: "B3", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)
    let g4 = Player(name: "G4", gender: .g)

    // b1 and b2 each have 1pt, b3 has 1pt too
    // Without adjustment, all boys are tied at 1pt
    // But b1 is on field, so with adjustment b1 has 2pt → b2 and b3 preferred
    let pointsPlayed: [Player: Int] = [
        b1: 1, b2: 1, b3: 1,
        g1: 0, g2: 0, g3: 0, g4: 0
    ]
    let onField: [Player] = [b1]

    let adjusted = LineSuggester.countingCurrentPoint(
        pointsPlayed: pointsPlayed,
        onFieldPlayers: onField
    )

    for _ in 0..<20 {
        let suggestion = LineSuggester.suggest(
            available: [b1, b2, b3, g1, g2, g3, g4],
            ratio: .twoBThreeG,
            pointsPlayed: adjusted,
            lastPointOnBench: [:]
        )
        let bPicked = suggestion.bSide.map(\.player)
        // b1 now has 2pts vs b2/b3 at 1pt — b1 should never be picked
        #expect(!bPicked.contains(where: { $0 === b1 }))
    }
}

@Test func shuffleNeverPromotesHigherPointsPlayed() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let b3 = Player(name: "B3", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)
    let g4 = Player(name: "G4", gender: .g)

    let available = [b1, b2, b3, g1, g2, g3, g4]
    // b1 and g1 have played 1 point; everyone else 0
    let pointsPlayed: [Player: Int] = [
        b1: 1, b2: 0, b3: 0,
        g1: 1, g2: 0, g3: 0, g4: 0
    ]

    // Run 20 times — a player with 1pt should never be picked when
    // there are enough 0pt players to fill the line
    for _ in 0..<20 {
        let suggestion = LineSuggester.suggest(
            available: available,
            ratio: .twoBThreeG,
            pointsPlayed: pointsPlayed,
            lastPointOnBench: [:]
        )
        let picked = suggestion.allEntries.map { $0.player }
        // 2 B-side slots, 2 boys with 0pts (b2, b3) — b1 (1pt) should never appear
        #expect(!picked.contains(where: { $0 === b1 }))
        // 3 G-side slots, 3 girls with 0pts (g2, g3, g4) — g1 (1pt) should never appear
        #expect(!picked.contains(where: { $0 === g1 }))
    }
}

@Test func prefersPlayersWhoSatMostRecentlyWhenPointsAreEqual() {
    let bs = (1...4).map { Player(name: "B\($0)", gender: .b) }
    let gs = (1...6).map { Player(name: "G\($0)", gender: .g) }
    let game = Game(opponent: "Hawks", date: Date())
    game.availablePlayers = bs + gs

    // Points 1-3 go to the first half of each pool and 4-6 to the second, so
    // everyone has played three and the only thing separating them is who has
    // been sitting since point 3.
    game.points = (1...6).map { number in
        let firstShift = number <= 3
        let boys = firstShift ? bs[0..<2] : bs[2..<4]
        let girls = firstShift ? gs[0..<3] : gs[3..<6]
        return GamePoint(
            number: number,
            ratio: .twoBThreeG,
            outcome: .dead,
            onFieldPlayers: boys.map { PointPlayer(player: $0, effectiveGender: .bx) }
                + girls.map { PointPlayer(player: $0, effectiveGender: .gx) }
        )
    }

    #expect(Set(game.pointsPlayed.values) == [3])

    let suggestion = LineSuggester.suggest(
        available: bs + gs,
        ratio: .twoBThreeG,
        pointsPlayed: game.pointsPlayed,
        lastPointOnBench: game.lastPointOnBench
    )

    // B1, B2, G1, G2 and G3 have sat points 4, 5 and 6. Sending the others out
    // again would be their fourth point in a row.
    let picked = Set(suggestion.allEntries.map(\.player.name))
    #expect(picked == ["B1", "B2", "G1", "G2", "G3"])
}
