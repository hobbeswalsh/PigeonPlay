# Productization TODO

What stands between PigeonPlay as our team's app and PigeonPlay as something we
ship. Written 2026-08-17 from a read-through of the whole codebase at commit
`fbc0a6b`.

Caveat on every claim below: this review was not build-verified. The reviewing
machine had only Command Line Tools, so `xcodebuild -project PigeonPlay.xcodeproj
-scheme PigeonPlay test` could not run. Line references were read, not executed.

The code itself is in decent shape — small, coherent, honestly commented, and the
model layer is genuinely tested. The gap to a product is durability,
sport-configurability, accessibility, and release engineering.

## Ship blockers

These change the data model or the persistence story, so they are cheapest before
1.0 ships and expensive after.

- [ ] **Give coaches a way to not lose the season.** Everything lives in one
  on-device SwiftData store with no export, no import, and no sync, so a lost
  phone is a lost season. `PigeonPlayApp.swift:18` calls `fatalError` on migration
  failure, which beats deleting the store but leaves the user with an app that
  cannot launch. Nothing in the app calls `modelContext.save()`, so we depend
  entirely on autosave — fine indoors, not on a sideline where iOS kills a
  backgrounded app. Add CloudKit sync plus a JSON export. Do it first: CloudKit
  requires every attribute to carry a default and every relationship to be
  optional, which is a schema-wide change we cannot make cheaply once real stores
  exist. From 1.0 onward, every migration needs a test that opens a fixture store
  from the previously shipped version; `PlayerMigration.swift:3-12` records that a
  prior store was already destroyed once.

- [ ] **Persist the in-flight game state.** `ActiveGameView.swift:13-20` keeps
  `phase`, `selectedLine`, `queuedLine`, and `currentRatio` in `@State`, and only
  the ratio is re-derived on relaunch (`ActiveGameView.swift:24-28`). If iOS kills
  the app between locking in a line and recording the point, the coach rebuilds
  the line mid-game. This is the most likely real-world failure for an app used
  outdoors. Extract an `@Observable GameSession` that owns the flow and writes the
  in-flight line onto `Game`. This also unblocks testing: `lockIn`, `recordPoint`,
  `undoPoint`, and `reconcileLines` are private methods on a `View` struct today,
  so phase transitions, undo-then-record, and mid-line availability changes have
  no coverage at all.

- [ ] **Close the player-deletion hole that can corrupt a game.** `Game.involves`
  (`Game.swift:151-158`) only scans recorded points, and `RosterView.swift:94-96`
  uses it as the sole delete guard, so a player sitting in `availablePlayers` or
  standing on a locked-in but unrecorded line is freely deletable from the Roster
  tab. `PointPlayer.player` is non-optional (`Game.swift:43`), so recording that
  point afterward writes a relationship to a deleted object. `reconcileLines` only
  runs on availability-sheet dismissal (`ActiveGameView.swift:189`), so it never
  fires for a roster-tab deletion. Widen the guard to cover `availablePlayers` of
  any active game.

- [ ] **Key object identity one way instead of three.** The codebase mixes
  `ObjectIdentifier` (`LineSuggester.swift:36`, `Game.swift:140-141`,
  `LineBuilderView.swift:9-15`), `persistentModelID` (`ActiveGameView.swift:209`,
  `RecordPointView.swift:34`), and `Player` itself as a `Dictionary` key
  (`Game.swift:122`). `ObjectIdentifier` is a memory address and only holds while
  a single `ModelContext` vends the same instance, and `Player`-as-key hashes on
  `persistentModelID`, which changes when a freshly inserted object is saved. It
  works today by accident of single-context uniquing. Standardize on
  `PersistentIdentifier`; the work is mechanical but it changes
  `LineSuggester.suggest`'s signature and touches both line views.

## App Store review will flag this

- [ ] **Add accessibility, Dynamic Type, and localization support.** There is not
  one `accessibilityLabel` in the project. The icon-only call, message, and mail
  buttons (`PlayerFormView.swift:192-215`), the add and remove line buttons
  (`LineBuilderView.swift:37-42` and `:65`), and every playbook tool and color
  swatch (`PlaybookView.swift:35-57`) are silent to VoiceOver. Fixed-width stat
  columns (`GameDetailView.swift:54-66`) clip at large text sizes, and gender is
  conveyed by color alone at `LineBuilderView.swift:29`. No string catalog exists.
  The work is broad but shallow: one sweep of every view plus a pass with
  Accessibility Inspector.

## Turns it from our team's app into a product

- [ ] **Store saved plays in normalized coordinates.** `FieldCanvasView.swift:97`,
  `:103`, and `:108` store `value.location` verbatim, and `isHorizontal`
  (`PlaybookView.swift:11`) only repaints the background. A play drawn on an
  iPhone in landscape renders as garbage on an iPad, in portrait, or after
  toggling field orientation. Normalize to unit coordinates and version
  `DrawingElement` (`SavedPlay.swift:4-8`) so existing plays migrate.

- [ ] **Fix the playbook's editing model while in there.**
  `FieldCanvasView.undo()` at line 140 is called from nowhere, so `undoStack` at
  line 15 copies the entire element array on every stroke and is never read.
  Clearing the canvas (`PlaybookView.swift:63`) and loading a play (`:110`) both
  discard unsaved work without confirmation, and saving always inserts a new
  `SavedPlay`, so there is no rename and no overwrite.

- [ ] **Make the ratio sequence and line size configurable.**
  `GenderRatio.alternated` (`Game.swift:15-20`) with `nextRatio`
  (`Game.swift:116-118`) can only produce ABAB, but much of coed ultimate uses
  ABBA — this is the surviving item from the old TODO. Line size 5 is baked into
  `LineBuilderView.swift:46` and `:89`, `ActiveGameView.swift:113`, and the counts
  in `Game.swift:22-34`. If we support teams beyond our own, the ratio sequence
  and line size belong in a team or league settings model referenced by `Game`.

- [ ] **Rename the gender model in the same migration.** `Gender` and
  `GenderMatching` (`Player.swift:4-21`) model a child's identity in order to
  express a lineup rule. What the app needs to know is which side of the ratio a
  player counts toward. Naming it that way is more accurate and less fraught for
  an app about elementary schoolers, and it costs nothing extra if we are already
  migrating for the item above.

- [ ] **Meet the obligations that come with storing parents' contact data.** We
  need a privacy policy URL, the App Store privacy questionnaire answered for
  contact data, and a deliberate COPPA decision if this ships for children's
  teams. (Contact linking itself shipped in the v1.0 Contact Management
  milestone — this is the follow-through, not the feature.)

- [ ] **Stop relying on device-local contact identifiers.**
  `Player.contactIdentifiers` (`Player.swift:29`) stores only `CNContact`
  identifiers, which are device-local, so links break on device migration and the
  row degrades to "Contact no longer available" (`PlayerFormView.swift:79`) with
  no repair path. `CNContactPickerViewController` hands us the selected contact's
  properties out-of-process, so caching name, phone, and email at link time would
  survive migration and remove the Contacts permission prompt entirely —
  `PlayerFormView.swift:137-146` currently asks at a confusing moment, after the
  picker has already succeeded. The trade-off is that cached copies go stale and
  we would own a parent's contact details, so this needs an explicit delete path.
  Decide deliberately rather than by default.

- [ ] **Build the release engineering that does not exist.** There is no CI
  directory. `project.yml` has no version or build number management, no
  Debug/Release separation, and no signing configuration. The app icon is still a
  placeholder named `Gemini_Generated_Image_j3cwdqj3cwdqj3cw.png`. Both
  `project.yml` and a committed `PigeonPlay.xcodeproj` are checked in as sources
  of truth while xcodegen is not installed, so they will drift. There is no crash
  reporting. Pick one project source of truth, add CI running `xcodebuild test` on
  every PR, and wire up MetricKit or a crash reporter before we have users we
  cannot phone.

## Smaller items

- [ ] `GameView.swift:6` and `:13` take `activeGames.first` from an unsorted
  query, which is nondeterministic if the single-active-game invariant ever
  breaks. Add a sort or enforce the invariant in the model.

- [ ] `RosterView` shows a bare empty `List` for a new user with no players, and
  `CheckInView` shows an empty list with a disabled Start button and no
  explanation. Both want a `ContentUnavailableView`.

## Notes

`.planning/codebase/CONCERNS.md` is stale and should not be used as a to-do list.
It describes a 368-line `GameView.swift` that no longer exists and duplicated
line-selection views that have since been unified into `LineBuilderView`.

`Game.pointsPlayed` and `Game.lastPointOnBench` (`Game.swift:122-146`) recompute
on every render. That is fine at team scale; do not optimize it yet.
