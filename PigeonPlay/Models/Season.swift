import Foundation
import SwiftData

/// One run of a team: a name, when it started, and when the coach closed
/// it. The open season is the one with no `endedAt`; closing it is what
/// "archive this season and start again" means, and the games stay in the
/// store so last year is still a tap away in History.
@Model
final class Season {
    var name: String = ""
    var startedAt: Date = Date.distantPast
    /// Nil while the season is the current one. Set once, when archived.
    var endedAt: Date?

    // Bare, as the other inverse ends are: Game.season is the declaring
    // side. Optional because CloudKit requires it of every relationship.
    var games: [Game]?

    var isCurrent: Bool { endedAt == nil }

    init(name: String, startedAt: Date = Date()) {
        self.name = name
        self.startedAt = startedAt
    }
}
