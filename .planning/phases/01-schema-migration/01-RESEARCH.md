# Phase 1: Schema Migration - Research

**Researched:** 2026-03-22
**Domain:** SwiftData VersionedSchema migration — dropping legacy parent fields, adding contact fields
**Confidence:** HIGH

---

## Summary

Phase 1 is a focused SwiftData model migration. The `Player` model currently carries three legacy fields (`parentName`, `parentPhone`, `parentEmail`) that must be removed, and two new fields must be added (`phoneNumber: String?`, `contactIdentifiers: [String]`). No business logic or UI work belongs in this phase — the goal is simply a compiler-clean, crash-free model that future phases build on.

The critical constraint is that the current `Player` model has **no `VersionedSchema` wrapping**. This means the on-disk store has no version fingerprint. Attempting a direct migration without first registering V1 will cause a launch crash for any user with existing persisted data. The plan must handle V1 registration and V2 migration in a single release (acceptable here because the user has confirmed existing data loss is acceptable and the deployment audience is small/development-only).

The migration qualifies as **lightweight** throughout: all dropped fields are optional, the new `phoneNumber` is optional, and `contactIdentifiers` defaults to `[]`. No custom migration closure code is needed.

**Primary recommendation:** Define `PlayerSchemaV1` (verbatim current model), define `PlayerSchemaV2` (new shape), declare a lightweight `SchemaMigrationPlan`, update `PigeonPlayApp.swift` to pass the plan to `modelContainer`, and update all tests and views that reference the dropped fields.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCHEMA-01 | Player model wrapped in VersionedSchema V1/V2 with SchemaMigrationPlan | VersionedSchema + SchemaMigrationPlan pattern documented in Standard Stack and Architecture Patterns sections |
| SCHEMA-02 | parentName, parentPhone, parentEmail fields removed from Player model | Lightweight migration supports field removal; V1 preserved for migration path |
| SCHEMA-03 | Player has optional phoneNumber (String?) for player's own number | Optional field addition qualifies as lightweight; no migration closure needed |
| SCHEMA-04 | Player has contactIdentifiers ([String]) for linked iOS Contact IDs | Array with default `[]` qualifies as lightweight; field naming confirmed in Architecture research |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData `VersionedSchema` | iOS 17+ (app targets iOS 18) | Type-safe schema versioning | Required API for any SwiftData model migration; no alternative |
| SwiftData `SchemaMigrationPlan` | iOS 17+ | Declares the ordered migration path | Required to register V1 fingerprint and describe V1→V2 steps |
| SwiftData `MigrationStage.lightweight` | iOS 17+ | Performs field add/drop automatically | Sufficient for this migration; no data transformation needed |
| Swift Testing (`@Test` macro) | Xcode 16 / iOS 18 | Unit tests | Already in use in this project |

### No New Dependencies

This phase introduces no new imports. All required APIs are already available via the existing `import SwiftData` statements.

### Version Verification

SwiftData `VersionedSchema` and `SchemaMigrationPlan` are iOS 17+ APIs. The app targets iOS 18.0. No version compatibility concern.

---

## Architecture Patterns

### Recommended File Structure for This Phase

```
PigeonPlay/
├── Models/
│   ├── Player.swift           # Now contains PlayerSchemaV2.Player (the live model)
│   └── PlayerMigration.swift  # New: PlayerSchemaV1, PlayerSchemaV2, PlayerMigrationPlan
└── App/
    └── PigeonPlayApp.swift    # Updated: modelContainer gains migrationPlan
PigeonPlayTests/
└── PlayerTests.swift          # Updated: drop parent field tests, add new field tests
```

**Rationale for separate `PlayerMigration.swift`:** V1 schema is dead code that must be preserved for migration purposes only. Isolating it prevents confusion about which type is the live model. The `Player.swift` file retains only the current (V2) definition.

### Pattern 1: VersionedSchema + Lightweight Migration

**What:** Wrap the exact current model in `PlayerSchemaV1`, define the new shape in `PlayerSchemaV2`, declare a plan, and pass it to `modelContainer`.

**When to use:** Any time a SwiftData model has shipped to devices and needs structural changes.

**Example:**
```swift
// PlayerMigration.swift
// Source: Apple Developer Documentation — SchemaMigrationPlan

import SwiftData

enum PlayerSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Player.self] }

    @Model
    final class Player {
        var name: String
        var gender: PigeonPlay.Gender
        var defaultMatching: PigeonPlay.GenderMatching?
        var parentName: String?
        var parentPhone: String?
        var parentEmail: String?

        init(name: String, gender: PigeonPlay.Gender, defaultMatching: PigeonPlay.GenderMatching? = nil,
             parentName: String? = nil, parentPhone: String? = nil, parentEmail: String? = nil) {
            self.name = name
            self.gender = gender
            self.defaultMatching = defaultMatching
            self.parentName = parentName
            self.parentPhone = parentPhone
            self.parentEmail = parentEmail
        }
    }
}

enum PlayerSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Player.self] }

    @Model
    final class Player {
        var name: String
        var gender: PigeonPlay.Gender
        var defaultMatching: PigeonPlay.GenderMatching?
        var phoneNumber: String?
        var contactIdentifiers: [String]

        init(name: String, gender: PigeonPlay.Gender, defaultMatching: PigeonPlay.GenderMatching? = nil,
             phoneNumber: String? = nil, contactIdentifiers: [String] = []) {
            self.name = name
            self.gender = gender
            self.defaultMatching = defaultMatching
            self.phoneNumber = phoneNumber
            self.contactIdentifiers = contactIdentifiers
        }
    }
}

enum PlayerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PlayerSchemaV1.self, PlayerSchemaV2.self]
    }
    static var stages: [MigrationStage] {
        [MigrationStage.lightweight(fromVersion: PlayerSchemaV1.self, toVersion: PlayerSchemaV2.self)]
    }
}
```

```swift
// PigeonPlayApp.swift — updated modelContainer call
.modelContainer(
    for: [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self],
    migrationPlan: PlayerMigrationPlan.self
)
```

### Pattern 2: Keeping the Live Model Canonical

The `Player` class in `Player.swift` becomes the V2 shape directly. It is **also** referenced by `PlayerSchemaV2.models`. SwiftData resolves the live model by the type in `models` — `PlayerSchemaV2.Player` in the migration file should either alias or be the same `Player` type from the main module.

**Important nuance:** The V1 `Player` inner type inside `PlayerSchemaV1` must be a distinct nested type to avoid naming conflicts. Name it as a nested class inside the enum:

```swift
enum PlayerSchemaV1: VersionedSchema {
    // ...
    @Model final class Player { ... }  // distinct from PigeonPlay.Player
}
```

The live `PigeonPlay.Player` in `Player.swift` becomes the V2 definition. `PlayerSchemaV2.models` points to `PigeonPlay.Player.self`.

### Anti-Patterns to Avoid

- **Combining V1 wrap and field changes in one type**: V1 must be a verbatim snapshot of the current model. Do not add, remove, or rename fields in V1.
- **Putting V1 definition inside `Player.swift`**: Pollutes the live model file with historical dead code. Use `PlayerMigration.swift`.
- **Forgetting to update `modelContainer`**: Defining the plan but not passing `migrationPlan:` to `modelContainer` means the migration never runs and existing users crash.
- **Making `contactIdentifiers` non-optional with no default**: Adding a non-optional `[String]` without `= []` may cause a lightweight migration failure on some SwiftData versions. Always provide a default of `[]`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Field removal between app versions | Manual store deletion or custom migration code | `MigrationStage.lightweight` | SwiftData handles optional field removal automatically; custom code is error-prone and unnecessary |
| Schema versioning fingerprint | Manual version tracking in UserDefaults | `VersionedSchema.versionIdentifier` | SwiftData uses the version identifier to match on-disk schema to known versions; hand-rolling this will conflict |
| Default values for new array fields | Populate in a custom `willMigrate` closure | `contactIdentifiers: [String] = []` in V2 initializer | Lightweight migration applies defaults automatically for new optional/defaulted fields |

**Key insight:** SwiftData's lightweight migration is specifically designed for exactly this shape of change (drop optionals, add optional/defaulted fields). The entire value of the framework is avoiding custom data transformation code for these cases.

---

## Common Pitfalls

### Pitfall 1: Skipping the V1 Registration Step

**What goes wrong:** The developer writes V2 and a migration plan but never defines V1. SwiftData cannot match the on-disk store fingerprint to any known version and crashes on launch with `"Cannot use staged migration with an unknown model version"`.

**Why it happens:** V1 feels unnecessary — the existing model is "already there." But SwiftData needs an explicit fingerprinted version to anchor the migration path.

**How to avoid:** `PlayerSchemaV1` must contain a verbatim copy of the current `Player` fields: `name`, `gender`, `defaultMatching`, `parentName`, `parentPhone`, `parentEmail`. Do not modify V1.

**Warning signs:** Any migration plan whose `schemas` array starts at V2 without a V1 entry. Any `Player.swift` that does not have a corresponding V1 enum before migration code is written.

### Pitfall 2: Non-Optional Non-Defaulted Fields in Lightweight Migration

**What goes wrong:** Adding `var contactIdentifiers: [String]` without a default value `= []` may cause the lightweight migration to fail silently or crash, because existing rows have no value for the new column.

**Why it happens:** Lightweight migration can only set new columns to `nil` (for optionals) or a default value specified in the initializer. A non-optional array with no default has no value to assign.

**How to avoid:** Always declare `var contactIdentifiers: [String] = []` with the default in the initializer. Swift 6 will not complain; SwiftData will use the default for existing rows.

**Warning signs:** Compiler accepts the field but the app crashes or shows empty data after migration.

### Pitfall 3: Tests Still Reference Dropped Fields

**What goes wrong:** `PlayerTests.swift` contains `playerOptionalFields()` and `playerWithParentInfo()` tests that directly access `player.parentName`, `player.parentPhone`, and `player.parentEmail`. After the migration, these tests will not compile.

**Why it happens:** Tests were written for the old model shape and must be updated in lockstep with the model.

**How to avoid:** Update `PlayerTests.swift` as part of this phase — delete the three parent-field tests, write replacements that verify the new fields (`phoneNumber` and `contactIdentifiers`).

**Warning signs:** Build failure in `PigeonPlayTests` after Player.swift is updated.

### Pitfall 4: PlayerFormView.swift Left Referencing Dropped Fields

**What goes wrong:** `PlayerFormView.swift` reads and writes `player.parentName`, `player.parentPhone`, `player.parentEmail` in both `onAppear` and `save()`. These references will not compile after the field removal.

**Why it happens:** View code was tightly coupled to the old model shape.

**How to avoid:** As part of this phase, strip the parent contact section from `PlayerFormView`. Do NOT add the new contacts UI yet — that is Phase 2's responsibility. The form section should simply be removed in this phase, leaving the view cleaner than it started.

**Warning signs:** Build errors in `PlayerFormView.swift` after `Player.swift` is updated.

---

## Code Examples

### Current Player Model (V1 — verbatim snapshot for migration)

```swift
// Source: PigeonPlay/Models/Player.swift (current state as of research date)
@Model
final class Player {
    var name: String
    var gender: Gender
    var defaultMatching: GenderMatching?
    var parentName: String?
    var parentPhone: String?
    var parentEmail: String?
    // ... effectiveMatching computed property ...
}
```

### Target Player Model (V2 — live model after migration)

```swift
// PigeonPlay/Models/Player.swift (post-migration)
import Foundation
import SwiftData

@Model
final class Player {
    var name: String
    var gender: Gender
    var defaultMatching: GenderMatching?
    var phoneNumber: String?
    var contactIdentifiers: [String]

    var effectiveMatching: GenderMatching {
        switch gender {
        case .b: .bx
        case .g: .gx
        case .x: defaultMatching ?? .bx
        }
    }

    init(
        name: String,
        gender: Gender,
        defaultMatching: GenderMatching? = nil,
        phoneNumber: String? = nil,
        contactIdentifiers: [String] = []
    ) {
        self.name = name
        self.gender = gender
        self.defaultMatching = defaultMatching
        self.phoneNumber = phoneNumber
        self.contactIdentifiers = contactIdentifiers
    }
}
```

### Updated modelContainer Call

```swift
// PigeonPlayApp.swift
.modelContainer(
    for: [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self],
    migrationPlan: PlayerMigrationPlan.self
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Direct `@Model` field removal without migration | `VersionedSchema` + `SchemaMigrationPlan` with `MigrationStage.lightweight` | SwiftData introduced iOS 17 | Any field change on shipped models requires explicit versioning |
| `NSPersistentStoreDescription` migration config (Core Data) | `SchemaMigrationPlan` passed to `modelContainer` initializer | SwiftData debut (iOS 17) | Simpler API, no need for separate migration mapping files |

**Deprecated/outdated:**
- Core Data `NSManagedObjectModel` version bundles: Not applicable here, but a common mistake is to look up Core Data migration docs when solving SwiftData migration problems. The APIs are entirely different.

---

## Runtime State Inventory

> This phase modifies a SwiftData model — the data store is runtime state.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | SwiftData SQLite store on device; existing `Player` rows have `parentName`, `parentPhone`, `parentEmail` columns and no `phoneNumber`/`contactIdentifiers` columns | Lightweight migration drops old columns and adds new ones automatically on first launch post-upgrade |
| Live service config | None — local SwiftData store only, no external services | None |
| OS-registered state | None — no scheduled tasks or background registrations reference Player fields | None |
| Secrets/env vars | None — no env vars reference Player field names | None |
| Build artifacts | Worktrees at `.worktrees/robin/link-contacts-to-players`, `.worktrees/robin/end-game-confirmation`, `.worktrees/robin/high-prio-refactors` contain old `Player.swift` and `PlayerTests.swift` with parent fields | These are separate git worktrees; changes in main branch do not affect them automatically. Worktree work should be rebased after this phase ships. |

**Data loss note:** The user confirmed in project decisions that loss of existing `parentName`/`parentPhone`/`parentEmail` data is acceptable. The lightweight migration will silently drop these columns — existing values are not migrated to new fields because there is no corresponding new field.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is code/model changes only. No external tools, CLIs, services, or runtimes beyond the existing Xcode/Swift toolchain are required. The toolchain is already confirmed operational (existing tests pass, project builds).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test` macro, Xcode 16) |
| Config file | Embedded in Xcode project (`PigeonPlayTests` target) |
| Quick run command | `xcodebuild test -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PigeonPlayTests/PlayerTests` |
| Full suite command | `xcodebuild test -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCHEMA-01 | `Player` model compiles with `VersionedSchema`; `modelContainer` accepts `migrationPlan:` | Build verification | Full suite command (build success = pass) | ❌ Wave 0 — test for migration plan presence |
| SCHEMA-02 | `parentName`, `parentPhone`, `parentEmail` do not exist on `Player` type | Unit (compile-time) | `xcodebuild build` — compile error if fields exist | ✅ existing `PlayerTests` must be updated to remove these field accesses |
| SCHEMA-03 | `Player.phoneNumber: String?` can be set and persisted | Unit | `PigeonPlayTests/PlayerTests` — `playerNewFields` test | ❌ Wave 0 |
| SCHEMA-04 | `Player.contactIdentifiers: [String]` defaults to `[]`, can be appended | Unit | `PigeonPlayTests/PlayerTests` — `playerContactIdentifiers` test | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Build + `PlayerTests` target only
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `PigeonPlayTests/PlayerTests.swift` — delete `playerOptionalFields` and `playerWithParentInfo` tests (reference dropped fields), add `playerNewFields` (SCHEMA-03) and `playerContactIdentifiers` (SCHEMA-04)
- [ ] No new test infrastructure needed — Swift Testing framework already configured

---

## Project Constraints (from CLAUDE.md)

| Directive | Source | Impact on This Phase |
|-----------|--------|----------------------|
| Use `gsd` skill for all work | CLAUDE.md | Work must proceed through GSD workflow (already doing so) |
| Always work on branches in git worktrees | CLAUDE.md | Phase must be executed in a worktree, not on main |
| Never commit straight to `main` | Global CLAUDE.md | All changes via PR |
| Red/Green TDD for new features | Global CLAUDE.md | Write failing tests for `phoneNumber` and `contactIdentifiers` before adding fields |
| Swift 6.0 enforced | Project CLAUDE.md | All new code must compile under Swift 6 strict concurrency — no issue for model-only changes |
| iOS 18.0 minimum deployment target | Project CLAUDE.md | SwiftData `VersionedSchema` (iOS 17+) is fully supported |
| No third-party dependencies | Project CLAUDE.md | Not relevant — this phase uses only SwiftData |
| 4-space indentation | Project CLAUDE.md | Standard Swift convention — follow in all new/modified files |
| `@Model final class` pattern | Project CLAUDE.md | V2 Player must use `@Model final class Player` |
| Enums with static methods for services | Project CLAUDE.md | Not applicable to this phase (model-only) |

---

## Open Questions

1. **PlayerSchemaV1 enum type naming collision**
   - What we know: `PlayerSchemaV1` defines a nested `Player` class; the main module also has `Player`. Swift resolves by scope, but using `PigeonPlay.Gender` inside `PlayerSchemaV1.Player` requires the fully qualified name to avoid ambiguity.
   - What's unclear: Whether the nested `@Model` class inside the V1 enum can reuse `Gender` and `GenderMatching` without qualification, or whether Swift 6 strict concurrency adds any wrinkle.
   - Recommendation: Reference `PigeonPlay.Gender` and `PigeonPlay.GenderMatching` explicitly inside `PlayerSchemaV1.Player` to be safe. If the compiler complains, use `typealias` inside the enum.

2. **modelContainer error handling for migration failure**
   - What we know: The current `PigeonPlayApp.swift` uses `.modelContainer(for:)` with no error handling. If migration fails, the app will crash silently.
   - What's unclear: Whether adding a `do/catch` around `ModelContainer` construction is worth the complexity for a development-audience app.
   - Recommendation: For this phase (development audience only), no error handling is required. Document as a known gap if the app ever goes to TestFlight/App Store.

---

## Sources

### Primary (HIGH confidence)

- Apple Developer Documentation — [SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan) — migration plan API
- Apple Developer Documentation — [VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema) — schema versioning API
- STACK.md (project-level research, 2026-03-22) — SwiftData migration patterns
- PITFALLS.md (project-level research, 2026-03-22) — V1 registration requirement, lightweight migration scope
- ARCHITECTURE.md (project-level research, 2026-03-22) — build order, file structure, migration code examples

### Secondary (MEDIUM confidence)

- [Lightweight vs complex migrations — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/lightweight-vs-complex-migrations) — what qualifies as lightweight (verified against Apple forums)
- [How to create a complex migration using VersionedSchema — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema)
- [Never use SwiftData without VersionedSchema — Mert Bulan](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema)
- [SwiftData unversioned migration crash — Apple Developer Forums](https://developer.apple.com/forums/thread/761735)

### Code Inspection (HIGH confidence — current codebase)

- `PigeonPlay/Models/Player.swift` — confirmed current field shape (6 fields, no VersionedSchema)
- `PigeonPlay/App/PigeonPlayApp.swift` — confirmed current `modelContainer` call has no `migrationPlan:`
- `PigeonPlayTests/PlayerTests.swift` — confirmed 3 tests reference dropped fields
- `PigeonPlay/Views/Roster/PlayerFormView.swift` — confirmed 6 references to parent fields that must be removed

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — SwiftData migration APIs verified against Apple docs; no third-party libraries involved
- Architecture: HIGH — Migration pattern drawn from project-level architecture research plus direct code inspection
- Pitfalls: HIGH — V1-registration pitfall confirmed in Apple Developer Forums; field-default pitfall confirmed in community sources cross-referenced against docs

**Research date:** 2026-03-22
**Valid until:** 2026-09-22 (SwiftData APIs are stable; unlikely to change)
