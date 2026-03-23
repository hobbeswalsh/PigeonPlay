---
phase: 02-service-and-permissions
plan: 01
subsystem: ui
tags: [swift, swiftui, contactsui, uikit-bridge, uiviewcontrollerrepresentable]

requires:
  - phase: 01-schema-migration
    provides: Player.contactIdentifiers [String] field in live model

provides:
  - ContactPickerRepresentable: UIViewControllerRepresentable wrapping CNContactPickerViewController in UINavigationController
  - Coordinator class implementing CNContactPickerDelegate, passing contact.identifier (String) to onSelect closure
  - NSContactsUsageDescription plist key in project.yml preventing Phase 3 crash

affects: [02-02-player-form-contacts, 03-contact-service]

tech-stack:
  added: [ContactsUI framework, Contacts framework]
  patterns:
    - UIViewControllerRepresentable with Coordinator class for UIKit-to-SwiftUI bridging
    - Delegate assigned to context.coordinator (class, not struct) for correct UIKit lifetime management
    - String identifier extraction in delegate callback (not CNContact) for Swift 6 Sendable compliance

key-files:
  created:
    - PigeonPlay/Views/Roster/ContactPickerRepresentable.swift
    - PigeonPlayTests/ContactPickerRepresentableTests.swift
  modified:
    - project.yml

key-decisions:
  - "Coordinator pattern on class (not struct) required because UIKit holds delegate weakly — value type would be deallocated immediately"
  - "UINavigationController wrapper around CNContactPickerViewController is mandatory — bare picker produces empty sheet (documented UIKit quirk)"
  - "Pass String (contact.identifier) not CNContact across closure boundary — CNContact is not Sendable, Swift 6 strict concurrency enforces this"
  - "NSContactsUsageDescription added in Phase 2 before any CNContactStore code — prevents crash when Phase 3 adds store access"

patterns-established:
  - "UIKit bridge pattern: ContactPickerRepresentable is the first UIViewControllerRepresentable in this codebase; future UIKit bridges should follow the same Coordinator-class pattern"

requirements-completed: [PICKER-01, PERM-01]

duration: 8min
completed: 2026-03-23
---

# Phase 2 Plan 01: ContactPickerRepresentable and NSContactsUsageDescription Summary

**CNContactPickerViewController UIKit bridge via UIViewControllerRepresentable with UINavigationController wrapper, Coordinator delegate class passing contact.identifier, and NSContactsUsageDescription plist key for Phase 3 CNContactStore access**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-23T04:51:24Z
- **Completed:** 2026-03-23T04:59:07Z
- **Tasks:** 2
- **Files modified:** 4 (ContactPickerRepresentable.swift, ContactPickerRepresentableTests.swift, project.yml, project.pbxproj)

## Accomplishments
- ContactPickerRepresentable struct correctly wraps CNContactPickerViewController in UINavigationController (avoids empty-sheet UIKit bug)
- Coordinator class holds CNContactPickerDelegate; contactPicker(_:didSelect:) extracts contact.identifier (String) and passes to onSelect closure
- Two unit tests verify coordinator callback wiring and cancel-no-op behavior; both pass under Swift 6 strict concurrency
- NSContactsUsageDescription added to project.yml PigeonPlay target settings.base before any CNContactStore code is written

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Failing tests** - `7694cff` (test)
2. **Task 1 GREEN: ContactPickerRepresentable implementation** - `880935a` (feat)
3. **Task 2: NSContactsUsageDescription in project.yml** - `b02e320` (chore)

## Files Created/Modified
- `PigeonPlay/Views/Roster/ContactPickerRepresentable.swift` - UIViewControllerRepresentable bridge for CNContactPickerViewController; Coordinator class with CNContactPickerDelegate
- `PigeonPlayTests/ContactPickerRepresentableTests.swift` - Unit tests for Coordinator: onSelect invoked with contact.identifier, cancel does not invoke onSelect
- `project.yml` - Added INFOPLIST_KEY_NSContactsUsageDescription to PigeonPlay target settings.base
- `PigeonPlay.xcodeproj/project.pbxproj` - Regenerated via xcodegen to include new source files

## Decisions Made
- Used `@MainActor` annotation on test functions because `CNContactPickerViewController()` init is main-actor isolated — Swift 6 strict concurrency requires this in test code
- Placed NSContactsUsageDescription after GENERATE_INFOPLIST_FILE and before other INFOPLIST_KEY_ entries for logical grouping

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added @MainActor to test functions**
- **Found during:** Task 1 RED (writing test file)
- **Issue:** Swift compiler warned that `CNContactPickerViewController()` init is main-actor isolated and cannot be called from synchronous nonisolated context
- **Fix:** Added `@MainActor` attribute to both `@Test` functions in ContactPickerRepresentableTests.swift
- **Files modified:** PigeonPlayTests/ContactPickerRepresentableTests.swift
- **Verification:** Build succeeds with no warnings, tests pass
- **Committed in:** 7694cff (RED commit, updated before pushing)

---

**Total deviations:** 1 auto-fixed (missing @MainActor for Swift 6 compliance)
**Impact on plan:** Required for compilation under Swift 6 strict concurrency. No scope creep.

## Issues Encountered
- No iPhone 16 simulator present (OS 26.2 devices only available); used iPhone 16e simulator instead. Tests pass identically.
- First `xcodebuild test -only-testing:...` run before XcodeGen regeneration reported 0 tests run (stale project not including new file); resolved by running `xcodegen generate` first.

## Next Phase Readiness
- ContactPickerRepresentable is ready for Plan 02 integration into PlayerFormView via `.sheet(isPresented:)`
- NSContactsUsageDescription is in place; Phase 3 CNContactStore access will not crash on first run
- No blockers

---
*Phase: 02-service-and-permissions*
*Completed: 2026-03-23*
