# Codebase Concerns

**Analysis Date:** 2026-03-17

## Tech Debt

**GameView complexity:**
- Issue: `GameView.swift` is 368 lines with multiple nested states and phases. Contains both container view logic and two separate embedded views (`NewGameFlow`, `ActiveGameView`, `AvailabilityView`), making it difficult to test and modify individual features.
- Files: `PigeonPlay/Views/Game/GameView.swift`
- Impact: Changes to game creation flow, active game display, or availability management are tightly coupled and risk breaking other features. Difficult to isolate and unit test individual behaviors.
- Fix approach: Extract `NewGameFlow`, `ActiveGameView`, and `AvailabilityView` to separate files. Consider introducing a `GameCoordinator` or state machine to manage phase transitions more explicitly.

**FieldCanvasView state and undo stack:**
- Issue: `FieldCanvasView` maintains its own local `@State private var undoStack` that is not persisted to SwiftData. The undo stack is lost when the view is dismissed or recreated, and there's no way to recover drawing state mid-session.
- Files: `PigeonPlay/Views/Playbook/FieldCanvasView.swift`
- Impact: Users who accidentally dismiss the canvas or navigate away lose all undo history. Undo becomes unreliable across view lifecycle boundaries.
- Fix approach: Persist undo stack to a temporary data structure (either in-memory session state or as a SwiftData model). Consider managing undo/redo at the model layer rather than view layer.

**Duplicated lineup selection logic:**
- Issue: Nearly identical UI and logic for building a lineup exists in both `LineSelectionView` and `NextLineQueueView`. Both handle player filtering, gender matching toggles, add/remove buttons, and suggest shuffles. This violates DRY principle.
- Files: `PigeonPlay/Views/Game/LineSelectionView.swift` (120 lines), `PigeonPlay/Views/Game/NextLineQueueView.swift` (130 lines)
- Impact: Bug fixes or UX improvements to one view require changes to both. Changes easily drift out of sync, creating inconsistent behavior between current line and queued line selection.
- Fix approach: Extract shared UI and business logic into a parameterized `LineBuilderView` component. Pass callbacks for add/remove/resuggest behaviors rather than duplicating them.

**LineSuggester gender-matching defaults hardcoded:**
- Issue: In `LineSuggester.suggest()`, players with gender `.x` are always matched to `.bx` or `.gx` based on `defaultMatching` or a hardcoded fallback (line 125 in `NextLineQueueView`). The fallback `?? .bx` is repeated across multiple views with no single source of truth.
- Files: `PigeonPlay/Services/LineSuggester.swift`, `PigeonPlay/Views/Game/LineSelectionView.swift`, `PigeonPlay/Views/Game/NextLineQueueView.swift`
- Impact: If gender-matching logic needs to change, it must be updated in multiple places. Easy to miss a location and create inconsistent behavior.
- Fix approach: Create a helper function or extension method (e.g., `Player.defaultGenderMatching()`) in the `Player` model that returns the matching with a single hardcoded fallback. Reference this everywhere.

## Known Bugs

**No validation of point recording:**
- Symptoms: A point can be recorded with `outcome: .us` but `scorer: nil`, resulting in invalid game state. The UI prevents this (requires scorer selection), but the data model has no constraints.
- Files: `PigeonPlay/Models/Game.swift` (GamePoint init), `PigeonPlay/Views/Game/RecordPointView.swift`
- Trigger: If UI state is bypassed (e.g., via direct API calls in tests or future refactoring), invalid points can be created.
- Workaround: Rely entirely on UI validation in `RecordPointView`. Brittle—any UI change that allows recording without scorer breaks this.

**Bench time tracking may be incorrect after undo:**
- Symptoms: When a point is undone, `lastPointOnBench` dictionary computed in `ActiveGameView` is recalculated, but players who were on bench during the undone point may show incorrect `lastPointOnBench` values if multiple undos occur in sequence.
- Files: `PigeonPlay/Views/Game/GameView.swift` (lines 122–131), `PigeonPlay/Models/Game.swift`
- Trigger: User records point, then undoes multiple times in sequence.
- Workaround: Not aware of a user-facing workaround; the sorting will just be slightly off for bench time on subsequent suggestions.

**DrawingElement CGPoint not resilient to orientation changes:**
- Symptoms: Drawing coordinates in `FieldCanvasView` are not normalized to the field's logical coordinate space. If the device rotates from landscape to portrait (or vice versa), existing drawing elements won't rescale and will appear in wrong positions.
- Files: `PigeonPlay/Views/Playbook/FieldCanvasView.swift`, `PigeonPlay/Models/SavedPlay.swift` (DrawingElement)
- Trigger: User draws a play in landscape, saves it, then loads it in portrait (or device rotates during drawing).
- Workaround: Always open and use playbook in the same orientation.

**No persistence of current game/playbook state if app is force-quit:**
- Symptoms: If user is in the middle of recording points or drawing a play and the app is force-quit, the current session (in-progress point, canvas elements) is lost. SwiftData is persisted but in-memory `@State` is not.
- Files: `PigeonPlay/Views/Game/GameView.swift`, `PigeonPlay/Views/Playbook/PlaybookView.swift`
- Trigger: App is backgrounded then force-quit while a game is active or playbook is being edited.
- Workaround: Users should end games and save plays before closing the app.

## Security Considerations

**Parent contact information stored in plaintext:**
- Risk: Player parent email, phone, and name are stored in SwiftData without encryption. If device is stolen or backup is compromised, sensitive contact information is exposed.
- Files: `PigeonPlay/Models/Player.swift`, `PigeonPlay/Views/Roster/PlayerFormView.swift`
- Current mitigation: Relies on iOS device-level encryption (Data Protection) and user PIN/Face ID.
- Recommendations: Consider encrypting parent contact fields using CryptoKit or Keychain before storing. At minimum, warn users in UI that parent data is stored locally. Do not sync/backup this data to iCloud without explicit user consent and encryption.

**No backup or export mechanism:**
- Risk: All data (players, games, plays) exists only on the device. No export, backup, or recovery mechanism exists if the app is uninstalled or device is replaced.
- Files: App-wide (model layer)
- Current mitigation: None.
- Recommendations: Implement data export (JSON, CSV) and import capabilities. Consider optional iCloud sync (encrypted). Document backup procedure in app UI.

## Performance Bottlenecks

**Recalculating pointsPlayed and lastPointOnBench on every render:**
- Problem: `ActiveGameView` recalculates `pointsPlayed` and `lastPointOnBench` dictionaries every time the view renders (lines 109–131). These are O(n) operations over all points and players.
- Files: `PigeonPlay/Views/Game/GameView.swift` (lines 109–131)
- Cause: These are computed properties that re-run on every state change, even if `game.points` hasn't changed. With large games (50+ points, 15+ players), this can add up.
- Improvement path: Memoize these calculations or compute them once when points are recorded. Store computed stats in the `Game` model or use a view model with proper change detection.

**Line suggestion algorithm uses .shuffled() every call:**
- Problem: `LineSuggester.suggest()` calls `.shuffled()` on the entire available player pool (lines 37, 41) even when just sorting by play time and bench time. This adds randomness intentionally but is called frequently (on ratio change, shuffle button, etc.).
- Files: `PigeonPlay/Services/LineSuggester.swift` (lines 35–41)
- Cause: Designed for fairness; minimizes bias toward earlier-listed players. But shuffling the entire array O(n) on every suggest is wasteful.
- Improvement path: For initial suggestions (before shuffle), skip shuffling and just sort. Only shuffle when user taps "Shuffle" button explicitly. Or, use a more efficient randomization (Fisher-Yates with early termination).

**LinearLayout re-renders entire player list on small state changes:**
- Problem: `LineSelectionView` and `NextLineQueueView` use `ForEach` with `.persistentModelID` keying, but the entire bench/on-field sections re-render when any binding changes (e.g., when toggling a single player's gender matching).
- Files: `PigeonPlay/Views/Game/LineSelectionView.swift` (lines 28–83), `PigeonPlay/Views/Game/NextLineQueueView.swift` (lines 33–92)
- Cause: `@Binding` modifications trigger parent view recompute, which re-renders all child ForEach entries.
- Improvement path: Use `@State` for local modifications where possible. Consider extracting player rows to separate subviews with their own `@State` to isolate re-renders.

## Fragile Areas

**GamePhase enum and state machine:**
- Files: `PigeonPlay/Views/Game/GameView.swift` (lines 104–107, 162–251)
- Why fragile: `GamePhase` is a simple enum with no validation. The `phase` state can be set to any value at any time, but the UI assumes strict transitions (selectingLine → recordingPoint → selectingLine). If an intermediate view forgets to update phase, the UI enters an inconsistent state.
- Safe modification: Consider a proper state machine or use a @StateObject coordinator that manages valid transitions explicitly. Add assertions or guards to catch invalid state changes.
- Test coverage: Test only happy paths. No tests for invalid phase transitions or concurrent state modifications.

**undoLastPoint() returns Optional but no verification of state consistency:**
- Files: `PigeonPlay/Models/Game.swift` (lines 102–106)
- Why fragile: `undoLastPoint()` removes a point and returns it, but doesn't verify that the game state remains consistent (e.g., if a removed point was a scorer's only goal, stats may be stale elsewhere in the app).
- Safe modification: After undo, ensure all derived state (pointsPlayed, lastPointOnBench) is recalculated. Consider making undo a transaction that updates all derived state atomically.
- Test coverage: `GameTests` verify undo removes points but don't verify state consistency post-undo.

**DrawingElement enum without versioning:**
- Files: `PigeonPlay/Models/SavedPlay.swift` (lines 4–8)
- Why fragile: `DrawingElement` is stored directly in SwiftData. If the enum cases change (e.g., adding a new tool), older saved plays won't deserialize. No migration path exists.
- Safe modification: Add a version number to `SavedPlay` or use a `@Codable` strategy with version handling before modifying `DrawingElement`.
- Test coverage: No tests for SavedPlay serialization/deserialization.

**nextLineQueue depends on precise ratio alternation:**
- Files: `PigeonPlay/Views/Game/GameView.swift` (lines 193–201), `PigeonPlay/Models/Game.swift` (lines 15–20)
- Why fragile: When locking in a line, the queued ratio is set to `currentRatio.alternated`. If ratio logic changes or a new ratio type is added, this breaks silently. No validation that the queued ratio is actually different.
- Safe modification: Add a test that verifies alternated ratios are always different. Consider explicit ratio sequences (e.g., [.twoBThreeG, .threeBTwoG] repeating) instead of .alternated.
- Test coverage: No tests for queue ratio alternation logic.

## Scaling Limits

**Game points stored in memory array:**
- Current capacity: Array can theoretically hold unlimited points, but with large games (200+ points) and SwiftData queries, memory usage grows linearly.
- Limit: No pagination or lazy loading of game points. Entire game history is loaded into memory when a game is displayed.
- Scaling path: Implement pagination for game detail view. Use `.limit()` in SwiftData queries for history. Consider archive old games separately.

**Player roster grows without indexing:**
- Current capacity: All players are loaded into memory by `@Query` on every view that displays players.
- Limit: With 100+ players, query performance and List rendering slowdown.
- Scaling path: Add search/filter to player list. Implement lazy loading with pagination. Use SwiftData indexing on player name.

**SavedPlay elements array unbounded:**
- Current capacity: Drawing elements array can grow indefinitely as user draws.
- Limit: No undo history limit, no element count limit. Very large drawings can cause memory pressure and slow down serialization.
- Scaling path: Cap undo stack to last 50 actions. Implement drawing element pruning/simplification if array grows too large.

## Dependencies at Risk

**SwiftData adoption (new framework):**
- Risk: SwiftData is relatively new (iOS 17+). If critical bugs are found or API changes occur, migration is costly. Limited third-party tooling and fewer Stack Overflow answers for edge cases.
- Impact: Bugs in SwiftData could freeze the app (e.g., query performance, model versioning). No easy way to migrate to Core Data without major refactoring.
- Migration plan: Maintain a data export/import feature so data is not locked into SwiftData. Consider Core Data as a fallback if SwiftData proves problematic.

**CGPoint in DrawingElement Codable:**
- Risk: CGPoint's Codable conformance is not guaranteed to be stable across OS versions or SwiftUI updates.
- Impact: Older saved plays may not deserialize on newer iOS versions.
- Migration plan: Create explicit struct `DrawingPoint(x: CGFloat, y: CGFloat)` conforming to Codable instead of relying on CGPoint's default behavior. Migrate existing plays on app upgrade.

## Missing Critical Features

**No conflict resolution for simultaneous edits:**
- Problem: If two views modify the same player or game concurrently (e.g., editing player while adding to a lineup), conflicts are undetected.
- Blocks: Cannot safely implement features like online multiplayer or collaborative playbook editing.

**No game statistics or analytics:**
- Problem: Games are recorded but no aggregated stats exist (e.g., player average points per game, win-loss record by opponent, gender ratio win rates). All analysis requires manual game-by-game review.
- Blocks: Users can't make data-driven decisions (e.g., which ratio is more effective, which players perform better together).

**No ability to adjust lineups mid-point:**
- Problem: Once a point is locked in, the lineup is fixed. If a substitution is needed (e.g., due to injury during play), there's no way to record it without undoing the entire point.
- Blocks: Realistic game scenarios where mid-point substitutions are necessary.

**No import/export of player rosters:**
- Problem: Each game/device has a separate roster. No way to share rosters between users or devices, or to back up/restore.
- Blocks: Team coordination across devices; disaster recovery.

## Test Coverage Gaps

**FieldCanvasView drawing and undo:**
- What's not tested: Drawing gestures, stroke creation, arrow/circle placement, eraser intersection detection, undo stack persistence.
- Files: `PigeonPlay/Views/Playbook/FieldCanvasView.swift`
- Risk: Bugs in drawing logic, geometry calculations, or undo state machine are undetected. Eraser threshold (line 118, 20pt) could be adjusted incorrectly without test feedback.
- Priority: Medium (not core to game recording, but important UX)

**GameView phase transitions and state coherence:**
- What's not tested: Transitions between selectingLine and recordingPoint, interaction between queue and current line, undo and phase state coherence.
- Files: `PigeonPlay/Views/Game/GameView.swift` (lines 92–323)
- Risk: Phase transitions can become inconsistent if state management changes.
- Priority: High (core gameplay flow)

**SavedPlay serialization and deserialization:**
- What's not tested: Saving plays, loading plays, corrupted data handling, version migrations.
- Files: `PigeonPlay/Models/SavedPlay.swift`
- Risk: Plays fail to load due to SwiftData model changes or data corruption.
- Priority: Medium (feature is less critical, but data loss is painful)

**Player gender matching fallback logic:**
- What's not tested: X-gender players with no defaultMatching specified, behavior when defaultMatching is nil, fallback to `.bx`.
- Files: `PigeonPlay/Models/Player.swift`, `PigeonPlay/Views/Game/LineSelectionView.swift`, `PigeonPlay/Views/Game/NextLineQueueView.swift`
- Risk: X-gender players default incorrectly if fallback is not handled uniformly.
- Priority: High (affects fairness of line suggestions)

**Undo game state consistency:**
- What's not tested: After undo, pointsPlayed and lastPointOnBench are recalculated correctly; undo followed by new points produces correct stats.
- Files: `PigeonPlay/Models/Game.swift`, `PigeonPlay/Views/Game/GameView.swift`
- Risk: Stats drift or become incorrect after multiple undos, affecting fairness of next line suggestions.
- Priority: High (affects game integrity)

**ActiveGameView availability toggle:**
- What's not tested: Adding and removing available players, lineup state after availability changes, edge cases (all players removed, re-added).
- Files: `PigeonPlay/Views/Game/GameView.swift` (AvailabilityView, lines 325–368)
- Risk: UI and game state may desynchronize if a player on the field is suddenly marked unavailable.
- Priority: Medium (edge case, but impacts gameplay)

---

*Concerns audit: 2026-03-17*
