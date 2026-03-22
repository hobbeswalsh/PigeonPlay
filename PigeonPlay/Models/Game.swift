import Foundation
import SwiftData

enum GenderRatio: String, Codable {
    case twoBThreeG
    case threeBTwoG

    var displayName: String {
        switch self {
        case .twoBThreeG: "2B / 3G"
        case .threeBTwoG: "3B / 2G"
        }
    }

    var alternated: GenderRatio {
        switch self {
        case .twoBThreeG: .threeBTwoG
        case .threeBTwoG: .twoBThreeG
        }
    }

    var bSideCount: Int {
        switch self {
        case .twoBThreeG: 2
        case .threeBTwoG: 3
        }
    }

    var gSideCount: Int {
        switch self {
        case .twoBThreeG: 3
        case .threeBTwoG: 2
        }
    }
}

enum PointOutcome: String, Codable {
    case us, them, dead
}

@Model
final class PointPlayer {
    var player: Player
    var effectiveGender: GenderMatching

    init(player: Player, effectiveGender: GenderMatching) {
        self.player = player
        self.effectiveGender = effectiveGender
    }
}

@Model
final class GamePoint {
    var number: Int
    var ratio: GenderRatio
    var outcome: PointOutcome
    var onFieldPlayers: [PointPlayer]
    var scorer: Player?
    var assist: Player?

    init(
        number: Int,
        ratio: GenderRatio,
        outcome: PointOutcome,
        onFieldPlayers: [PointPlayer] = [],
        scorer: Player? = nil,
        assist: Player? = nil
    ) {
        precondition(outcome != .us || scorer != nil, "Points scored by us must have a scorer")
        self.number = number
        self.ratio = ratio
        self.outcome = outcome
        self.onFieldPlayers = onFieldPlayers
        self.scorer = scorer
        self.assist = assist
    }
}

@Model
final class Game {
    var opponent: String
    var date: Date
    var points: [GamePoint]
    var availablePlayers: [Player]
    var isActive: Bool

    init(opponent: String, date: Date) {
        self.opponent = opponent
        self.date = date
        self.points = []
        self.availablePlayers = []
        self.isActive = true
    }

    var ourScore: Int {
        points.filter { $0.outcome == .us }.count
    }

    var theirScore: Int {
        points.filter { $0.outcome == .them }.count
    }

    @discardableResult
    func undoLastPoint() -> GamePoint? {
        guard !points.isEmpty else { return nil }
        return points.removeLast()
    }
}
