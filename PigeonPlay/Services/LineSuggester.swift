import Foundation

struct LineSuggestion {
    struct Entry {
        let player: Player
        let matching: GenderMatching
    }

    let bSide: [Entry]
    let gSide: [Entry]

    var allEntries: [Entry] { bSide + gSide }
}

enum LineSuggester {
    static func suggest(
        available: [Player],
        ratio: GenderRatio,
        pointsPlayed: [Player: Int],
        lastPointOnBench: [Player: Int]
    ) -> LineSuggestion {
        func sortKey(_ player: Player) -> (Int, Int) {
            let played = pointsPlayed[player] ?? 0
            // Lower lastPointOnBench = sat out longer = higher priority.
            // Missing means never sat out (or first point), treat as 0.
            let bench = lastPointOnBench[player] ?? 0
            return (played, bench)
        }

        let bPool = available.filter { p in
            p.gender == .b || (p.gender == .x && p.defaultMatching == .bx)
        }.sorted { sortKey($0) < sortKey($1) }

        let gPool = available.filter { p in
            p.gender == .g || (p.gender == .x && p.defaultMatching == .gx)
        }.sorted { sortKey($0) < sortKey($1) }

        let bSide = Array(bPool.prefix(ratio.bSideCount)).map { player in
            LineSuggestion.Entry(
                player: player,
                matching: .bx
            )
        }

        let gSide = Array(gPool.prefix(ratio.gSideCount)).map { player in
            LineSuggestion.Entry(
                player: player,
                matching: .gx
            )
        }

        return LineSuggestion(bSide: bSide, gSide: gSide)
    }
}
