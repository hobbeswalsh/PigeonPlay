# High-Priority Refactors Design

**Date:** 2026-03-17
**Branch:** robin/high-prio-refactors

## Summary

Four high-priority concerns from the codebase audit, executed in dependency order.

## 1. Player.effectiveMatching — Single Source of Truth

**Problem:** Gender-matching fallback `?? .bx` is scattered across `LineSelectionView`, `NextLineQueueView`, and `LineSuggester` pool filters. An `.x` player with `nil` defaultMatching is silently excluded from LineSuggester pools but included when manually added — inconsistent behavior.

**Fix:** Add computed property to `Player`:

```swift
var effectiveMatching: GenderMatching {
    switch gender {
    case .b: .bx
    case .g: .gx
    case .x: defaultMatching ?? .bx
    }
}
```

Replace all scattered matching logic with `player.effectiveMatching`. In LineSuggester, pool filters become `p.effectiveMatching == .bx` / `.gx`.

**Files changed:** `Player.swift`, `LineSuggester.swift`, `LineSelectionView.swift`, `NextLineQueueView.swift`

## 2. LineBuilderView — Extract Shared Lineup UI

**Problem:** `LineSelectionView` (120 lines) and `NextLineQueueView` (130 lines) duplicate on-field rows, bench rows, add/remove/toggle logic.

**Fix:** Extract `LineBuilderView` taking:
- `Binding<[LineSuggestion.Entry]>` — the line being built
- `[Player]` — available players
- `[Player: Int]` — pointsPlayed
- `String` — header label ("On Field" / "Next Up")

Both views become thin wrappers adding their specific chrome (ratio picker, shuffle button, etc.). Use `persistentModelID` keying in both (fix LineSelectionView's fragile index-based keying).

**Files changed:** New `LineBuilderView.swift`, simplified `LineSelectionView.swift`, simplified `NextLineQueueView.swift`

## 3. Extract Embedded Views from GameView.swift

**Problem:** GameView.swift is 368 lines containing 4 structs. Hard to navigate and test.

**Fix:** Move to separate files:
- `NewGameFlow.swift` (struct NewGameFlow)
- `ActiveGameView.swift` (struct ActiveGameView + GamePhase enum)
- `AvailabilityView.swift` (struct AvailabilityView)

`GameView.swift` retains only the container (~61 lines).

**Files changed:** New `NewGameFlow.swift`, `ActiveGameView.swift`, `AvailabilityView.swift`. Simplified `GameView.swift`.

## 4. GamePoint Init Validation

**Problem:** `GamePoint` allows `outcome: .us` with `scorer: nil`. Model doesn't enforce its own invariants.

**Fix:** Add precondition to `GamePoint.init`:

```swift
init(...) {
    if outcome == .us {
        precondition(scorer != nil, "Points scored by us must have a scorer")
    }
    // ...
}
```

**Files changed:** `Game.swift`

## Execution Order

1 → 2 → 3 → 4 (1 must be first; 2 before 3 since extraction moves simplified code; 4 is independent)

## Baseline

- 19/20 tests passing (1 flaky: `excludesCurrentLine` — shuffle-dependent, pre-existing)
- Worktree: `.worktrees/robin/high-prio-refactors`
