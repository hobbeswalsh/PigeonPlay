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
        lastPointOnBench: [Player: Int],
        excluding: Set<Player> = []
    ) -> LineSuggestion {
        let excludedIDs = Set(excluding.map { ObjectIdentifier($0) })

        func sortKey(_ player: Player) -> (Int, Int, Int) {
            let played = pointsPlayed[player] ?? 0
            // Lower lastPointOnBench = sat out longer = higher priority.
            // Missing means never sat out (or first point), treat as 0.
            let bench = lastPointOnBench[player] ?? 0
            // Excluded players sort last so non-excluded are preferred
            let excluded = excludedIDs.contains(ObjectIdentifier(player)) ? 1 : 0
            return (excluded, played, bench)
        }

        let bPool = available.filter { $0.effectiveMatching == .bx }
            .shuffled().sorted { sortKey($0) < sortKey($1) }

        let gPool = available.filter { $0.effectiveMatching == .gx }
            .shuffled().sorted { sortKey($0) < sortKey($1) }

        let bSide = Array(bPool.prefix(ratio.bSideCount)).map { player in
            LineSuggestion.Entry(player: player, matching: player.effectiveMatching)
        }

        let gSide = Array(gPool.prefix(ratio.gSideCount)).map { player in
            LineSuggestion.Entry(player: player, matching: player.effectiveMatching)
        }

        return LineSuggestion(bSide: bSide, gSide: gSide)
    }
}
