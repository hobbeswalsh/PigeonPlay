import Foundation
import SwiftData

enum GenderRatio: String, Codable {
    case twoBThreeG
    case threeBTwoG

    var alternated: GenderRatio {
        switch self {
        case .twoBThreeG: .threeBTwoG
        case .threeBTwoG: .twoBThreeG
        }
    }

    /// How many of each side a line carries at this ratio, for a given
    /// line size. The counts follow the size rather than being baked in:
    /// `threeBTwoG` is the B-majority option and gets the extra player on
    /// an odd line, `twoBThreeG` the G-majority one. An even line splits
    /// evenly, so the two options coincide.
    func composition(lineSize: Int) -> LineComposition {
        let larger = (lineSize + 1) / 2
        let smaller = lineSize / 2
        switch self {
        case .threeBTwoG: return LineComposition(bCount: larger, gCount: smaller)
        case .twoBThreeG: return LineComposition(bCount: smaller, gCount: larger)
        }
    }
}

/// The two sides of a line and how many of each it takes.
struct LineComposition: Equatable {
    let bCount: Int
    let gCount: Int

    var displayName: String { "\(bCount)B / \(gCount)G" }
}

/// The pattern the ratio follows point to point. Ultimate prescribes the
/// ratio by point number, not by whatever was last played, so a coach who
/// deviates for one point does not shift the whole rest of the game.
enum RatioSequence: String, Codable, CaseIterable {
    case alternating
    case abba

    var displayName: String {
        switch self {
        case .alternating: "Alternating (ABAB)"
        case .abba: "ABBA"
        }
    }

    /// Ratio prescribed for a 1-based point number, given the ratio of the
    /// first point. `alternating` flips every point (A B A B); `abba` holds
    /// each ratio for two points in an A B B A cycle.
    func ratio(startingFrom start: GenderRatio, pointNumber: Int) -> GenderRatio {
        switch self {
        case .alternating:
            return (pointNumber - 1).isMultiple(of: 2) ? start : start.alternated
        case .abba:
            // A B B A cycle: positions 0 and 3 are the starting ratio.
            let position = (pointNumber - 1) % 4
            return (position == 0 || position == 3) ? start : start.alternated
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
    var onFieldPlayers: [PointPlayer]?
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
    var points: [GamePoint]?
    @Relationship(inverse: \Player.games) var availablePlayers: [Player]?
    var isActive: Bool = true

    // Optional for CloudKit, and because a game restored from a v1
    // archive arrives without one. Readers treat nil as "not yet filed
    // under a season" rather than assuming the current one.
    @Relationship(inverse: \Season.games) var season: Season?

    // The rules the game is played under. Kept on the game itself, not a
    // shared settings row, so history and archives keep the rules each game
    // was actually played by. Defaulted so a lightweight migration carries
    // every existing game onto the values it was already assuming: a
    // five-person line, alternating ratios, starting 2B/3G.
    var lineSize: Int = 5

    // Stored as raw strings, not as the enums directly. A lightweight
    // migration leaves a newly added enum column null and does not apply the
    // Swift default, so reading the non-optional enum back crashes. It does
    // default a plain String column, the way it already does for `name` and
    // `contactIdentifiers`.
    private var ratioSequenceRaw: String = RatioSequence.alternating.rawValue
    private var startingRatioRaw: String = GenderRatio.twoBThreeG.rawValue

    var ratioSequence: RatioSequence {
        get { RatioSequence(rawValue: ratioSequenceRaw) ?? .alternating }
        set { ratioSequenceRaw = newValue.rawValue }
    }

    var startingRatio: GenderRatio {
        get { GenderRatio(rawValue: startingRatioRaw) ?? .twoBThreeG }
        set { startingRatioRaw = newValue.rawValue }
    }

    init(
        opponent: String,
        date: Date,
        lineSize: Int = 5,
        ratioSequence: RatioSequence = .alternating,
        startingRatio: GenderRatio = .twoBThreeG
    ) {
        self.opponent = opponent
        self.date = date
        self.points = []
        self.availablePlayers = []
        self.isActive = true
        self.lineSize = lineSize
        self.ratioSequenceRaw = ratioSequence.rawValue
        self.startingRatioRaw = startingRatio.rawValue
    }

    var ourScore: Int {
        (points ?? []).filter { $0.outcome == .us }.count
    }

    var theirScore: Int {
        (points ?? []).filter { $0.outcome == .them }.count
    }

    // SwiftData does not guarantee to-many relationship order across
    // fetches; anything chronological must go through this.
    var sortedPoints: [GamePoint] {
        (points ?? []).sorted { $0.number < $1.number }
    }

    var nextPointNumber: Int {
        ((points ?? []).map(\.number).max() ?? 0) + 1
    }

    /// Ratio this game's sequence prescribes for a 1-based point number.
    func ratio(forPointNumber number: Int) -> GenderRatio {
        ratioSequence.ratio(startingFrom: startingRatio, pointNumber: number)
    }

    /// Ratio prescribed for the upcoming point. Derived from the point
    /// number rather than the last recorded ratio, so it survives a relaunch
    /// and an ABBA game keeps its pattern even if a coach overrode a point.
    var nextRatio: GenderRatio {
        ratio(forPointNumber: nextPointNumber)
    }

    /// Recorded points played per available player. Players who have not
    /// taken the field map to 0. Appearances whose player has been
    /// deleted count toward nobody.
    var pointsPlayed: [Player: Int] {
        var counts: [Player: Int] = [:]
        for player in availablePlayers ?? [] {
            counts[player] = 0
        }
        for point in points ?? [] {
            for pp in point.onFieldPlayers ?? [] {
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
            let playedIDs = Set((point.onFieldPlayers ?? []).compactMap { $0.player?.persistentModelID })
            for player in availablePlayers ?? [] where !playedIDs.contains(player.persistentModelID) {
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
        return (points ?? []).contains { point in
            (point.onFieldPlayers ?? []).contains { $0.player?.persistentModelID == id }
                || point.scorer?.persistentModelID == id
                || point.assist?.persistentModelID == id
        }
    }

    @discardableResult
    func undoLastPoint() -> GamePoint? {
        guard let point = sortedPoints.last,
              let index = points?.firstIndex(of: point) else { return nil }
        points?.remove(at: index)
        // Removing from the array only detaches the point; delete it so
        // undone points (and their PointPlayers, via cascade) don't
        // accumulate in the store.
        modelContext?.delete(point)
        return point
    }
}
