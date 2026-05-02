# Play-Time Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track wall-clock time each player spends on the field, display it next to player names, and use it as the primary fairness signal in the next-line suggester.

**Architecture:** `GamePoint` gains optional `startedAt`/`endedAt` Date fields. Per-player seconds is computed by summing `endedAt - startedAt` across all `GamePoint`s a player appeared in. The suggester sort key becomes `(excluded, secondsBucket, pointsPlayed, lastPointOnBench)` with 30-second buckets to avoid jitter. A live `M:SS` chip on the RecordPoint screen is driven by `TimelineView(.periodic(...))`. `UIApplication.isIdleTimerDisabled` is toggled while a point is in progress.

**Tech Stack:** Swift 6.0, SwiftUI, SwiftData, Swift Testing (`@Test` macro), iOS 18.0+.

**Worktree:** All work happens in `.worktrees/robin/play-time-tracking` on branch `robin/play-time-tracking`. Run tests in Xcode via Cmd-U; do not loop on `xcodebuild`.

**Source spec:** `docs/superpowers/specs/2026-05-02-play-time-tracking-design.md`

---

## File Structure

| File | Change |
|------|--------|
| `PigeonPlay/Models/Game.swift` | Add `startedAt: Date?`, `endedAt: Date?` to `GamePoint`. |
| `PigeonPlay/Services/LineSuggester.swift` | New `secondsPlayed` parameter (default `[:]`), updated sort key, free `formatPlayTime` helper. |
| `PigeonPlay/Views/Game/LineBuilderView.swift` | Accept `secondsPlayed`; render `M:SS \u{00B7} Npts`. |
| `PigeonPlay/Views/Game/LineSelectionView.swift` | Accept and forward `secondsPlayed`. |
| `PigeonPlay/Views/Game/NextLineQueueView.swift` | Accept and forward `secondsPlayed`. |
| `PigeonPlay/Views/Game/ActiveGameView.swift` | `secondsPlayed` computed map; `pointStartedAt` state; write timestamps in `recordPoint`; live `TimelineView` chip; idle-timer toggle. |
| `PigeonPlayTests/LineSuggesterTests.swift` | New cases for time-bucket sort and formatter. |

---

## Task 1: Add timestamps to GamePoint

**Files:**
- Modify: `PigeonPlay/Models/Game.swift`
- Modify: `PigeonPlayTests/GameTests.swift` (or create one focused test inline)

- [ ] **Step 1: Write the failing test**

Add to `PigeonPlayTests/GameTests.swift`:

```swift
@Test func gamePointStoresStartAndEndTimestamps() {
    let start = Date(timeIntervalSince1970: 1_000)
    let end = Date(timeIntervalSince1970: 1_090)
    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .dead,
        onFieldPlayers: [],
        startedAt: start,
        endedAt: end
    )
    #expect(point.startedAt == start)
    #expect(point.endedAt == end)
    #expect(point.endedAt!.timeIntervalSince(point.startedAt!) == 90)
}

@Test func gamePointTimestampsDefaultToNil() {
    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .dead
    )
    #expect(point.startedAt == nil)
    #expect(point.endedAt == nil)
}
```

- [ ] **Step 2: Run tests in Xcode (Cmd-U)**

Expected: FAIL — `GamePoint` initializer does not accept `startedAt` / `endedAt`.

- [ ] **Step 3: Add the properties and initializer params**

In `PigeonPlay/Models/Game.swift`, modify the `GamePoint` class. Final state of the class:

```swift
@Model
final class GamePoint {
    var number: Int
    var ratio: GenderRatio
    var outcome: PointOutcome
    var onFieldPlayers: [PointPlayer]
    var scorer: Player?
    var assist: Player?
    var startedAt: Date?
    var endedAt: Date?

    init(
        number: Int,
        ratio: GenderRatio,
        outcome: PointOutcome,
        onFieldPlayers: [PointPlayer] = [],
        scorer: Player? = nil,
        assist: Player? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        precondition(outcome != .us || scorer != nil, "Points scored by us must have a scorer")
        precondition(outcome != .dead || scorer == nil, "Dead points must not have a scorer")
        self.number = number
        self.ratio = ratio
        self.outcome = outcome
        self.onFieldPlayers = onFieldPlayers
        self.scorer = scorer
        self.assist = assist
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
```

- [ ] **Step 4: Run tests in Xcode (Cmd-U)**

Expected: PASS for both new tests; existing `GameTests` and `LineSuggesterTests` still pass (existing call sites omit the new params, defaults kick in).

- [ ] **Step 5: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add \
    PigeonPlay/Models/Game.swift \
    PigeonPlayTests/GameTests.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat(model): add startedAt/endedAt to GamePoint"
```

---

## Task 2: Add formatPlayTime helper

**Files:**
- Modify: `PigeonPlay/Services/LineSuggester.swift`
- Modify: `PigeonPlayTests/LineSuggesterTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `PigeonPlayTests/LineSuggesterTests.swift`:

```swift
@Test func formatPlayTimeProducesMmSs() {
    #expect(formatPlayTime(0) == "0:00")
    #expect(formatPlayTime(9) == "0:09")
    #expect(formatPlayTime(60) == "1:00")
    #expect(formatPlayTime(65) == "1:05")
    #expect(formatPlayTime(605) == "10:05")
    #expect(formatPlayTime(3599) == "59:59")
}
```

- [ ] **Step 2: Run tests in Xcode (Cmd-U)**

Expected: FAIL — `formatPlayTime` is not defined.

- [ ] **Step 3: Add the helper**

In `PigeonPlay/Services/LineSuggester.swift`, append below the `LineSuggester` enum:

```swift
func formatPlayTime(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    return "\(total / 60):\(String(format: "%02d", total % 60))"
}
```

- [ ] **Step 4: Run tests in Xcode (Cmd-U)**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add \
    PigeonPlay/Services/LineSuggester.swift \
    PigeonPlayTests/LineSuggesterTests.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat: add formatPlayTime helper"
```

---

## Task 3: Bucketed time in LineSuggester sort key

**Files:**
- Modify: `PigeonPlay/Services/LineSuggester.swift`
- Modify: `PigeonPlayTests/LineSuggesterTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `PigeonPlayTests/LineSuggesterTests.swift`:

```swift
@Test func timeWithinBucketFallsThroughToPointsPlayed() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let b3 = Player(name: "B3", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)

    let available = [b1, b2, b3, g1, g2, g3]
    // b1 and b2 both fall in bucket 0 (< 30s). b1 has more points.
    let secondsPlayed: [Player: TimeInterval] = [b1: 25, b2: 5, b3: 0]
    let pointsPlayed: [Player: Int] = [b1: 3, b2: 1, b3: 0]

    for _ in 0..<20 {
        let suggestion = LineSuggester.suggest(
            available: available,
            ratio: .twoBThreeG,
            pointsPlayed: pointsPlayed,
            secondsPlayed: secondsPlayed,
            lastPointOnBench: [:]
        )
        let bPicked = suggestion.bSide.map(\.player)
        // b3 (0pts) and b2 (1pt) should be picked over b1 (3pts), since all
        // three fall in the same secondsBucket.
        #expect(!bPicked.contains(where: { $0 === b1 }))
    }
}

@Test func differentBucketsMakeTimeWin() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let b3 = Player(name: "B3", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)

    let available = [b1, b2, b3, g1, g2, g3]
    // b1 has 35s (bucket 1), b2 has 25s (bucket 0), b3 has 0s (bucket 0).
    // Even though b1 has FEWER points, its higher time bucket should
    // disqualify it from selection over b2/b3.
    let secondsPlayed: [Player: TimeInterval] = [b1: 35, b2: 25, b3: 0]
    let pointsPlayed: [Player: Int] = [b1: 0, b2: 5, b3: 5]

    for _ in 0..<20 {
        let suggestion = LineSuggester.suggest(
            available: available,
            ratio: .twoBThreeG,
            pointsPlayed: pointsPlayed,
            secondsPlayed: secondsPlayed,
            lastPointOnBench: [:]
        )
        let bPicked = suggestion.bSide.map(\.player)
        #expect(!bPicked.contains(where: { $0 === b1 }))
    }
}

@Test func suggesterDefaultsToEmptySecondsPlayed() {
    // Existing behavior preserved when no secondsPlayed is supplied.
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)

    let suggestion = LineSuggester.suggest(
        available: [b1, b2, g1, g2, g3],
        ratio: .twoBThreeG,
        pointsPlayed: [:],
        lastPointOnBench: [:]
    )
    #expect(suggestion.bSide.count == 2)
    #expect(suggestion.gSide.count == 3)
}
```

- [ ] **Step 2: Run tests in Xcode (Cmd-U)**

Expected: FAIL on the first two new tests (no `secondsPlayed` parameter); third test compiles but the bucket logic doesn't exist yet so it'll either pass trivially or also fail at the call site.

- [ ] **Step 3: Add the parameter and update the sort key**

In `PigeonPlay/Services/LineSuggester.swift`, replace the `suggest` function with:

```swift
static func suggest(
    available: [Player],
    ratio: GenderRatio,
    pointsPlayed: [Player: Int],
    secondsPlayed: [Player: TimeInterval] = [:],
    lastPointOnBench: [Player: Int],
    excluding: Set<Player> = []
) -> LineSuggestion {
    let excludedIDs = Set(excluding.map { ObjectIdentifier($0) })

    func sortKey(_ player: Player) -> (Int, Int, Int, Int) {
        let excluded = excludedIDs.contains(ObjectIdentifier(player)) ? 1 : 0
        let secondsBucket = Int((secondsPlayed[player] ?? 0) / 30)
        let played = pointsPlayed[player] ?? 0
        // Lower lastPointOnBench = sat out longer = higher priority.
        // Missing means never sat out (or first point), treat as 0.
        let bench = lastPointOnBench[player] ?? 0
        return (excluded, secondsBucket, played, bench)
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
```

The default `secondsPlayed: [Player: TimeInterval] = [:]` keeps every existing call site building unchanged.

- [ ] **Step 4: Run tests in Xcode (Cmd-U)**

Expected: PASS for new tests AND for all existing `LineSuggesterTests` (existing tests omit `secondsPlayed`, default empty map → every player in bucket 0 → falls through to `pointsPlayed`/bench-time exactly as before).

- [ ] **Step 5: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add \
    PigeonPlay/Services/LineSuggester.swift \
    PigeonPlayTests/LineSuggesterTests.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat: bucketed secondsPlayed in LineSuggester sort key"
```

---

## Task 4: LineBuilderView accepts secondsPlayed and renders M:SS · Npts

**Files:**
- Modify: `PigeonPlay/Views/Game/LineBuilderView.swift`

No unit test for SwiftUI view rendering; verify visually after Task 7 wires data through.

Current `LineBuilderView` properties (lines 4-7):

```swift
let available: [Player]
let pointsPlayed: [Player: Int]
let header: String
@Binding var entries: [LineSuggestion.Entry]
```

- [ ] **Step 1: Add the parameter and update the trailing labels**

Insert `secondsPlayed` immediately after `pointsPlayed`:

```swift
let available: [Player]
let pointsPlayed: [Player: Int]
let secondsPlayed: [Player: TimeInterval]
let header: String
@Binding var entries: [LineSuggestion.Entry]
```

Replace `Text("\(pointsPlayed[entry.player] ?? 0)pts")` (currently line 34) with:

```swift
Text("\(formatPlayTime(secondsPlayed[entry.player] ?? 0)) \u{00B7} \(pointsPlayed[entry.player] ?? 0)pts")
```

Replace `Text("\(pointsPlayed[player] ?? 0)pts")` (currently line 62) with:

```swift
Text("\(formatPlayTime(secondsPlayed[player] ?? 0)) \u{00B7} \(pointsPlayed[player] ?? 0)pts")
```

The middot is the literal Unicode escape `\u{00B7}` inside the Swift string.

- [ ] **Step 2: Build (Cmd-B)**

Expected: BUILD FAILS at the call sites in `LineSelectionView` and `NextLineQueueView` because `LineBuilderView`'s init now requires `secondsPlayed`. Tasks 5 and 6 fix those.

- [ ] **Step 3: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add PigeonPlay/Views/Game/LineBuilderView.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat(ui): render time and points beside player names"
```

(Yes, this commit leaves the build broken. The next two tasks restore it. If you prefer green commits, do tasks 4-6 in one commit instead.)

---

## Task 5: LineSelectionView forwards secondsPlayed

**Files:**
- Modify: `PigeonPlay/Views/Game/LineSelectionView.swift`

- [ ] **Step 1: Add parameter and forward it**

In `PigeonPlay/Views/Game/LineSelectionView.swift`, insert `secondsPlayed` right after `pointsPlayed` (around line 6). Final property block:

```swift
let available: [Player]
let ratio: GenderRatio
let pointsPlayed: [Player: Int]
let secondsPlayed: [Player: TimeInterval]
let lastPointOnBench: [Player: Int]
@Binding var selectedLine: [LineSuggestion.Entry]
```

Update the `LineBuilderView(...)` call (currently lines 16-21) to pass it through:

```swift
LineBuilderView(
    available: available,
    pointsPlayed: pointsPlayed,
    secondsPlayed: secondsPlayed,
    header: "On Field",
    entries: $selectedLine
)
```

Update the `LineSuggester.suggest(...)` call inside `autoSuggest()` (currently lines 29-34):

```swift
let suggestion = LineSuggester.suggest(
    available: available,
    ratio: ratio,
    pointsPlayed: pointsPlayed,
    secondsPlayed: secondsPlayed,
    lastPointOnBench: lastPointOnBench
)
```

- [ ] **Step 2: Build (Cmd-B)**

Expected: still fails at `ActiveGameView` and `NextLineQueueView` call sites. That's fine.

- [ ] **Step 3: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add PigeonPlay/Views/Game/LineSelectionView.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat(ui): thread secondsPlayed through LineSelectionView"
```

---

## Task 6: NextLineQueueView forwards secondsPlayed

**Files:**
- Modify: `PigeonPlay/Views/Game/NextLineQueueView.swift`

- [ ] **Step 1: Add parameter and forward it**

In `PigeonPlay/Views/Game/NextLineQueueView.swift`, insert `secondsPlayed` right after `pointsPlayed` (around line 5). Final property block:

```swift
let available: [Player]
let pointsPlayed: [Player: Int]
let secondsPlayed: [Player: TimeInterval]
let lastPointOnBench: [Player: Int]
@Binding var queuedLine: [LineSuggestion.Entry]
@Binding var queuedRatio: GenderRatio
```

Update the `LineBuilderView(...)` call (currently lines 23-28):

```swift
LineBuilderView(
    available: available,
    pointsPlayed: pointsPlayed,
    secondsPlayed: secondsPlayed,
    header: "Next Up",
    entries: $queuedLine
)
```

Update the `LineSuggester.suggest(...)` call inside `resuggest()` (currently lines 41-46):

```swift
let suggestion = LineSuggester.suggest(
    available: available,
    ratio: queuedRatio,
    pointsPlayed: pointsPlayed,
    secondsPlayed: secondsPlayed,
    lastPointOnBench: lastPointOnBench
)
```

(No `excluding:` parameter is used at this call site — leave the existing semantics alone.)

- [ ] **Step 2: Build (Cmd-B)**

Expected: still fails at `ActiveGameView` call sites for `LineSelectionView` and `NextLineQueueView`. Task 7 fixes those.

- [ ] **Step 3: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add PigeonPlay/Views/Game/NextLineQueueView.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat(ui): thread secondsPlayed through NextLineQueueView"
```

---

## Task 7: ActiveGameView computes secondsPlayed and threads it through

**Files:**
- Modify: `PigeonPlay/Views/Game/ActiveGameView.swift`

This task only adds a derived map and passes it to subviews and the suggester. It does NOT yet capture timestamps — that's Task 8.

- [ ] **Step 1: Add the secondsPlayed computed property**

In `ActiveGameView`, add right after the existing `pointsPlayed` computed property (around line 33):

```swift
private var secondsPlayed: [Player: TimeInterval] {
    var totals: [Player: TimeInterval] = [:]
    for player in game.availablePlayers {
        totals[player] = 0
    }
    for point in game.points {
        guard let start = point.startedAt, let end = point.endedAt else { continue }
        let duration = end.timeIntervalSince(start)
        for pp in point.onFieldPlayers {
            totals[pp.player, default: 0] += duration
        }
    }
    return totals
}
```

- [ ] **Step 2: Pass secondsPlayed to LineSelectionView, NextLineQueueView, and both LineSuggester.suggest calls**

In `LineSelectionView(...)` (around line 100). Argument order matches the property declaration order from Task 5 (`pointsPlayed` then `secondsPlayed`):

```swift
LineSelectionView(
    available: game.availablePlayers,
    ratio: currentRatio,
    pointsPlayed: pointsPlayed,
    secondsPlayed: secondsPlayed,
    lastPointOnBench: lastPointOnBench,
    selectedLine: $selectedLine
)
```

In `NextLineQueueView(...)` (around line 163). Argument order matches Task 6 (`pointsPlayed` then `secondsPlayed`):

```swift
NextLineQueueView(
    available: game.availablePlayers,
    pointsPlayed: pointsPlayedIncludingCurrentPoint,
    secondsPlayed: secondsPlayed,
    lastPointOnBench: lastPointOnBench,
    queuedLine: $queuedLine,
    queuedRatio: $queuedRatio
)
```

In the Lock In closure's `LineSuggester.suggest(...)` (around line 118):

```swift
let suggestion = LineSuggester.suggest(
    available: game.availablePlayers,
    ratio: queuedRatio,
    pointsPlayed: pointsPlayedIncludingCurrentPoint,
    secondsPlayed: secondsPlayed,
    lastPointOnBench: lastPointOnBench,
    excluding: Set(selectedLine.map(\.player))
)
```

In `suggestLine()` (around line 213):

```swift
let suggestion = LineSuggester.suggest(
    available: game.availablePlayers,
    ratio: currentRatio,
    pointsPlayed: pointsPlayed,
    secondsPlayed: secondsPlayed,
    lastPointOnBench: lastPointOnBench
)
```

- [ ] **Step 3: Build (Cmd-B)**

Expected: BUILD SUCCEEDS. Run all tests in Xcode (Cmd-U) — all should pass. The app now builds and runs, but no time is yet being captured (`startedAt`/`endedAt` are still nil for new points), so labels render as `0:00 \u{00B7} Npts`.

- [ ] **Step 4: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add PigeonPlay/Views/Game/ActiveGameView.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat(ui): wire secondsPlayed through ActiveGameView"
```

---

## Task 8: Capture point start/end timestamps

**Files:**
- Modify: `PigeonPlay/Views/Game/ActiveGameView.swift`

- [ ] **Step 1: Add pointStartedAt state**

Add to the `@State` block at the top of `ActiveGameView` (around line 20):

```swift
@State private var pointStartedAt: Date?
```

- [ ] **Step 2: Set the timestamp when Lock In is tapped**

In the Lock In button closure (currently at line 115), set `pointStartedAt = Date()` as the FIRST line:

```swift
Button("Lock In") {
    pointStartedAt = Date()
    phase = .recordingPoint
    queuedRatio = currentRatio.alternated
    let suggestion = LineSuggester.suggest(
        available: game.availablePlayers,
        ratio: queuedRatio,
        pointsPlayed: pointsPlayedIncludingCurrentPoint,
        secondsPlayed: secondsPlayed,
        lastPointOnBench: lastPointOnBench,
        excluding: Set(selectedLine.map(\.player))
    )
    queuedLine = suggestion.allEntries
}
```

- [ ] **Step 3: Write timestamps when recording the point**

Replace the body of `recordPoint(...)` (currently around lines 231-254) with:

```swift
private func recordPoint(outcome: PointOutcome, scorer: Player?, assist: Player?) {
    let pointPlayers = selectedLine.map { entry in
        PointPlayer(player: entry.player, effectiveGender: entry.matching)
    }
    let point = GamePoint(
        number: game.points.count + 1,
        ratio: currentRatio,
        outcome: outcome,
        onFieldPlayers: pointPlayers,
        scorer: scorer,
        assist: assist,
        startedAt: pointStartedAt,
        endedAt: Date()
    )
    game.points.append(point)
    pointStartedAt = nil

    if queuedLine.isEmpty {
        currentRatio = currentRatio.alternated
        selectedLine = []
    } else {
        currentRatio = queuedRatio
        selectedLine = queuedLine
        queuedLine = []
    }
    phase = .selectingLine
}
```

- [ ] **Step 4: Clear pointStartedAt on undo**

In `undoPoint()` (around line 222), add `pointStartedAt = nil` alongside the other state clears:

```swift
private func undoPoint() {
    if let undone = game.undoLastPoint() {
        currentRatio = undone.ratio
        selectedLine = []
        queuedLine = []
        pointStartedAt = nil
        phase = .selectingLine
    }
}
```

- [ ] **Step 5: Build and run on a simulator**

Build (Cmd-B), then run (Cmd-R). Manual verification:
1. Start a new game with at least 5 available players.
2. Tap Lock In.
3. Wait ~5 seconds.
4. Tap a Dead point outcome.
5. Tap Lock In on the next line.
6. Inspect the line-building view — the 5 players from the previous point should now show ~`0:05 \u{00B7} 1pts`, the others `0:00 \u{00B7} 0pts`.
7. Run tests (Cmd-U) — all should still pass.

- [ ] **Step 6: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add PigeonPlay/Views/Game/ActiveGameView.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat: capture point start/end timestamps"
```

---

## Task 9: Live mm:ss clock chip on RecordPoint screen

**Files:**
- Modify: `PigeonPlay/Views/Game/ActiveGameView.swift`

- [ ] **Step 1: Add the TimelineView chip**

In the `case .recordingPoint:` branch (around line 135), wrap or precede the existing `ScrollView` with a clock display. Final structure:

```swift
case .recordingPoint:
    if let start = pointStartedAt {
        TimelineView(.periodic(from: start, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            Text(formatPlayTime(elapsed))
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    ScrollView {
        RecordPointView(onFieldPlayers: selectedLine) { outcome, scorer, assist in
            recordPoint(outcome: outcome, scorer: scorer, assist: assist)
        }
    }
    // ... existing .safeAreaInset stays unchanged ...
```

- [ ] **Step 2: Build and run on a simulator**

Manual verification:
1. Start a new game and tap Lock In.
2. Verify the mm:ss chip appears at the top of the RecordPoint screen and ticks once per second (`0:00`, `0:01`, `0:02`, ...).
3. Tap any outcome — the chip disappears (back to `selectingLine` phase, `pointStartedAt` is nil).

- [ ] **Step 3: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add PigeonPlay/Views/Game/ActiveGameView.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat(ui): live mm:ss clock during recordingPoint"
```

---

## Task 10: Disable idle timer during recordingPoint

**Files:**
- Modify: `PigeonPlay/Views/Game/ActiveGameView.swift`

- [ ] **Step 1: Add the .onChange and .onDisappear modifiers**

Attach to the outer `VStack` of `ActiveGameView.body` (alongside the existing `.toolbar`, `.alert`, `.sheet` modifiers, around line 195):

```swift
.onChange(of: phase) { _, newPhase in
    UIApplication.shared.isIdleTimerDisabled = (newPhase == .recordingPoint)
}
.onDisappear {
    UIApplication.shared.isIdleTimerDisabled = false
}
```

If `import UIKit` is not already at the top of the file, add it alongside `import SwiftUI`.

- [ ] **Step 2: Build and run on a real device (preferred) or simulator**

Manual verification on a real device (the simulator does not honor isIdleTimerDisabled meaningfully):
1. Set device auto-lock to a short interval (Settings > Display & Brightness > Auto-Lock > 30 seconds).
2. Start a game, tap Lock In, then leave the device idle.
3. Verify the screen stays awake throughout the point (does not lock at 30s).
4. Tap an outcome to record the point.
5. Wait — the device should resume normal auto-lock behavior and lock after 30s.

- [ ] **Step 3: Commit**

```bash
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking add PigeonPlay/Views/Game/ActiveGameView.swift
git -C /Users/robin/workspace/roster-manager/.worktrees/robin/play-time-tracking commit -m "feat: disable idle timer during recordingPoint"
```

---

## Task 11: End-to-end verification on existing data

**Files:** None modified.

- [ ] **Step 1: Verify SwiftData lightweight migration handles existing games**

Manual verification:
1. If the app already holds any games on the simulator/device from prior versions, build and run from this branch without erasing the simulator.
2. Open History — past games should still load and display normally.
3. Open Roster — players should still appear with no data loss.
4. The intentional consequence: past `GamePoint`s have `startedAt == nil` and `endedAt == nil`, so they contribute 0 to per-player time totals when those games are revisited mid-game (they are not active games, so this is invisible to the user).

If the app crashes on launch or the schema fails to load, the lightweight migration assumption is wrong; you'll need to add an explicit `VersionedSchema` and `MigrationStage` before this lands. That investigation is out of scope for this plan — stop and discuss.

- [ ] **Step 2: Verify the full happy path**

Run a fresh game on a simulator:
1. Add 7+ available players.
2. Lock in line 1 → wait 10s → record (any outcome).
3. Lock in line 2 → wait 60s → record.
4. Lock in line 3 → wait 5s → record.
5. Open the line-building view for line 4. Confirm:
   - Players who were on field for line 2 (long point) show ~`1:00 \u{00B7} 1pts`.
   - Players who were on field for line 1 or 3 (short points) show `0:05` to `0:10` and `1pts`.
   - The suggester picks players with the lowest secondsBucket, falling back to fewest pts within a bucket.

- [ ] **Step 3: No commit needed**

This is the final verification gate.

---

## Self-review notes

- **Spec coverage:** every decision in the spec maps to a task. Data model = Task 1. Formatter = Task 2. Suggester algorithm = Task 3. Display = Tasks 4-6. Computed seconds + threading = Task 7. Timestamp capture = Task 8. Live clock = Task 9. Idle timer = Task 10. Migration verification = Task 11.
- **No placeholders:** every step has concrete code or a concrete command.
- **Type/name consistency:** `secondsPlayed: [Player: TimeInterval]`, `pointStartedAt: Date?`, `formatPlayTime(_ seconds: TimeInterval) -> String` are used identically everywhere they appear.
- **Existing tests:** because `secondsPlayed` is a defaulted parameter on `LineSuggester.suggest`, no existing tests need to be edited.
- **Build-broken commits:** Tasks 4, 5 leave the build broken until Task 6 (or 7 if you skip the per-view granularity). The plan flags this. If a green-build-per-commit policy applies, fold Tasks 4-7 into one combined commit.
