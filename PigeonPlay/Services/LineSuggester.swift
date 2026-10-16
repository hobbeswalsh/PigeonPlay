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
    /// Returns a copy of `pointsPlayed` with +1 for each player currently on the field,
    /// accounting for the in-progress point that hasn't been recorded yet.
    static func countingCurrentPoint(
        pointsPlayed: [Player: Int],
        onFieldPlayers: [Player]
    ) -> [Player: Int] {
        var adjusted = pointsPlayed
        for player in onFieldPlayers {
            adjusted[player, default: 0] += 1
        }
        return adjusted
    }

    static func suggest(
        available: [Player],
        ratio: GenderRatio,
        lineSize: Int,
        pointsPlayed: [Player: Int],
        lastPointOnBench: [Player: Int],
        excluding: Set<Player> = []
    ) -> LineSuggestion {
        let composition = ratio.composition(lineSize: lineSize)
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

        let bPicked = Array(bPool.prefix(composition.bCount))
        let gPicked = Array(gPool.prefix(composition.gCount))

        // A short side must not leave the line short: a team with only
        // boys left still has to field a full line. The empty slots go to
        // whoever is next in line on either side, e.g. 5 boys and 1 girl at
        // 2B/3G plays 4B/1G.
        let openSlots = lineSize - bPicked.count - gPicked.count
        let fill = (bPool.dropFirst(composition.bCount) + gPool.dropFirst(composition.gCount))
            .sorted { sortKey($0) < sortKey($1) }
            .prefix(openSlots)

        func entries(_ players: [Player]) -> [LineSuggestion.Entry] {
            players.map { LineSuggestion.Entry(player: $0, matching: $0.effectiveMatching) }
        }

        return LineSuggestion(
            bSide: entries(bPicked + fill.filter { $0.effectiveMatching == .bx }),
            gSide: entries(gPicked + fill.filter { $0.effectiveMatching == .gx })
        )
    }
}
