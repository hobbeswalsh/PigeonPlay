# Phase 3: Contact Display and Actions - Research

**Researched:** 2026-03-23
**Domain:** iOS Contacts live fetch, communication URL schemes, permission gating in SwiftUI
**Confidence:** HIGH — all findings verified against Apple official documentation and prior milestone research artifacts

---

<user_constraints>
## User Constraints (from CONTEXT.md)

No CONTEXT.md exists for Phase 3 yet. The following constraints are carried forward from Phase 2 locked decisions and project-level decisions recorded in STATE.md and REQUIREMENTS.md.

### Locked Decisions (carried from Phase 2 / project level)

- **Live reference only** — always fetch contact data from CNContactStore; no snapshots in SwiftData
- **No relationship labels** — coaches just need to reach people; label complexity is out of scope
- `Player.contactIdentifiers: [String]` stores CNContact IDs (Phase 1, already shipped)
- `ContactPickerRepresentable` exists and is complete (Phase 2, already shipped)
- `NSContactsUsageDescription` is already in `project.yml` (Phase 2, already shipped)
- `PlayerFormView` shows placeholder "Linked Contact" text per contact ID — Phase 3 replaces these with live names

### Claude's Discretion

- Layout and visual design of the contact display row (ContactRowView)
- Whether live contact data is fetched in PlayerFormView or a separate detail view
- Exact permission denial UI (alert vs. inline message vs. banner)
- How loading state is presented while contacts are being fetched
- Whether ContactsService is introduced as a standalone file or inline in the view

### Deferred Ideas (OUT OF SCOPE)

- IOS18-01: ContactAccessButton for inline contact search/grant flow
- IOS18-02: CNAuthorizationStatus.limited handling with ContactAccessButton
- COMM-01: Group messaging or bulk communication to multiple contacts
- Contact search/filtering in-app
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DISPLAY-01 | Linked contacts show name, phone, and email fetched live from CNContactStore | `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)` with keys `[.givenName, .familyName, .phoneNumbers, .emailAddresses]`; run async in `.task` |
| DISPLAY-02 | User can tap to call a linked contact's phone number | `@Environment(\.openURL)` with `URL(string: "tel://\(digits)")` — strip non-digits before constructing |
| DISPLAY-03 | User can tap to send a text to a linked contact's phone number | `@Environment(\.openURL)` with `URL(string: "sms://\(digits)")` |
| DISPLAY-04 | User can tap to email a linked contact's email address | `@Environment(\.openURL)` with `URL(string: "mailto:\(address)")` |
| DISPLAY-05 | Deleted or inaccessible contacts display graceful fallback (not a crash) | Catch `CNErrorCodeRecordDoesNotExist`; show "Contact no longer available" inline |
| PERM-02 | App requests Contacts authorization before CNContactStore access | `CNContactStore.authorizationStatus(for: .contacts)` → request if `.notDetermined`; gate fetch on result |
| PERM-03 | Denied/restricted authorization state shows user guidance | Show inline message with Settings deep-link when status is `.denied` or `.restricted` |
</phase_requirements>

---

## Summary

Phase 3 builds on the completed Phase 2 infrastructure. The picker is done, identifiers are stored, the placeholder "Linked Contact" text is in place. This phase replaces those placeholders with live-fetched data and wires up all communication actions.

The core work is three things: (1) a `ContactsService` enum (static async methods, consistent with `LineSuggester`) that handles all `CNContactStore` interaction and authorization gating; (2) replacing the placeholder `ForEach` in `PlayerFormView`'s Contacts section with rows that display real name/phone/email and tappable action buttons; (3) correct permission handling — check auth status, request if undetermined, show Settings guidance if denied.

There is no new view file strictly required. The contact display can live as a `ContactRowView` struct in the same file as `PlayerFormView`, consistent with the project's pattern of colocating helper views (e.g., `PlayerRow` in `RosterView.swift`). A `ContactsService.swift` file in `Services/` is the one new file this phase requires.

**Primary recommendation:** Introduce `ContactsService` as the single choke-point for all `CNContactStore` access, replace the placeholder rows in `PlayerFormView` with async-loaded `ContactRowView` rows, and use `@Environment(\.openURL)` for all three communication actions.

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| `Contacts` (`import Contacts`) | iOS 9+ | Live fetch by identifier via `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)` | The only Apple-native way to read address book data. Already an implicit dependency from Phase 2. |
| `@Environment(\.openURL)` | iOS 14+ | Tap-to-call, tap-to-text, tap-to-email | Zero additional frameworks; dispatches to system Phone/Messages/Mail apps. App already targets iOS 18. |
| Swift `async`/`await` | Swift 5.5+ / iOS 15+ | Off-main-thread contact fetches | `CNContactStore` fetch methods block; must be dispatched off the main actor to avoid UI freeze. |

### Supporting

| API | Version | Purpose | When to Use |
|-----|---------|---------|-------------|
| `CNContactStore.authorizationStatus(for: .contacts)` | iOS 9+ | Synchronous status check | Before every fetch attempt — gate on result |
| `CNContactStore().requestAccess(for: .contacts) async` | iOS 9+ | Request authorization | Only when status is `.notDetermined` |
| `CNContactGivenNameKey`, `CNContactFamilyNameKey`, `CNContactPhoneNumbersKey`, `CNContactEmailAddressesKey` | iOS 9+ | The four keys needed for display | Fetch exactly these, nothing more |
| `CNLabeledValue<CNPhoneNumber>` | iOS 9+ | Phone number container within `CNContact.phoneNumbers` | Access `.value.stringValue` for the raw number string |
| `UIApplication.shared.open(_:)` | iOS 2+ | Programmatic URL dispatch (alternative to openURL env) | When `Button` action needs conditional logic before opening; `openURL` environment is preferred for simplicity |

### No New Package Dependencies

This phase requires no changes to package dependencies. Add `import Contacts` to new service and view files.

---

## Architecture Patterns

### Recommended Project Structure

```
PigeonPlay/
├── Services/
│   ├── LineSuggester.swift          # Unchanged
│   └── ContactsService.swift        # NEW: all CNContactStore interaction
├── Views/
│   └── Roster/
│       ├── RosterView.swift         # Unchanged
│       ├── PlayerFormView.swift     # UPDATED: replace placeholder rows
│       │                            #   ContactRowView collocated here (see below)
│       └── ContactPickerRepresentable.swift  # Unchanged
```

`ContactRowView` does not need its own file. It is a small display struct — colocate it in `PlayerFormView.swift`, following the same pattern as `PlayerRow` in `RosterView.swift`.

### Pattern 1: ContactsService — Enum with Static Async Methods

**What:** A stateless service wrapping all `CNContactStore` interaction: authorization check, authorization request, and fetch by identifier array. Consistent with `LineSuggester` (enum, static methods, no `@Observable`).

**When to use:** Any view that needs to display contact data or check permission status calls this service. Views never import `Contacts` or instantiate `CNContactStore` directly.

**Example:**
```swift
// Source: Apple CNContactStore docs + LineSuggester pattern in codebase
import Contacts

enum ContactsService {

    // All keys the app will ever access — defined once, shared everywhere
    static let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
    ]

    static func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    // Returns true if access was granted, false if denied/restricted
    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        return (try? await store.requestAccess(for: .contacts)) ?? false
    }

    // Returns successfully fetched contacts; skips identifiers that no longer exist
    static func fetchContacts(identifiers: [String]) async -> [ContactResult] {
        guard !identifiers.isEmpty else { return [] }
        let store = CNContactStore()
        return identifiers.compactMap { id in
            do {
                let contact = try store.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)
                return .found(contact)
            } catch let error as CNError where error.code == .recordDoesNotExist {
                return .notFound(id)
            } catch {
                return .notFound(id)
            }
        }
    }
}

enum ContactResult {
    case found(CNContact)
    case notFound(String)  // identifier that could not be resolved
}
```

**Why `ContactResult` instead of `[CNContact]`:** DISPLAY-05 requires graceful fallback for deleted contacts. If we silently drop missing contacts (returning `[CNContact]`), the view cannot distinguish "0 contacts" from "contact was deleted." `ContactResult` lets the view render a "no longer available" row for each missing identifier.

### Pattern 2: Async Fetch in `.task` with Loading State

**What:** Fetch contacts asynchronously when the contacts section appears, using `.task` (not `.onAppear`) so SwiftUI manages cancellation automatically.

**When to use:** In `PlayerFormView` wherever contact rows are rendered.

**Example:**
```swift
// In PlayerFormView
@State private var contactResults: [ContactResult] = []
@State private var contactsAuthStatus: CNAuthorizationStatus = .notDetermined
@State private var isLoadingContacts = false

// On the Section or a parent view:
.task(id: contactIdentifiers) {
    await loadContacts()
}

private func loadContacts() async {
    guard !contactIdentifiers.isEmpty else {
        contactResults = []
        return
    }
    let status = ContactsService.authorizationStatus()
    if status == .notDetermined {
        let granted = await ContactsService.requestAccess()
        contactsAuthStatus = granted ? .authorized : .denied
    } else {
        contactsAuthStatus = status
    }
    guard contactsAuthStatus == .authorized || contactsAuthStatus == .limited else {
        return
    }
    isLoadingContacts = true
    contactResults = await ContactsService.fetchContacts(identifiers: contactIdentifiers)
    isLoadingContacts = false
}
```

**Why `.task(id: contactIdentifiers)`:** The `id` parameter re-fires the task whenever `contactIdentifiers` changes — so adding or removing a linked contact immediately re-fetches.

### Pattern 3: Communication Actions via `@Environment(\.openURL)`

**What:** Use SwiftUI's built-in `openURL` environment value for all three communication URL schemes.

**When to use:** In `ContactRowView` for each action button.

**Example:**
```swift
// In ContactRowView
@Environment(\.openURL) private var openURL

// Phone call
Button {
    let digits = phone.filter(\.isNumber)
    if let url = URL(string: "tel://\(digits)") {
        openURL(url)
    }
} label: {
    Image(systemName: "phone")
}

// SMS
Button {
    let digits = phone.filter(\.isNumber)
    if let url = URL(string: "sms://\(digits)") {
        openURL(url)
    }
} label: {
    Image(systemName: "message")
}

// Email
Button {
    if let url = URL(string: "mailto:\(email)") {
        openURL(url)
    }
} label: {
    Image(systemName: "envelope")
}
```

**Phone number normalization:** `phone.filter(\.isNumber)` strips parentheses, dashes, spaces, and dots before building the `tel://` URL. A raw `CNPhoneNumber.stringValue` like `(555) 867-5309` would produce a malformed URL without this step.

### Pattern 4: Permission Denial UI

**What:** When `contactsAuthStatus` is `.denied` or `.restricted`, render an inline message in the Contacts section with a link to Settings.

**When to use:** Instead of blocking the whole form — only the Contacts section degrades.

**Example:**
```swift
// In PlayerFormView Contacts section, conditional on auth status
if contactsAuthStatus == .denied || contactsAuthStatus == .restricted {
    Label("Contacts access is required to display contact details.", systemImage: "exclamationmark.triangle")
        .foregroundStyle(.secondary)
        .font(.footnote)
    Button("Open Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
    .font(.footnote)
}
```

### Pattern 5: ContactRowView Layout

**What:** A small struct in `PlayerFormView.swift` that receives a single `CNContact` and renders name, phone, and email with tappable icons.

**Example structure (layout at implementer's discretion):**
```swift
struct ContactRowView: View {
    let contact: CNContact
    @Environment(\.openURL) private var openURL

    private var displayName: String {
        [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .ifEmpty("Unknown")
    }

    private var primaryPhone: String? {
        contact.phoneNumbers.first?.value.stringValue
    }

    private var primaryEmail: String? {
        contact.emailAddresses.first?.value as? String
    }

    var body: some View {
        // VStack of name row + action buttons — implementer decides exact layout
    }
}
```

### Anti-Patterns to Avoid

- **Calling `CNContactStore` in a view body or `.onAppear` closure:** Makes views untestable and risks calling `requestAccess` multiple times (OS only prompts once; subsequent calls silently return current status). Route through `ContactsService`.
- **Constructing `keysToFetch` inline at each call site:** Divergent key lists are how `CNPropertyNotFetchedException` gets introduced in new views. Use `ContactsService.keysToFetch` everywhere.
- **Not stripping non-digit characters from phone numbers before `tel://` URL construction:** Results in a silently no-op URL on iOS.
- **Silently dropping missing contact identifiers:** DISPLAY-05 requires a visible fallback row, not silent omission.
- **Requesting authorization before presenting the picker:** Picker works without authorization. Only request for `CNContactStore` fetch. (Phase 2 already correctly avoids this — do not regress it.)

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Live contact lookup by ID | Custom caching or snapshot layer | `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)` | Apple handles multi-account unification, CardDAV sync, iCloud merging automatically |
| Tap-to-call / tap-to-text / tap-to-email | Custom in-app dialer or message composer | `@Environment(\.openURL)` with `tel://`, `sms://`, `mailto:` | System apps handle these; building in-app equivalents is never worth it for this feature |
| Phone number parsing/formatting | Regex-based formatter | `phone.filter(\.isNumber)` for URL construction; display `CNPhoneNumber.stringValue` as-is | CNContact already stores the user's formatted string; only need digit-strip for URL |
| Authorization flow | Custom permission UI | `CNContactStore().requestAccess(for: .contacts) async` + Settings deep-link | OS controls the actual prompt; all you provide is timing and fallback messaging |

**Key insight:** The Contacts framework's fetch-by-identifier API is already the minimal, correct abstraction. There is no value in wrapping it further than a single `ContactsService` function.

---

## Common Pitfalls

### Pitfall 1: keysToFetch Mismatch → Runtime Crash

**What goes wrong:** `CNPropertyNotFetchedException` is thrown — and it is a hard crash, not a Swift error you can catch — when code accesses a `CNContact` property not included in the original `keysToFetch`.

**Why it happens:** Phase 2's `ContactPickerRepresentable` calls `onSelect(contact.identifier)` — it only needs the identifier. Phase 3 fetches via `ContactsService`, which must explicitly include all four display keys. If `ContactsService.fetchContacts` ever uses a different key set than the one `ContactRowView` accesses, a view that runs in a code path different from the fetch will crash.

**How to avoid:** `ContactsService.keysToFetch` is a single shared constant. Every access to a `CNContact` property in any view must correspond to a key in that array. Test by opening a contact that has all four fields populated.

**Warning signs:** Two separate arrays being constructed for keysToFetch anywhere in the codebase.

### Pitfall 2: iOS 18 `.limited` Access — Silent Empty Results

**What goes wrong:** On iOS 18, users can grant limited contacts access. `CNContactStore.unifiedContact(withIdentifier:)` throws `CNErrorCodeRecordDoesNotExist` for contacts not in the permitted set — even if the contact exists in the user's address book. Code that only handles `.authorized` will silently produce "Contact no longer available" rows for all contacts outside the limited set.

**Why it happens:** The switch on `CNAuthorizationStatus` has no `.limited` case, so it falls through to the "not authorized" branch and the fetch is never attempted.

**How to avoid:**
```swift
switch CNContactStore.authorizationStatus(for: .contacts) {
case .authorized, .limited:  // both allow fetching
    // proceed
case .denied, .restricted:
    // show guidance
case .notDetermined:
    // request
@unknown default:
    break
}
```
Treat `.limited` identically to `.authorized` for fetch purposes. The store will return what it can; `CNErrorCodeRecordDoesNotExist` for out-of-set contacts is already handled by `ContactResult.notFound`.

**Warning signs:** Any `switch` on `CNAuthorizationStatus` that lacks an explicit `.limited` case.

### Pitfall 3: `tel://` URL Fails Silently With Formatted Phone String

**What goes wrong:** `URL(string: "tel://(555) 867-5309")` produces `nil` — the parentheses and space are invalid in a URL. `openURL` is a no-op. The call button appears to work (no error) but nothing happens.

**Why it happens:** `CNPhoneNumber.stringValue` returns the user-formatted string (`(555) 867-5309`, `+1 555-867-5309`, etc.). This string is correct for display but cannot be used raw in a URL scheme.

**How to avoid:** `let digits = phone.filter(\.isNumber)` before constructing the URL. This handles all common formats including international prefixes (`+1` → `1`). For E.164 numbers with `+`, preserve the `+`: `let normalized = "+" + phone.filter({ $0.isNumber || $0 == "+" }).dropFirst(while: { !$0.isNumber && $0 != "+" })` — but simple digit-strip works for domestic numbers. The simple approach is sufficient for this app's use case.

**Warning signs:** Testing tap-to-call only with a manually typed "5551234567" number; not testing with a contact whose phone is formatted `(555) 123-4567`.

### Pitfall 4: `CNContact` Is Not Sendable — Cannot Cross Actor Boundaries

**What goes wrong:** Swift 6 strict concurrency rejects passing `CNContact` instances across actor boundaries. A `@MainActor` view trying to receive a `CNContact` from a `Task` running off the main actor gets a compile error: "Sending 'contact' risks causing data races."

**Why it happens:** `CNContact` is an Objective-C class not annotated `@Sendable`. Swift 6's strict concurrency enforces this.

**How to avoid:** Extract what you need from `CNContact` immediately on the actor where the fetch runs, or ensure the fetch and consumption happen on the same actor. The simplest approach: mark `ContactsService.fetchContacts` as `@MainActor` so the fetch and state assignment are on the same actor. Alternatively, extract display strings from `CNContact` in the service and return a value type — but this defeats the live-reference architecture. Marking the service method `@MainActor` is the least invasive fix.

**Confirmed pattern from STATE.md:** "contact.identifier (String) extracted in delegate callback — CNContact is not Sendable and cannot cross actor boundaries in Swift 6." The same constraint applies here.

**Warning signs:** Swift 6 compiler error mentioning "Sending" or "data races" on a `CNContact` return value.

### Pitfall 5: Authorization Prompt Fires Multiple Times or Never

**What goes wrong:** `requestAccess(for: .contacts)` is called on every view appearance because the status is re-checked without caching the result. On second and subsequent calls after the user has responded, the system silently returns the current status without showing a prompt — but the code may behave incorrectly if it expects a prompt to have appeared.

**Why it happens:** Not checking `authorizationStatus()` before calling `requestAccess()`, or calling `requestAccess()` from `onAppear` every time rather than gating on `.notDetermined`.

**How to avoid:** Always call `CNContactStore.authorizationStatus(for: .contacts)` first. Only call `requestAccess` if the result is `.notDetermined`. The `.task(id: contactIdentifiers)` pattern in Pattern 2 above does this correctly.

### Pitfall 6: Missing `ContactsService.keysToFetch` on the Picker's `displayedPropertyKeys`

**What goes wrong:** The picker (Phase 2) does not set `displayedPropertyKeys`, so the contact returned by the picker delegate has all fields populated — this works fine in Phase 2. In Phase 3, if `ContactsService.fetchContacts` uses a different key set from what `ContactRowView` accesses, the crash described in Pitfall 1 can occur even though the picker-returned contact appeared to work.

**How to avoid:** Phase 3 only uses contacts fetched via `ContactsService.fetchContacts` (not contacts returned directly from the picker). As long as `ContactsService.keysToFetch` is used consistently in every `unifiedContact` call, there is no cross-contamination with the picker flow.

---

## Code Examples

### ContactsService: Complete Authorization + Fetch Pattern

```swift
// Source: Apple CNContactStore documentation + Swift 6 concurrency constraints
import Contacts

enum ContactsService {

    static let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
    ]

    static func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    @MainActor
    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        return (try? await store.requestAccess(for: .contacts)) ?? false
    }

    @MainActor
    static func fetchContacts(identifiers: [String]) async -> [ContactResult] {
        let store = CNContactStore()
        return identifiers.map { id in
            do {
                let contact = try store.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)
                return .found(contact)
            } catch let error as CNError where error.code == .recordDoesNotExist {
                return .notFound(id)
            } catch {
                return .notFound(id)
            }
        }
    }
}

enum ContactResult {
    case found(CNContact)
    case notFound(String)
}
```

### Phone Number Normalization for URL Schemes

```swift
// Source: Swift standard library — filter(\.isNumber) strips all non-digit chars
extension String {
    var digitsOnly: String { filter(\.isNumber) }
}

// Usage in ContactRowView:
let digits = phoneNumber.digitsOnly
if !digits.isEmpty, let url = URL(string: "tel://\(digits)") {
    openURL(url)
}
```

### Settings Deep-Link for Permission Denied

```swift
// Source: UIApplication.openSettingsURLString — available since iOS 8
Button("Open Settings") {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        openURL(url)
    }
}
```

### Handling `.limited` Authorization

```swift
// Source: Apple CNContactStore.authorizationStatus docs (iOS 18)
static func canFetch() -> Bool {
    switch authorizationStatus() {
    case .authorized, .limited: return true
    case .denied, .restricted, .notDetermined: return false
    @unknown default: return false
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ABAddressBook` / `AddressBook.framework` | `Contacts` / `ContactsUI` | iOS 9 (removed iOS 14) | Irrelevant — this project targets iOS 18 |
| `CNContactStore.enumerateContacts` to search | `CNContactStore.unifiedContact(withIdentifier:)` for known IDs | Stable since iOS 9 | We store identifiers from Phase 1; targeted fetch is simpler and faster than enumeration |
| `CNAuthorizationStatus` with 3 cases | `CNAuthorizationStatus` with `.limited` added | iOS 18 | Must handle `.limited` explicitly — treat same as `.authorized` for fetch |
| `MFMessageComposeViewController` / `MFMailComposeViewController` for in-app compose | `openURL` with `sms://` / `mailto:` | Stable since iOS 14 | `openURL` is zero-framework; in-app composers only needed if body pre-fill is required |

**Deprecated/outdated:**
- `AddressBook.framework` (`ABAddressBook`): removed iOS 14+. Use `Contacts` framework.
- `canOpenURL` for `tel://` / `sms://`: no longer required — iOS will handle unsupported URLs gracefully. Do not add `LSApplicationQueriesSchemes` entries for these; that is deprecated practice.

---

## Runtime State Inventory

Step 2.5 trigger check: Phase 3 is a feature addition (display + actions), not a rename/refactor/migration. No runtime state inventory required.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Contacts framework | DISPLAY-01, PERM-02, PERM-03 | ✓ (system framework) | iOS 18 SDK | — |
| iOS Simulator / device | Manual UI testing of call/text/email actions | ✓ | Xcode on macOS | Simulator cannot place calls; device required for full E2E |
| iOS 18 Simulator | Verify `.limited` authorization path | ✓ (Xcode 15+) | iOS 18 | — |

**Missing dependencies with no fallback:**
- None — all required frameworks are system frameworks included with the iOS 18 SDK.

**Device note:** `tel://` and `sms://` URL dispatch is a no-op in the Simulator. Tests for tap-to-call/text must be verified manually on a physical device or accepted as "builds and fires `openURL` correctly" in unit tests.

---

## Validation Architecture

`nyquist_validation` is enabled in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test` macro) — used in all existing test files |
| Config file | None — framework detected via `PigeonPlayTests/` target in `PigeonPlay.xcodeproj` |
| Quick run command | `xcodebuild test -project PigeonPlay.xcodeproj -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Same — all tests run in one target |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DISPLAY-01 | `ContactsService.fetchContacts` returns `.found` for a valid identifier | Unit | `xcodebuild test ... -only-testing:PigeonPlayTests/contactsServiceFetchReturnsFoundForKnownIdentifier` | ❌ Wave 0 |
| DISPLAY-01 | `ContactsService.fetchContacts` returns all required fields (name, phone, email) | Unit | `xcodebuild test ...` | ❌ Wave 0 |
| DISPLAY-02 | `ContactRowView` phone button constructs correct `tel://` URL with digits only | Unit | `xcodebuild test ...` | ❌ Wave 0 |
| DISPLAY-03 | `ContactRowView` SMS button constructs correct `sms://` URL | Unit | `xcodebuild test ...` | ❌ Wave 0 |
| DISPLAY-04 | `ContactRowView` email button constructs correct `mailto:` URL | Unit | `xcodebuild test ...` | ❌ Wave 0 |
| DISPLAY-05 | `ContactsService.fetchContacts` returns `.notFound` for a nonexistent identifier | Unit | `xcodebuild test ...` | ❌ Wave 0 |
| DISPLAY-05 | `.notFound` result renders "Contact no longer available" (not a crash) | Manual | — | Manual only — requires UI |
| PERM-02 | `ContactsService.requestAccess` called when status is `.notDetermined` | Unit | `xcodebuild test ...` | ❌ Wave 0 |
| PERM-03 | Denied status shows Settings deep-link URL | Unit | `xcodebuild test ...` | ❌ Wave 0 |

**Note on testability:** `CNContactStore` is a system API with no protocol to mock against. Unit tests for `ContactsService.fetchContacts` with real identifiers will only pass on a device with matching contacts. The standard approach is:
1. Test the URL construction logic in isolation (strip digits → build URL → assert URL string)
2. Test `ContactResult` enum handling (given a `.notFound`, view state has the correct fallback string)
3. Accept that `CNContactStore` calls are integration-tested via manual on-device verification

This means most unit tests for Phase 3 test the logic _around_ the Contacts framework (URL building, auth status branching, result handling), not the framework calls themselves.

### Sampling Rate

- **Per task commit:** Build succeeds, existing tests pass
- **Per wave merge:** Full test suite green
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `PigeonPlayTests/ContactsServiceTests.swift` — covers DISPLAY-01, DISPLAY-05, PERM-02 (logic paths; store calls are manual)
- [ ] `PigeonPlayTests/ContactRowViewTests.swift` — covers DISPLAY-02, DISPLAY-03, DISPLAY-04 (URL construction logic)

*(Existing test infrastructure: `PigeonPlayTests/` target with Swift Testing `@Test` macro — confirmed in `PlayerTests.swift`, `GameTests.swift`, `ContactPickerRepresentableTests.swift`)*

---

## Open Questions

1. **Should `PlayerFormView` fetch contacts or should fetching move to a new `PlayerDetailView`?**
   - What we know: The architecture research recommended separating edit and detail surfaces. Phase 2 locked decision D-05 says Phase 3 adds live data to the existing Contacts section in `PlayerFormView`.
   - What's unclear: A separate `PlayerDetailView` is cleaner long-term (edit form vs. read view have different lifecycles), but Phase 3's scope as stated says "display live name, phone, and email" — the simplest delivery is updating `PlayerFormView`'s placeholder rows.
   - Recommendation: Keep it in `PlayerFormView` for Phase 3. The placeholder rows are already there. Splitting into `PlayerDetailView` is a future refactor. Planner should confirm this.

2. **Phone number normalization edge cases: international numbers with `+`**
   - What we know: `phone.filter(\.isNumber)` strips `+` from `+1 (555) 867-5309`, producing `15558675309` which works as a `tel://` URL on US devices.
   - What's unclear: Whether international coaches using this app need `+` preserved for proper routing.
   - Recommendation: Use `filter(\.isNumber)` for now (simple, works for domestic). Document as a known limitation. The project's use case is a local sports roster; international dialing edge cases are not in scope for v1.

3. **Display when a contact has no phone number or no email**
   - What we know: `CNContact.phoneNumbers` and `.emailAddresses` are arrays that may be empty. The action buttons for call/text/email should not appear if no corresponding data exists.
   - What's unclear: Whether to show a "no phone" placeholder text or simply hide the row element.
   - Recommendation: Hide action buttons when the corresponding field is empty (no button is less confusing than a disabled button). Planner should call this out explicitly in the ContactRowView task.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 3 |
|-----------|-------------------|
| Swift 6.0 strict concurrency | `CNContact` is not `Sendable`; all fetches must stay on `@MainActor` or extract value types immediately |
| iOS 18.0 minimum deployment target | `CNAuthorizationStatus.limited` is available without `#available` guard; use it |
| No third-party dependencies | Contacts + ContactsUI only; no SwiftyContacts, KNContactsPicker, etc. |
| Services as enums with static methods | `ContactsService` follows the `LineSuggester` pattern |
| Tests required; Swift Testing `@Test` macro | Wave 0 must create test files before implementation tasks |
| Red/Green TDD | Write failing tests first for URL construction logic and ContactResult handling |
| XcodeGen project structure | Any new `.swift` file must be added to `project.yml` so XcodeGen regenerates the project |
| GSD workflow enforcement | All edits via GSD execute-phase, no direct repo edits outside the workflow |

---

## Sources

### Primary (HIGH confidence)

- Apple CNContactStore documentation — `unifiedContact(withIdentifier:keysToFetch:)`, `authorizationStatus`, `requestAccess` behavior
- Apple CNContactPickerViewController documentation — confirms no auth required for picker
- WWDC24 "Meet the Contact Access Button" — `.limited` authorization status behavior on iOS 18
- `.planning/research/STACK.md` — prior milestone research, verified against Apple docs
- `.planning/research/PITFALLS.md` — prior milestone pitfalls research, verified against Apple forums
- `.planning/STATE.md` — accumulated decisions from Phases 1 and 2
- Existing codebase inspection — `PlayerFormView.swift`, `ContactPickerRepresentable.swift`, `Player.swift`, `PlayerMigration.swift`

### Secondary (MEDIUM confidence)

- Hacking with Swift: "How to read user contacts with ContactAccessButton" — identifier persistence pattern
- createwithswift.com: "Contact Management: Working with the Contact Picker View Controller"

### Tertiary (LOW confidence)

- None for this phase. All findings are grounded in official Apple documentation or direct codebase inspection.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs are Apple-native, stable since iOS 9, verified in prior milestone research
- Architecture: HIGH — `ContactsService` pattern directly mirrors `LineSuggester` already in codebase; no novel patterns introduced
- Pitfalls: HIGH — `CNPropertyNotFetchedException`, `.limited` handling, `tel://` normalization all verified against Apple docs and prior PITFALLS.md research
- Test architecture: MEDIUM — `CNContactStore` is not mockable; test strategy must work around this with logic-level unit tests and manual integration tests

**Research date:** 2026-03-23
**Valid until:** 2026-07-01 (Contacts framework APIs are stable; iOS 19 could introduce new authorization cases)
