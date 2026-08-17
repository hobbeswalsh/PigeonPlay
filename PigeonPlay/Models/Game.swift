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
    // Optional because CloudKit forbids a required to-one relationship.
    // That is also what closes the deletion hole: deleting a Player used
    // to leave this pointing at a dead object, and now it nullifies.
    // Every reader must therefore treat a nil player as "this appearance
    // belongs to someone who is no longer on the roster".
    @Relationship(inverse: \Player.appearances) var player: Player?
    var effectiveGender: GenderMatching = GenderMatching.bx
    var point: GamePoint?

    init(player: Player, effectiveGender: GenderMatching) {
        self.player = player
        self.effectiveGender = effectiveGender
    }
}

@Model
final class GamePoint {
    var number: Int = 0
    var ratio: GenderRatio = GenderRatio.twoBThreeG
    var outcome: PointOutcome = PointOutcome.dead
    @Relationship(deleteRule: .cascade, inverse: \PointPlayer.point)
    var onFieldPlayers: [PointPlayer] = []
    @Relationship(inverse: \Player.pointsScored) var scorer: Player?
    @Relationship(inverse: \Player.pointsAssisted) var assist: Player?
    var game: Game?

    // These guard construction only. A record arriving from CloudKit is
    // materialised without going through init, so they are not an
    // invariant the rest of the code may lean on for synced data.
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
    var opponent: String = ""
    // Only ever reached by a record that arrives without a date, which
    // init makes impossible. distantPast keeps such a row at the bottom
    // of the date-descending history list rather than the top.
    var date: Date = Date.distantPast
    @Relationship(deleteRule: .cascade, inverse: \GamePoint.game)
    var points: [GamePoint] = []
    @Relationship(inverse: \Player.games) var availablePlayers: [Player] = []
    var isActive: Bool = true

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
    /// taken the field map to 0. Appearances whose player has been
    /// deleted count toward nobody.
    var pointsPlayed: [Player: Int] {
        var counts: [Player: Int] = [:]
        for player in availablePlayers {
            counts[player] = 0
        }
        for point in points {
            for pp in point.onFieldPlayers {
                guard let player = pp.player else { continue }
                counts[player, default: 0] += 1
            }
        }
        return counts
    }

    /// The most recent point number each available player sat out.
    /// Players who have never sat out are absent from the result.
    var lastPointOnBench: [Player: Int] {
        var last: [Player: Int] = [:]
        for point in sortedPoints {
            let playedIDs = Set(point.onFieldPlayers.compactMap { $0.player?.persistentModelID })
            for player in availablePlayers where !playedIDs.contains(player.persistentModelID) {
                last[player] = point.number
            }
        }
        return last
    }

    /// Whether the player appears in any recorded point (on field, as
    /// scorer, or as assist). Deleting such a player drops the record of
    /// what they did, so the roster refuses it.
    func involves(_ player: Player) -> Bool {
        let id = player.persistentModelID
        return points.contains { point in
            point.onFieldPlayers.contains { $0.player?.persistentModelID == id }
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
