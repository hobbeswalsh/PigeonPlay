# Play-Time Tracking — Design

**Date:** 2026-05-02
**Branch:** `robin/play-time-tracking`
**Status:** Spec — awaiting plan

## Problem

`LineSuggester` currently sorts available players by points-played count and bench-recency. A player who was on the field for a 20-second point and a player who played a 5-minute point are treated identically (both `pointsPlayed = 1`). This is unfair: the short-point player should be picked again before the long-point player.

## Goal

Replace point-count-based fairness with wall-clock-time-based fairness. The next-line suggestion should prefer players who have spent the least real time on the field.

## Non-goals

- Game-clock reporting (period/quarter/halftime breakdowns)
- Per-player time targets ("kid X needs 12 minutes total")
- Live time displays during a point
- Backfilling timestamps onto v1.0 historical games
- Configurable algorithm tuning knobs

## Data model

`GamePoint` gains two optional `Date` fields:

```swift
var startedAt: Date?
var endedAt: Date?

var duration: TimeInterval? {
    guard let s = startedAt, let e = endedAt else { return nil }
    return e.timeIntervalSince(s)
}
```

Both optional. Lightweight SwiftData migration — no `VersionedSchema` ceremony, no `PlayerMigration`-equivalent step. Existing v1.0 `GamePoint` rows have `nil` for both, contributing 0 seconds to time totals while their `pointsPlayed` count remains accurate.

### Capture points

- `startedAt = .now` is set when the user locks in a line and the game transitions into the recording-point state (in `ActiveGameView`).
- `endedAt = .now` is set when the outcome is recorded (`RecordPointView` submission).
- Dead points count fully — they are real on-field time.

## Algorithm

`LineSuggester.suggest` signature changes:

```swift
static func suggest(
    available: [Player],
    ratio: GenderRatio,
    secondsPlayed: [Player: TimeInterval],
    secondsSinceLastPlay: [Player: TimeInterval],
    excluding: Set<Player> = []
) -> LineSuggestion
```

Sort key per player: `(excluded, secondsPlayed, -secondsSinceLastPlay)` ascending. Lower seconds-played wins; ties broken by who has been benched longer.

`countingCurrentPoint` is replaced by:

```swift
static func addingInProgressPoint(
    secondsPlayed: [Player: TimeInterval],
    onFieldPlayers: [Player],
    elapsed: TimeInterval
) -> [Player: TimeInterval]
```

Adds `elapsed` to each on-field player's seconds-played dict entry. Used by `NextLineQueueView` so that pre-staging the next line while a point is in progress reflects real on-field time.

## Caller-side helpers

Per-player time stats are computed by callers from `Game.points`. To keep them testable in isolation, two static methods land on `Game`:

```swift
extension Game {
    func secondsPlayed(asOf now: Date) -> [Player: TimeInterval]
    func secondsSinceLastPlay(asOf now: Date) -> [Player: TimeInterval]
}
```

- `secondsPlayed` sums each completed point's `duration` for every player who appeared in it. Points with `duration == nil` contribute 0.
- `secondsSinceLastPlay` returns `now - max(endedAt for points where player appeared)`. For a player who has never played in this game, returns `now - game.date`.
- Both are pure functions of `Game.points`, `Game.availablePlayers`, `Game.date`, and the supplied `now`.

The current in-progress point is folded in by `LineSuggester.addingInProgressPoint` after these helpers run, not by the helpers themselves.

## UI surfaces

A `TimeInterval.formattedShort` extension returns `M:SS` for durations under one hour, `H:MM:SS` otherwise. Defined once, used in all three places below.

### Line builder, check-in, next-line queue

Each player row gains a stat suffix in monospaced caption font, right-aligned:

```
Sarah G          · 3 pts · 4:23
Tom B            · 2 pts · 2:51
```

Shown for every available player. `NextLineQueueView` includes the in-progress point's elapsed time in the displayed totals so the screen matches what the suggester used.

### History (`GameDetailView`)

Per-player summary table beneath the existing point log, sorted by player name:

```
Player        Pts    Time
Sarah         3      4:23
Tom           2      2:51
...
Total         5      7:14
```

Includes any player on `availablePlayers` for that game (zero-row players show `0 / 0:00`). Only points with non-nil `duration` contribute to the time column; the in-progress point is excluded (it lands once recorded).

## Edge cases

- **Legacy v1.0 games** — `duration == nil` everywhere. Time columns show `0:00`; point counts unchanged. No backfill.
- **In-progress point on app reopen** — `startedAt` set, `endedAt` nil. When the outcome is recorded normally, `endedAt = .now` lands. Stale active games from a previous session may show inflated elapsed time; the coach can undo the point if needed.
- **Dead points** — count fully toward time played.
- **Player never played** — `secondsPlayed = 0`, `secondsSinceLastPlay = now - game.date`. Sorts to the front, which is the desired behavior.
- **Device sleep mid-point** — `Date.now` advances regardless; matches reality (the kid was on the field while the phone slept).
- **Undo last point** — `Game.undoLastPoint()` already removes the trailing `GamePoint`; its timestamps go with it. Totals recompute correctly with no further changes.
- **Player removed from availability mid-game** — accumulated time stays attached to the points they appeared in. They stop appearing in suggestions.

## Tests

### `LineSuggesterTests` (new and rewritten)

- **Motivating case:** player A on field for one 20s point, player B on field for one 5min point. Both have `pointsPlayed = 1` under the old algorithm. Assert A is preferred for the next line under the new algorithm.
- **Tiebreaker:** equal `secondsPlayed`, different `secondsSinceLastPlay` — longer-benched wins.
- **`addingInProgressPoint`:** elapsed is added only to on-field players; benched players' totals are untouched.
- **Existing tests** rewritten in time units. Where they previously used `pointsPlayed: [p: 2]`, they now use `secondsPlayed: [p: 120]` (or whatever multiplier preserves the test's intent). Semantics preserved.

### `GameTests` (new)

- `GamePoint.duration` returns nil when either timestamp is missing.
- `GamePoint.duration` returns the correct interval when both are set.
- `Game.secondsPlayed` accumulates correctly across multiple points, including a player who appears in some but not others.
- `Game.secondsPlayed` treats `nil`-duration points as 0 contribution.
- `Game.secondsSinceLastPlay` returns `now - lastEndedAt` for players who have played, and `now - game.date` for players who have not.

## Out of scope (explicit)

- No telemetry / analytics on play time
- No coach-facing "fairness score" or variance metric
- No cross-game time aggregation (per-season totals)
- No alerts or warnings for unbalanced time

These are reasonable v2 follow-ups but not part of this milestone.
