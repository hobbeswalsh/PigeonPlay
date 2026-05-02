# Play-time tracking in line suggester

**Date:** 2026-05-02
**Status:** Design approved, awaiting implementation plan

## Goal

Track real wall-clock time each player spends on the field, display it next to player names in the in-game line-building views, and use it as the primary fairness signal for the next-line suggester. Keep the existing points-played display for context.

## Non-goals

- No time aggregation in History or Roster views (separate phases).
- No "halt clock" / pause UI (use `dead` outcome + re-Lock In).
- No "abort in-progress point" UI (use `dead` outcome).
- No app-kill mid-point recovery beyond today's behavior.
- No third-party dependencies; Apple frameworks only.

## Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Continuous game clock that runs only during the `recordingPoint` phase. | Leverages existing Lock In / Record Point taps; no new gestures. |
| 2 | Suggester sort key becomes `(excluded, secondsBucket, pointsPlayed, lastPointOnBench)` with `secondsBucket = Int(secondsPlayed / 30)`. | Time is the primary fairness signal; 30-second bucketing prevents jitter where a 5s difference would flip the suggestion. Falls through to points then bench-time. |
| 3 | Source of truth: `startedAt: Date?` and `endedAt: Date?` on `GamePoint`. Per-player seconds is derived by summing on read. | Tiny dataset, no drift risk. Undo "just works" because removing a `GamePoint` removes its time. |
| 4 | Live `M:SS` clock chip on the RecordPoint screen, driven by `TimelineView(.periodic(...))`. | Coach gets visible feedback the timer is running. SwiftUI-native, no manual `Timer`. |
| 5 | Display next to player names: `M:SS \u{00B7} Npts` (time primary, points secondary, middot separator U+00B7). | Reflects that time is now the suggester's primary signal. |
| 6 | `UIApplication.shared.isIdleTimerDisabled = true` while phase is `recordingPoint`. | Sidesteps phone-sleep-during-point; one line, scoped, no accounting logic. |
| 7 | Scope: only the three line-building views (`LineBuilderView`, `LineSelectionView`, `NextLineQueueView`). | Matches existing `Npts` footprint. History/Roster aggregations are separate design conversations. |

## Data model

**`GamePoint`** (in `PigeonPlay/Models/Game.swift`) gains:

```swift
var startedAt: Date?
var endedAt: Date?
```

Both optional. Existing persisted points stay valid; their contribution to per-player seconds is zero. SwiftData lightweight migration handles this -- no migration code needed.

**No new property on `Game` or `Player`.** The in-progress timestamp lives in view state only.

## Algorithm

`PigeonPlay/Services/LineSuggester.swift`:

```swift
static func suggest(
    available: [Player],
    ratio: GenderRatio,
    secondsPlayed: [Player: TimeInterval],   // new
    pointsPlayed: [Player: Int],
    lastPointOnBench: [Player: Int],
    excluding: Set<Player> = []
) -> LineSuggestion
```

Sort key:

```swift
func sortKey(_ player: Player) -> (Int, Int, Int, Int) {
    let excluded = excludedIDs.contains(ObjectIdentifier(player)) ? 1 : 0
    let secondsBucket = Int((secondsPlayed[player] ?? 0) / 30)
    let played = pointsPlayed[player] ?? 0
    let bench = lastPointOnBench[player] ?? 0
    return (excluded, secondsBucket, played, bench)
}
```

`countingCurrentPoint(...)` is unchanged -- still used for the `pointsPlayed` parameter (display). The in-progress point's elapsed seconds are NOT folded into `secondsPlayed` for the next-line suggestion: the existing `excluding:` set keeps on-field players off the next line, which is the only behavior that matters at Lock In time.

A small formatter helper lives in `LineSuggester.swift` as a free function:

```swift
func formatPlayTime(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    return "\(total / 60):\(String(format: "%02d", total % 60))"
}
```

## UX & lifecycle

**`ActiveGameView`** (`PigeonPlay/Views/Game/ActiveGameView.swift`):

- New `@State private var pointStartedAt: Date?`.
- Set to `Date()` inside the Lock In closure (currently around line 115).
- Read into the new `GamePoint`'s `startedAt` inside `recordPoint(...)`, with `endedAt = Date()`. Clear `pointStartedAt` after.
- New computed property `secondsPlayed: [Player: TimeInterval]` mirroring the structure of `pointsPlayed`, summing `endedAt - startedAt` per `GamePoint` (skipping nil timestamps).
- Pass `secondsPlayed` to `LineSelectionView` and `NextLineQueueView`.
- Live clock chip on RecordPoint screen, only visible when `pointStartedAt != nil`:
  ```swift
  if let start = pointStartedAt {
      TimelineView(.periodic(from: start, by: 1)) { context in
          let elapsed = context.date.timeIntervalSince(start)
          Text(formatPlayTime(elapsed))
              .font(.title2.monospacedDigit())
      }
  }
  ```
- Idle timer toggle:
  ```swift
  .onChange(of: phase) { _, newPhase in
      UIApplication.shared.isIdleTimerDisabled = (newPhase == .recordingPoint)
  }
  .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
  ```

**`LineBuilderView`** (`PigeonPlay/Views/Game/LineBuilderView.swift`):

- New parameter `let secondsPlayed: [Player: TimeInterval]`.
- Replace `Text("\(pointsPlayed[entry.player] ?? 0)pts")` (lines 34, 62) with:
  ```swift
  Text("\(formatPlayTime(secondsPlayed[entry.player] ?? 0)) \u{00B7} \(pointsPlayed[entry.player] ?? 0)pts")
  ```

**`LineSelectionView`** and **`NextLineQueueView`**: accept and forward `secondsPlayed` to the suggester and to `LineBuilderView`.

**Undo:** No code change. `Game.undoLastPoint()` removes the `GamePoint`; its time is no longer summed.

**App-kill mid-point:** Accepted limitation. `pointStartedAt` is in-memory only, same as `selectedLine` today. Coach re-Locks In; the new point's start time is `Date()` at that moment.

## Files touched

| File | Change |
|------|--------|
| `PigeonPlay/Models/Game.swift` | Add `startedAt: Date?`, `endedAt: Date?` to `GamePoint`. |
| `PigeonPlay/Services/LineSuggester.swift` | New `secondsPlayed` parameter, updated sort key, `formatPlayTime` helper. |
| `PigeonPlay/Views/Game/ActiveGameView.swift` | `pointStartedAt` state, `secondsPlayed` computed property, idle-timer `.onChange`, live `TimelineView` chip, write timestamps in `recordPoint(...)`. |
| `PigeonPlay/Views/Game/LineBuilderView.swift` | Accept `secondsPlayed`; render `M:SS \u{00B7} Npts`. |
| `PigeonPlay/Views/Game/LineSelectionView.swift` | Accept and forward `secondsPlayed`. |
| `PigeonPlay/Views/Game/NextLineQueueView.swift` | Accept and render `secondsPlayed`. |
| `PigeonPlayTests/LineSuggesterTests.swift` | New cases for time-bucket sort, mixed nil-timestamp handling, formatter. |

## Testing

**Unit tests (`LineSuggesterTests`):**

- Two `Bx` players, identical points-played, secondsPlayed differing by 5s -> bucket equal -> falls through to bench-time tiebreaker (existing behavior).
- Two `Bx` players, identical points-played, secondsPlayed differing by 35s -> different buckets -> player with less time is chosen.
- Three players where points-played and bench-time disagree with secondsPlayed -> secondsPlayed wins (within bucket boundaries).
- `secondsPlayed` summing across `GamePoint`s with mixed nil/non-nil timestamps -> nil contributes zero, non-nil contributes `endedAt - startedAt`.
- Formatter: `0 -> "0:00"`, `9 -> "0:09"`, `65 -> "1:05"`, `605 -> "10:05"`, `3599 -> "59:59"`.

**Manual:** Live clock UI (TimelineView), idle-timer behavior on a real device, end-to-end "lock in -> wait -> record" cycle showing accumulated time in the next-line view.

## Migration

SwiftData lightweight migration. Both new properties are optional, so no code-level migration step is required. Existing games keep their point history intact with no recorded time.
