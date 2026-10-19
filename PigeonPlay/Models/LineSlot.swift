import Foundation
import SwiftData

enum GamePhase: String, Codable {
    case selectingLine
    case recordingPoint
}

enum LineKind: String, Codable {
    case selected
    case queued
}

/// One place in a line that has been chosen but not yet recorded.
///
/// A `Game` keeps these so a line survives the app being ended between
/// "Lock In" and "record point". They are scratch state: recording a point
/// copies the selected slots into `PointPlayer`s, and they carry the matching
/// the coach saw because a short side can put a Bx player on a G slot.
@Model
final class LineSlot {
    var kind: LineKind = LineKind.selected
    var position: Int = 0
    var matching: GenderMatching = GenderMatching.bx

    // Optional because CloudKit requires it. A nil player means the player
    // was deleted after the line was built; readers drop such a slot.
    @Relationship(inverse: \Player.lineSlots) var player: Player?
    var game: Game?

    init(kind: LineKind, position: Int, player: Player, matching: GenderMatching) {
        self.kind = kind
        self.position = position
        self.player = player
        self.matching = matching
    }
}
