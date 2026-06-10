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
    @Relationship(deleteRule: .cascade) var onFieldPlayers: [PointPlayer]
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
        precondition(outcome != .dead || scorer == nil, "Dead points must not have a scorer")
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
    @Relationship(deleteRule: .cascade) var points: [GamePoint]
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

    // SwiftData does not guarantee to-many relationship order across
    // fetches; anything chronological must go through this.
    var sortedPoints: [GamePoint] {
        points.sorted { $0.number < $1.number }
    }

    var nextPointNumber: Int {
        (points.map(\.number).max() ?? 0) + 1
    }

    /// Ratio for the upcoming point, alternating from the latest recorded
    /// point. Nil when no point has been recorded yet.
    var nextRatio: GenderRatio? {
        sortedPoints.last?.ratio.alternated
    }

    /// Recorded points played per available player. Players who have not
    /// taken the field map to 0.
    var pointsPlayed: [Player: Int] {
        var counts: [Player: Int] = [:]
        for player in availablePlayers {
            counts[player] = 0
        }
        for point in points {
            for pp in point.onFieldPlayers {
                counts[pp.player, default: 0] += 1
            }
        }
        return counts
    }

    /// The most recent point number each available player sat out.
    /// Players who have never sat out are absent from the result.
    var lastPointOnBench: [Player: Int] {
        var last: [Player: Int] = [:]
        for point in sortedPoints {
            let playedIDs = Set(point.onFieldPlayers.map { ObjectIdentifier($0.player) })
            for player in availablePlayers where !playedIDs.contains(ObjectIdentifier(player)) {
                last[player] = point.number
            }
        }
        return last
    }

    /// Whether the player appears in any recorded point (on field, as
    /// scorer, or as assist). Such players must not be deleted: doing so
    /// would dangle the non-optional PointPlayer.player reference.
    func involves(_ player: Player) -> Bool {
        let id = player.persistentModelID
        return points.contains { point in
            point.onFieldPlayers.contains { $0.player.persistentModelID == id }
                || point.scorer?.persistentModelID == id
                || point.assist?.persistentModelID == id
        }
    }

    @discardableResult
    func undoLastPoint() -> GamePoint? {
        guard let point = sortedPoints.last,
              let index = points.firstIndex(of: point) else { return nil }
        points.remove(at: index)
        // Removing from the array only detaches the point; delete it so
        // undone points (and their PointPlayers, via cascade) don't
        // accumulate in the store.
        modelContext?.delete(point)
        return point
    }
}
