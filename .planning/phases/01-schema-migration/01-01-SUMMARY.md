---
phase: 01-schema-migration
plan: 01
subsystem: database
tags: [swiftdata, migration, versioned-schema, schema-migration]

# Dependency graph
requires: []
provides:
  - Player model V2 shape: phoneNumber (String?), contactIdentifiers ([String])
  - PlayerMigration.swift with V1 snapshot, V2 ref, and lightweight SchemaMigrationPlan
  - ModelContainer wired with PlayerMigrationPlan for safe schema migration on existing installs
affects: [02-contact-picker, 03-contact-display]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - VersionedSchema enum pattern for SwiftData model history (PlayerSchemaV1 as verbatim snapshot)
    - ModelContainer constructed in App init() with migrationPlan for Scene-level wiring
    - Separate PlayerMigration.swift isolates dead V1 code from live Player.swift

key-files:
  created:
    - PigeonPlay/Models/PlayerMigration.swift
  modified:
    - PigeonPlay/Models/Player.swift
    - PigeonPlay/App/PigeonPlayApp.swift
    - PigeonPlay/Views/Roster/PlayerFormView.swift
    - PigeonPlayTests/PlayerTests.swift
    - PigeonPlay.xcodeproj/project.pbxproj

key-decisions:
  - "ModelContainer constructed in App init() rather than via .modelContainer(for:migrationPlan:) Scene modifier — that overload does not exist; throwing init requires explicit do/catch with fatalError for local data store"
  - "static let instead of static var for versionIdentifier — Swift 6.0 strict concurrency rejects mutable global state on nonisolated types"

patterns-established:
  - "Pattern 1: VersionedSchema V1 as verbatim model snapshot — never modify V1; it anchors the on-disk fingerprint"
  - "Pattern 2: PlayerSchemaV2.models points to PigeonPlay.Player (live type) rather than a duplicate nested class"

requirements-completed: [SCHEMA-01, SCHEMA-02, SCHEMA-03, SCHEMA-04]

# Metrics
duration: 10min
completed: 2026-03-23
---

# Phase 01 Plan 01: Schema Migration Summary

**SwiftData Player model migrated from V1 (parentName/parentPhone/parentEmail) to V2 (phoneNumber/contactIdentifiers) via lightweight VersionedSchema migration plan wired into ModelContainer**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-23T03:50:00Z
- **Completed:** 2026-03-23T04:00:08Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Player model V2 shape: `phoneNumber: String?` and `contactIdentifiers: [String] = []`; parent fields dropped
- PlayerMigration.swift: V1 verbatim snapshot + lightweight SchemaMigrationPlan for crash-free migration on existing installs
- All 32 tests pass; parent field tests replaced with V2 contract tests for new fields

## Task Commits

Each task was committed atomically:

1. **Task 1: Update PlayerTests for V2 model shape (TDD Red)** - `38e02ae` (test)
2. **Task 2: Create migration infrastructure and update model, app, and view (TDD Green)** - `a360d26` (feat)

## Files Created/Modified

- `PigeonPlay/Models/PlayerMigration.swift` - PlayerSchemaV1 (V1 snapshot), PlayerSchemaV2, PlayerMigrationPlan
- `PigeonPlay/Models/Player.swift` - V2 Player model: phoneNumber, contactIdentifiers; parent fields removed
- `PigeonPlay/App/PigeonPlayApp.swift` - ModelContainer constructed with PlayerMigrationPlan in App init()
- `PigeonPlay/Views/Roster/PlayerFormView.swift` - Parent contact section and state vars removed
- `PigeonPlayTests/PlayerTests.swift` - V1 parent field tests removed; 4 new V2 tests added
- `PigeonPlay.xcodeproj/project.pbxproj` - Regenerated via XcodeGen to include PlayerMigration.swift

## Decisions Made

- **ModelContainer API**: `.modelContainer(for:migrationPlan:)` does not exist as a Scene modifier — the `migrationPlan:` parameter only exists on the `ModelContainer` throwing initializer. Constructed container explicitly in `App.init()` with `fatalError` on failure (acceptable for local-only SwiftData store).
- **Swift 6.0 concurrency fix**: `versionIdentifier` declared as `static let` not `static var` — Swift 6 strict concurrency rejects mutable nonisolated global state. Changed in both V1 and V2 schema enums.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Incorrect `.modelContainer(for:migrationPlan:)` Scene modifier usage**
- **Found during:** Task 2 (PigeonPlayApp.swift update)
- **Issue:** Plan specified `.modelContainer(for:migrationPlan:)` as a Scene modifier, but this overload does not exist in the SwiftData+SwiftUI bridge. Only `init(for:migrationPlan:)` on `ModelContainer` directly accepts a migration plan.
- **Fix:** Construct `ModelContainer` explicitly in `App.init()` using the throwing convenience initializer, then pass the container instance to `.modelContainer(_:)`.
- **Files modified:** `PigeonPlay/App/PigeonPlayApp.swift`
- **Verification:** BUILD SUCCEEDED; all 32 tests pass
- **Committed in:** `a360d26` (Task 2 commit)

**2. [Rule 1 - Bug] Swift 6.0 concurrency error on mutable static versionIdentifier**
- **Found during:** Task 2 (first build attempt)
- **Issue:** `static var versionIdentifier = Schema.Version(...)` in VersionedSchema enums is nonisolated global mutable state — Swift 6 strict concurrency rejects this with an error.
- **Fix:** Changed to `static let` in both `PlayerSchemaV1` and `PlayerSchemaV2`.
- **Files modified:** `PigeonPlay/Models/PlayerMigration.swift`
- **Verification:** BUILD SUCCEEDED; no concurrency warnings
- **Committed in:** `a360d26` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs from plan inaccuracies about API shape and Swift 6 constraints)
**Impact on plan:** Both fixes necessary for the build to succeed. No scope creep.

## Issues Encountered

- XcodeGen regeneration required to add PlayerMigration.swift to the Xcode project — the xcodeproj's source directory glob picks up all Swift files, but the on-disk project.pbxproj needed regeneration.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Player V2 model is in place; `phoneNumber` and `contactIdentifiers` fields ready for Phase 2 (Contact Picker UI)
- `PlayerFormView` is intentionally sparse — parent section removed, contact picker UI comes in Phase 2
- No blockers for Phase 2

## Self-Check: PASSED

- FOUND: PigeonPlay/Models/PlayerMigration.swift
- FOUND: PigeonPlay/Models/Player.swift
- FOUND: PigeonPlay/App/PigeonPlayApp.swift
- FOUND: .planning/phases/01-schema-migration/01-01-SUMMARY.md
- FOUND commit: 38e02ae (test: TDD Red)
- FOUND commit: a360d26 (feat: TDD Green)

---
*Phase: 01-schema-migration*
*Completed: 2026-03-23*
