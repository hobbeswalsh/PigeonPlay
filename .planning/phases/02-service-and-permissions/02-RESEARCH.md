# Phase 2: Contact Picker - Research

**Researched:** 2026-03-22
**Domain:** iOS ContactsUI / CNContactPickerViewController integration in SwiftUI
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Contacts appear as a new Form section ("Contacts") below "Player Info" in PlayerFormView
- **D-02:** Player's own phone number is a TextField in the "Player Info" section, after gender/matching fields
- **D-03:** "Add Contact" is a button row at the bottom of the Contacts section with a plus icon
- **D-04:** Tapping "Add Contact" opens CNContactPickerViewController via UIViewControllerRepresentable
- **D-05:** Each linked contact shows name only (no phone preview) in Phase 2 — Phase 3 adds live data display
- **D-06:** Swipe-to-delete removes a linked contact from the player

### Claude's Discretion

- CNContactPickerViewController wrapping approach (UIViewControllerRepresentable vs UINavigationController wrapper)
- Whether to show contact count badge on PlayerRow in the roster list
- Contact picker configuration (single vs multi-select, which contact properties to request)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PICKER-01 | CNContactPickerViewController wrapped as SwiftUI view via UIViewControllerRepresentable | Pattern 2 (UINavigationController wrapper) — see Architecture Patterns below |
| PICKER-02 | User can link one or more iOS Contacts to a player from the player edit form | Coordinator `contactPicker(_:didSelect:)` appends identifier to `player.contactIdentifiers`; no authorization required before picker presentation |
| PICKER-03 | User can unlink a previously linked contact from a player | SwiftUI `List` with `.onDelete` removes the identifier from `player.contactIdentifiers`; existing `RosterView` uses this exact pattern |
| PERM-01 | NSContactsUsageDescription set in Info.plist/project.yml | Add `INFOPLIST_KEY_NSContactsUsageDescription` to the `settings.base` block of the `PigeonPlay` target in `project.yml` |

</phase_requirements>

---

## Summary

Phase 1 delivered `Player.contactIdentifiers: [String]` and `Player.phoneNumber: String?` in the live model, along with the V1→V2 migration infrastructure. Phase 2's job is entirely in the UIKit-bridge and view layers — no model changes are needed. The migration is already done.

The three implementation tasks are: (1) wrap `CNContactPickerViewController` in a `UIViewControllerRepresentable` so SwiftUI can present it as a sheet; (2) add the "Contacts" section and phone number field to `PlayerFormView`; (3) add `NSContactsUsageDescription` to `project.yml`. There are no tricky authorization flows for this phase because `CNContactPickerViewController` is an out-of-process picker that requires zero upfront permission — the permission system only comes into play in Phase 3 when live `CNContactStore` fetches are added.

The biggest technical trap for this phase is the empty-sheet bug: presenting `CNContactPickerViewController` directly from `makeUIViewController` produces a blank modal. The fix is to wrap it in a `UINavigationController`. This is a well-documented quirk, confirmed by multiple sources. The coordinator pattern for the delegate is the other mandatory detail — the delegate must be assigned to `context.coordinator` (a class), not to the `UIViewControllerRepresentable` struct (a value type that gets copied).

**Primary recommendation:** Implement `ContactPickerRepresentable` with a `UINavigationController` wrapper, wire the Coordinator as the `CNContactPickerDelegate`, and integrate into `PlayerFormView` using `.sheet(isPresented:)`. Add `INFOPLIST_KEY_NSContactsUsageDescription` to `project.yml` before writing any code that touches `CNContactStore`.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ContactsUI` (`import ContactsUI`) | iOS 9+ | `CNContactPickerViewController` — system contact picker | Only Apple-native way to present the system Contacts picker. Does not require authorization before use. |
| `Contacts` (`import Contacts`) | iOS 9+ | `CNContact`, `CNContactPickerDelegate` | Required for the delegate callback type signature. Identifier extraction happens here. |

No new package dependencies. Both frameworks ship with the iOS SDK.

### Supporting

| API | Purpose | When to Use |
|-----|---------|-------------|
| `CNContactPickerDelegate.contactPicker(_:didSelect:)` | Callback with the selected contact; extract `.identifier` here | Single-contact selection flow (Phase 2 default) |
| `CNContactPickerDelegate.contactPicker(_:didSelectContacts:)` | Callback with multiple contacts if multi-select is configured | Only if D-03/D-04 scope expands to multi-select; not required for Phase 2 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `UINavigationController` wrapper in `makeUIViewController` | Bare `CNContactPickerViewController` | Bare picker produces an empty sheet on current iOS — do not use |
| Single-select delegate (`didSelect contact:`) | Multi-select delegate (`didSelectContacts:`) | Multi-select adds complexity with no stated requirement; coach can tap "Add Contact" multiple times |

---

## Architecture Patterns

### Recommended File Structure (Phase 2 additions only)

```
PigeonPlay/Views/Roster/
├── PlayerFormView.swift           # Updated: add phone field + Contacts section
└── ContactPickerRepresentable.swift  # New: UIKit bridge for CNContactPickerViewController
```

No new service file in Phase 2. `ContactsService` is a Phase 3 concern (live `CNContactStore` fetches). Phase 2 only needs the picker wrapper and the view integration.

### Pattern 1: ContactPickerRepresentable (PICKER-01)

**What:** `UIViewControllerRepresentable` that presents `CNContactPickerViewController` wrapped in `UINavigationController`. The `Coordinator` class holds the picker delegate and calls back into SwiftUI via a closure.

**When to use:** Any time `CNContactPickerViewController` must be shown from SwiftUI.

**Recommended implementation:**

```swift
// Source: Apple ContactsUI docs + createwithswift.com (verified)
import ContactsUI
import SwiftUI

struct ContactPickerRepresentable: UIViewControllerRepresentable {
    var onSelect: (String) -> Void  // hands back CNContact.identifier

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // UINavigationController wrapper required — bare picker shows empty sheet
        return UINavigationController(rootViewController: picker)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var onSelect: (String) -> Void
        init(onSelect: @escaping (String) -> Void) { self.onSelect = onSelect }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact.identifier)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // Picker dismisses itself; no action needed
        }
    }
}
```

**Note on callback type:** The closure passes `String` (identifier only), not `CNContact`. This prevents retaining a non-`Sendable` `CNContact` across actor boundaries in Swift 6.

### Pattern 2: Contacts Section in PlayerFormView (PICKER-02, PICKER-03)

**What:** A new `Section("Contacts")` in the existing `Form` body. Shows linked contacts by identifier-derived display name (Phase 2: name only, resolved via `CNContactStore` only for display purposes — or deferred entirely to Phase 3). An "Add Contact" button row at the bottom of the section opens the picker as a sheet. Swipe-to-delete removes identifiers.

**Key decision:** D-05 says "name only, no phone preview." The question is where the name comes from. Two options:

1. **Store-free approach (recommended for Phase 2):** Display a placeholder label ("Linked Contact") or the raw identifier suffix until Phase 3 resolves names. This keeps Phase 2 strictly within scope — no `CNContactStore` access required, no authorization flow required.
2. **Eager resolution:** Fetch names on appear via `CNContactStore`. This requires `NSContactsUsageDescription`, authorization handling, and async state management — all of which overlap with Phase 3 requirements (DISPLAY-01, PERM-02, PERM-03).

**Recommendation:** Display a generic row label in Phase 2 — the linked contact count and swipe-to-delete work without resolving names. This keeps Phase 2 narrowly scoped. A "Linked Contact" placeholder is acceptable since D-05 explicitly defers live data to Phase 3.

If the planner wants Phase 2 to show resolved names, note that it requires `CNContactStore.authorizationStatus` + `requestAccess` logic — that is Phase 3 scope per REQUIREMENTS.md (PERM-02).

**Form integration sketch:**

```swift
// In PlayerFormView body, new section after "Player Info"
Section("Contacts") {
    ForEach(contactIdentifiers, id: \.self) { identifier in
        Text("Linked Contact")   // Phase 3 resolves real name
            .foregroundStyle(.secondary)
    }
    .onDelete { offsets in
        contactIdentifiers.remove(atOffsets: offsets)
    }
    Button {
        showContactPicker = true
    } label: {
        Label("Add Contact", systemImage: "plus")
    }
}
.sheet(isPresented: $showContactPicker) {
    ContactPickerRepresentable { identifier in
        if !contactIdentifiers.contains(identifier) {
            contactIdentifiers.append(identifier)
        }
        showContactPicker = false
    }
}
```

**State management:** `contactIdentifiers` is a local `@State` copy initialized from `player.contactIdentifiers` on `.onAppear`. The copy is written back to the model in `save()`. This follows the existing `PlayerFormView` pattern (name, gender, defaultMatching are all local `@State` copies).

**Duplicate prevention:** Check `contactIdentifiers.contains(identifier)` before appending. A player could theoretically tap "Add Contact" and select the same contact twice.

### Pattern 3: NSContactsUsageDescription in project.yml (PERM-01)

**What:** XcodeGen generates Info.plist from settings in `project.yml`. The privacy string is added under `settings.base` of the `PigeonPlay` target using the `INFOPLIST_KEY_` prefix.

**Where in project.yml:**

```yaml
targets:
  PigeonPlay:
    settings:
      base:
        INFOPLIST_KEY_NSContactsUsageDescription: "PigeonPlay uses your contacts to link parents and guardians to players on your roster."
```

**Why now:** Even though `CNContactPickerViewController` requires no authorization, `CNContactStore` fetches (Phase 3) will crash the app immediately if this key is absent. Adding it in Phase 2 ensures it is in place before any store access is written.

### Anti-Patterns to Avoid

- **Delegate on the struct:** `CNContactPickerDelegate` must be implemented on a `class` (`Coordinator`), not on the `UIViewControllerRepresentable` struct. Structs are value types; UIKit holds the delegate weakly and the struct would be deallocated.
- **Bare picker without UINavigationController:** Returns an empty modal sheet. Always wrap.
- **Requesting authorization before showing picker:** `CNContactPickerViewController` is an out-of-process picker. No authorization is required. A `requestAccess` call before the picker is misleading and wasteful.
- **Storing CNContact across actor boundaries:** Swift 6 strict concurrency rejects `CNContact` (not `Sendable`) passed between actors. Extract the identifier in the delegate callback and pass only `String`.
- **Putting ContactsService in this phase:** Phase 2 does not read from `CNContactStore`. The service belongs in Phase 3.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| System contact picker UI | Custom contact list/search view | `CNContactPickerViewController` | System picker is privacy-compliant, works without authorization, is maintained by Apple, handles search/filtering, is localized |
| SwiftUI sheet bridge for UIKit view controllers | Manual `UIWindow` manipulation | `UIViewControllerRepresentable` | Standard pattern for all UIKit-to-SwiftUI bridging |

---

## Runtime State Inventory

Step 2.5: SKIPPED — This is not a rename/refactor/migration phase. Phase 1 already completed the data migration. Phase 2 adds only new UI and a plist key; it does not change identifiers, keys, or stored state that would require a runtime inventory.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 2 has no external service or CLI dependencies. All required APIs (`ContactsUI`, `Contacts`) are part of the iOS SDK. The only tooling required is Xcode (already in use) and XcodeGen for `project.yml` regeneration.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Xcode 15+ with iOS 18 SDK | All Swift 6.0 compilation | Implied by existing project | Already in use |
| XcodeGen | `project.yml` → `.xcodeproj` regeneration | Assumed present | Used to add `NSContactsUsageDescription` |

---

## Common Pitfalls

### Pitfall 1: Empty Picker Sheet (Missing UINavigationController Wrapper)

**What goes wrong:** `CNContactPickerViewController` presented directly from `makeUIViewController` shows an empty modal with no contacts.

**Why it happens:** UIKit quirk specific to this view controller. It needs a navigation controller parent to render its content.

**How to avoid:** Return `UINavigationController(rootViewController: picker)` from `makeUIViewController`, not the picker directly.

**Warning signs:** Picker sheet appears but shows no contacts, or shows a blank gray sheet.

### Pitfall 2: Delegate Fires on Wrong Object / Never Fires

**What goes wrong:** Contact selection callback never fires, or fires and then crashes due to a dangling reference.

**Why it happens:** Delegate assigned to the `UIViewControllerRepresentable` struct (value type, not retained) instead of the `Coordinator` (class instance, retained by the representable).

**How to avoid:** Assign `picker.delegate = context.coordinator` inside `makeUIViewController`. The `Coordinator` class is retained for the lifetime of the representable.

**Warning signs:** Tapping a contact dismisses the picker but `onSelect` is never called.

### Pitfall 3: Swift 6 Concurrency Error on CNContact

**What goes wrong:** Compiler error: `'CNContact' is not Sendable` or `sending value of non-Sendable type across actor boundary`.

**Why it happens:** `CNContact` is a reference type that is not marked `Sendable`. Passing it from the delegate (UIKit main thread context) to a SwiftUI view update crossing actor boundaries triggers Swift 6 strict concurrency checks.

**How to avoid:** In the `Coordinator.contactPicker(_:didSelect:)` callback, extract `contact.identifier` (a `String`, which is `Sendable`) immediately and pass only the `String` via the closure.

**Warning signs:** Build error referencing `CNContact` and `@MainActor` or `Sendable`.

### Pitfall 4: Missing NSContactsUsageDescription Crashes Phase 3

**What goes wrong:** The app compiles and runs in Phase 2, but crashes in Phase 3 the moment any `CNContactStore` access is attempted.

**Why it happens:** iOS hard-crashes the app if `NSContactsUsageDescription` is absent when any Contacts store access is attempted — even from code added after the initial build.

**How to avoid:** Add `INFOPLIST_KEY_NSContactsUsageDescription` to `project.yml` in this phase, before any `CNContactStore` code is written.

**Warning signs:** Phase 3 test run produces `EXC_BAD_INSTRUCTION` or `Privacy - Contacts Usage Description` crash in the console.

### Pitfall 5: Duplicate Contact Identifiers

**What goes wrong:** Tapping "Add Contact" twice and selecting the same person adds the same identifier twice. Phase 3 live-fetch then shows two identical contact rows.

**Why it happens:** No deduplication guard in the append logic.

**How to avoid:** `if !contactIdentifiers.contains(identifier) { contactIdentifiers.append(identifier) }` in the picker callback.

---

## Code Examples

### ContactPickerRepresentable — Full Implementation

```swift
// Source: Apple ContactsUI documentation, createwithswift.com (verified pattern)
import ContactsUI
import SwiftUI

struct ContactPickerRepresentable: UIViewControllerRepresentable {
    var onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return UINavigationController(rootViewController: picker)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var onSelect: (String) -> Void
        init(onSelect: @escaping (String) -> Void) { self.onSelect = onSelect }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact.identifier)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {}
    }
}
```

### NSContactsUsageDescription in project.yml

```yaml
targets:
  PigeonPlay:
    type: application
    platform: iOS
    sources:
      - PigeonPlay
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_NSContactsUsageDescription: "PigeonPlay uses your contacts to link parents and guardians to players on your roster."
        # ... other existing keys
```

### Phone Number TextField in PlayerFormView

```swift
// In the "Player Info" Section, after the defaultMatching Picker
TextField("Phone", text: Binding(
    get: { phoneNumber ?? "" },
    set: { phoneNumber = $0.isEmpty ? nil : $0 }
))
.keyboardType(.phonePad)
```

Note: `phoneNumber` here is a local `@State private var phoneNumber: String?` initialized from `player?.phoneNumber` in `.onAppear`, and written back in `save()`.

### Duplicate Guard in Picker Callback

```swift
ContactPickerRepresentable { identifier in
    if !contactIdentifiers.contains(identifier) {
        contactIdentifiers.append(identifier)
    }
    showContactPicker = false
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ABAddressBook.framework` | `Contacts` + `ContactsUI` | iOS 9 / removed iOS 14 | No impact — project targets iOS 18 |
| Full upfront contacts authorization | Out-of-process picker (no auth required) | iOS 9 (`CNContactPickerViewController`) | Picker-first flow requires zero permission prompt — use this |
| iOS 17: only `.authorized`/`.denied`/`.notDetermined`/`.restricted` | iOS 18 adds `.limited` | iOS 18 | Only relevant in Phase 3 when `CNContactStore` fetches are added |

---

## Project Constraints (from CLAUDE.md)

- Swift 6.0 strict concurrency enforced — `CNContact` is not `Sendable`; extract identifier (`String`) in delegate callback immediately
- iOS 18.0 minimum deployment target — `CNAuthorizationStatus.limited` is available and must be handled in Phase 3; not in scope for Phase 2
- No third-party dependencies — use Apple's `Contacts` + `ContactsUI` frameworks only
- SwiftUI views are structs — UIKit delegates must live on Coordinator classes, not on the representable struct
- `@Model` classes use camelCase; no snake_case
- Use `@State private var` for ephemeral form state, `@Bindable` for model binding
- Tests use Swift Testing (`@Test` macro), not XCTest
- No `UIViewControllerRepresentable` pattern exists yet in this codebase — this is the first UIKit bridge

---

## Open Questions

1. **Contact name display in Phase 2 (D-05 interpretation)**
   - What we know: D-05 says "name only, no phone preview." The name must come from somewhere.
   - What's unclear: Does Phase 2 show resolved contact names (requiring `CNContactStore` + authorization handling), or a placeholder label until Phase 3?
   - Recommendation: Use a placeholder (e.g., "Linked Contact \(index + 1)") to keep Phase 2 strictly dependency-free. Phase 3 already has DISPLAY-01 and PERM-02 for live fetch. If the planner wants real names in Phase 2, the plan must include async `CNContactStore` access and `requestAccess` handling.

2. **Contact count badge on PlayerRow (Claude's Discretion)**
   - What we know: `player.contactIdentifiers.count` is trivially available.
   - What's unclear: Whether this is worth the visual noise in Phase 2, or if it should wait until contacts actually show useful data (Phase 3).
   - Recommendation: Omit in Phase 2. A badge of "2 contacts" is less useful than seeing the actual names (Phase 3). Keeps Phase 2 scope contained.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test` macro), Xcode 15+ |
| Config file | None (XcodeGen generates test bundle target; no separate config file) |
| Quick run command | `xcodebuild test -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcpretty` |
| Full suite command | Same (all tests are unit tests; no separate integration suite) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PICKER-01 | `ContactPickerRepresentable` compiles and conforms to `UIViewControllerRepresentable` | unit (compile-time verification) | Build target | ❌ Wave 0 — new file |
| PICKER-01 | `makeUIViewController` returns `UINavigationController` (not bare picker) | unit | `ContactPickerRepresentableTests` | ❌ Wave 0 |
| PICKER-01 | Coordinator conforms to `CNContactPickerDelegate` | unit (compile-time) | Build target | ❌ Wave 0 |
| PICKER-02 | `contactPicker(_:didSelect:)` invokes `onSelect` closure with `contact.identifier` | unit | `ContactPickerRepresentableTests` | ❌ Wave 0 |
| PICKER-02 | Selecting a contact appends identifier to `player.contactIdentifiers` | unit | `PlayerFormViewTests` or inline | ❌ Wave 0 |
| PICKER-02 | Selecting a duplicate contact does not append again | unit | `ContactPickerRepresentableTests` | ❌ Wave 0 |
| PICKER-03 | Removing an identifier from `contactIdentifiers` persists via save | unit | `PlayerFormViewTests` | ❌ Wave 0 |
| PERM-01 | `NSContactsUsageDescription` present in built Info.plist | build verification | `xcodebuild` + `PlistBuddy` check | ❌ Wave 0 (manual) |

Note: `PERM-01` is most practically verified by building the app and confirming the key in derived data. An automated test that reads the built Info.plist is possible but unusual — a simpler approach is a Wave 0 build-and-check step.

The `ContactPickerRepresentable` logic that can be tested in isolation:
- Coordinator's `onSelect` closure receives `contact.identifier`
- Duplicate guard in the append logic

View-level integration (sheet presentation, row display, swipe-to-delete) is best verified manually in the simulator for Phase 2 since the project does not have a UI testing target.

### Sampling Rate

- **Per task commit:** Build the scheme (confirms Swift 6 concurrency compliance)
- **Per wave merge:** Full unit test suite
- **Phase gate:** Full suite green + manual simulator verification of picker flow before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `PigeonPlayTests/ContactPickerRepresentableTests.swift` — covers PICKER-01 coordinator behavior, PICKER-02 callback and duplicate guard
- [ ] `PigeonPlayTests/PlayerFormContactsTests.swift` — covers PICKER-02 (append), PICKER-03 (remove)

*(Existing `PlayerTests.swift` already covers `player.contactIdentifiers` at the model level — no changes needed there.)*

---

## Sources

### Primary (HIGH confidence)

- [CNContactPickerViewController — Apple Developer Documentation](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller) — delegate methods, no-auth-required behavior, UINavigationController requirement confirmed
- [CNContact.identifier — Apple Developer Documentation](https://developer.apple.com/documentation/contacts/cncontact/1403103-identifier) — identifier stability
- [Meet the Contact Access Button — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10121/) — CNContactPickerViewController vs ContactAccessButton distinction confirmed

### Secondary (MEDIUM confidence)

- [Contact Management: Working with CNContactPickerViewController — createwithswift.com](https://www.createwithswift.com/contact-management-working-with-the-contact-picker-view-controller/) — UINavigationController wrapper pattern, coordinator pattern
- [ContactPicker in SwiftUI — Sharath Sriram](https://sharaththegeek.substack.com/p/contactpicker-in-swiftui) — UIViewControllerRepresentable coordinator pattern

### Codebase (HIGH confidence — direct inspection)

- `PigeonPlay/Models/Player.swift` — confirmed `contactIdentifiers: [String]` and `phoneNumber: String?` exist in live model
- `PigeonPlay/Models/PlayerMigration.swift` — confirmed V1/V2 migration infrastructure complete; no further model work needed in Phase 2
- `PigeonPlay/App/PigeonPlayApp.swift` — confirmed `ModelContainer` uses `PlayerMigrationPlan`
- `PigeonPlay/Views/Roster/PlayerFormView.swift` — confirmed Form/Section structure, `@State` pattern for form fields, `save()` writes back to model
- `project.yml` — confirmed `GENERATE_INFOPLIST_FILE: YES`; `INFOPLIST_KEY_NSContactsUsageDescription` is absent (needs to be added)
- `PigeonPlayTests/PlayerTests.swift` — confirmed Swift Testing (`@Test` macro); no UIKit or ContactsUI tests exist yet

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — both frameworks are Apple-native; no packages to version
- Architecture: HIGH — `UIViewControllerRepresentable` + Coordinator is the canonical SwiftUI/UIKit bridge pattern, confirmed against Apple docs; `UINavigationController` wrapper requirement confirmed against multiple sources
- Pitfalls: HIGH — empty-sheet bug and delegate pattern confirmed by Apple Developer Forums; Swift 6 `Sendable` constraint is a compile-time guarantee

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (stable Apple APIs; no foreseeable churn)
