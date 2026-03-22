# Pitfalls Research

**Domain:** iOS Contacts framework integration + SwiftData schema migration
**Researched:** 2026-03-22
**Confidence:** HIGH (multiple primary sources, Apple developer forums, WWDC documentation)

---

## Critical Pitfalls

### Pitfall 1: Shipping a SwiftData Schema Migration Without First Versioning the Existing Model

**What goes wrong:**

The current `Player` model has no `VersionedSchema`. If you add `VersionedSchema` and a `SchemaMigrationPlan` in the same release that drops `parentName`/`parentPhone`/`parentEmail` and adds the new fields, SwiftData will crash on launch for every existing user with the error: `"Cannot use staged migration with an unknown model version"`.

**Why it happens:**

SwiftData's migration machinery needs to identify _which version_ of the schema is currently persisted on device to determine what migration path to follow. An unversioned schema has no version fingerprint. When SwiftData sees a `SchemaMigrationPlan` but cannot match the on-disk store to any known version in the plan, it panics instead of guessing.

**How to avoid:**

Use a two-release strategy:

1. **Release A:** Wrap the current model — untouched — in `SchemaV1` (a `VersionedSchema`). Ship this to users. No migration plan needed, no model changes. This registers the current schema fingerprint on-disk.
2. **Release B:** Define `SchemaV2` with the new fields (drop old parent fields, add `phoneNumber` and `linkedContactIdentifiers`). Add a `SchemaMigrationPlan` with a lightweight stage from V1 to V2.

Since this app currently has a small user base, it may be acceptable to compress releases if all testers are on a fresh install. But for any live TestFlight or App Store users who have existing data, the two-release strategy is mandatory.

**Warning signs:**

- Any model file that does NOT reference `VersionedSchema` before you start writing migration code.
- The phrase `ModelContainer(for: Player.self, Game.self, ...)` with a plain `[Schema]` instead of a `SchemaMigrationPlan`.

**Phase to address:** SwiftData migration phase (whichever phase drops the old parent fields).

---

### Pitfall 2: Conflating CNContactPickerViewController with CNContactStore Permission Requirements

**What goes wrong:**

Developers add `NSContactsUsageDescription` to Info.plist, call `CNContactStore().requestAccess(for: .contacts)`, and wire up an authorization gate before showing the contact picker — then discover the picker works without any of this. Worse: some developers skip `NSContactsUsageDescription` entirely because the picker "just works," then add `CNContactStore` lookups later and get silent failures or crashes because the key is absent.

**Why it happens:**

`CNContactPickerViewController` is an out-of-process picker. It runs in a separate system process; your app only receives the final selection. No authorization is required or requested. `CNContactStore`, by contrast, requires full `.authorized` status before returning any results, and iOS will crash the app immediately if `NSContactsUsageDescription` is missing when a store access is attempted.

**How to avoid:**

- Use `CNContactPickerViewController` for all contact selection — it requires zero permission and is privacy-friendly by design.
- Still add `NSContactsUsageDescription` to Info.plist from day one, because `CNContactStore` is needed to re-fetch a saved contact by identifier (`CNContact.identifier`) at display time.
- Do not call `requestAccess` before presenting the picker — it's irrelevant and confusing to users.
- Do call `requestAccess` (or check `authorizationStatus`) before any `CNContactStore.enumerateContacts` / `unifiedContact(withIdentifier:)` call.

**Warning signs:**

- A permission gate that blocks showing the `CNContactPickerViewController`.
- Any `CNContactStore` fetch call that is not preceded by an authorization status check.
- Missing `NSContactsUsageDescription` in Info.plist (XcodeGen `project.yml` will need this added to the `plist` section under `INFOPLIST_KEY_NSContactsUsageDescription`).

**Phase to address:** Contact picker integration phase.

---

### Pitfall 3: Accessing a CNContact Property That Was Not in the keysToFetch

**What goes wrong:**

After fetching a contact by identifier via `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)`, code that accesses a property not included in `keysToFetch` throws `CNPropertyNotFetchedException` with the message "A property was not requested when contact was fetched." This crashes the app immediately with no graceful fallback.

**Why it happens:**

`CNContact` uses lazy partial-fetch by design: it tracks which keys were requested and throws a hard exception for any property access outside that set. This is not a soft nil — it is a fatal exception. It catches developers who test with one code path but access contact properties from a different code path (e.g., a detail view that accesses `.emailAddresses` when the fetch only requested `.phoneNumbers`).

**How to avoid:**

Define a single constant array of all keys your app will ever access:

```swift
static let contactKeys: [CNKeyDescriptor] = [
    CNContactGivenNameKey as CNKeyDescriptor,
    CNContactFamilyNameKey as CNKeyDescriptor,
    CNContactPhoneNumbersKey as CNKeyDescriptor,
    CNContactEmailAddressesKey as CNKeyDescriptor,
]
```

Use this array everywhere — in the picker's `displayedPropertyKeys` and in every `CNContactStore` fetch. Never access a key not in this list. Use `contact.isKeyAvailable(CNContactGivenNameKey)` defensively when in doubt.

**Warning signs:**

- Different parts of the app constructing their own inline `keysToFetch` arrays.
- A detail view that shows more contact fields than the fetch request specifies.
- Any code path that accesses contact properties from a `CNContact` returned by the picker delegate (picker returns partial contacts by default).

**Phase to address:** Contact display / detail view phase.

---

### Pitfall 4: iOS 18 Limited Contacts Access Returns Zero Records

**What goes wrong:**

On iOS 18+, when a user grants "limited" contacts access (`CNAuthorizationStatus.limited`), `CNContactStore.enumerateContacts` returns an empty result set — not an error. Code that treats an empty result as "no contacts found" will silently fail to re-fetch saved contact identifiers, making linked contacts appear to have been deleted.

**Why it happens:**

iOS 18 introduced granular contact sharing: users can share only specific contacts with an app. `CNAuthorizationStatus.limited` is a new case that does not exist in iOS 17 or earlier. Code that only handles `.authorized` and `.denied` will fall through to the "no contacts" state without indicating why.

**How to avoid:**

This project uses `CNContactPickerViewController` for selection (out-of-process, unaffected by authorization level). The only place `CNContactStore` is needed is when re-fetching a saved contact identifier to display its current info. Handle all four authorization cases:

```swift
switch CNContactStore.authorizationStatus(for: .contacts) {
case .authorized:    // fetch normally
case .limited:       // fetch normally — only returns permitted contacts
case .denied, .restricted:  // show "Access required" UI
case .notDetermined: // request access
}
```

Under `.limited`, `unifiedContact(withIdentifier:)` will succeed if the saved contact is in the user's permitted set, and will throw `CNErrorCodeRecordDoesNotExist` if not. Treat that error as "contact no longer accessible" rather than a crash.

**Warning signs:**

- A `switch` on `CNAuthorizationStatus` with a single `default:` branch covering `.limited`.
- App silently shows empty contact info after the user upgrades to iOS 18 and re-accepts permissions under the new limited model.

**Phase to address:** Permission flow and contact re-fetch phase.

---

### Pitfall 5: Storing CNContact Data Snapshots Instead of the Identifier

**What goes wrong:**

Instead of storing only `CNContact.identifier` and fetching live data on demand, developers store the contact's name, phone, and email directly in the SwiftData model. This creates stale data: when a parent changes their phone number, the app still shows the old number.

**Why it happens:**

It feels simpler to store the data once and not worry about live fetches. The PROJECT.md already ruled this out, but it's worth flagging because the temptation can reassert itself during implementation when live fetching feels complex.

**How to avoid:**

Store only `CNContact.identifier` (a stable `String`). Fetch live contact data in the view layer via `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)`. The identifier is stable across app launches and device restarts (though not across iCloud account changes on the same device — see Pitfall 6).

**Warning signs:**

- Any SwiftData model field named `contactName`, `contactPhone`, or `contactEmail` added during implementation.
- Contact data being cached into the `Player` model at selection time.

**Phase to address:** Data model design phase (prevent at schema definition, not after).

---

### Pitfall 6: Assuming CNContact Identifiers Are Cross-Device Stable

**What goes wrong:**

A `CNContact.identifier` is stable across app launches on a single device, but it is NOT guaranteed to be the same identifier for the same contact on a different device (even when using iCloud Contacts sync). Developers building multi-device sync or backup/restore flows discover that stored identifiers are stale after a restore-to-new-device.

**Why it happens:**

The identifier is generated locally. iCloud sync preserves the logical contact record but may assign a different local identifier on a fresh device. Apple's documentation says "this identifier can be saved and used to fetch the contact." It does not say it is stable across devices.

**How to avoid:**

For this project's scope (single-device, no sync), this is LOW risk but worth knowing. If iCloud backup/restore is ever relevant, add logic to gracefully handle `CNErrorCodeRecordDoesNotExist` when re-fetching a stored identifier, and present UI asking the user to re-link the contact rather than crashing or showing stale data.

**Warning signs:**

- TestFlight testers restoring from backup and reporting that linked contacts appear broken.
- Any future iCloud sync feature that transfers `Player` records between devices.

**Phase to address:** Contact re-fetch / error handling phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip `VersionedSchema` on initial model | Less boilerplate | Unrecoverable crash for existing users on first migration | Never — must retrofit V1 before any migration |
| Inline `keysToFetch` at each call site | Less setup | Divergent key lists cause partial-contact crashes in new views | Never — use a single shared constant |
| Request contacts permission before picker | Familiar permission flow | Unnecessary friction; picker works without it | Never — it's wrong regardless of simplicity |
| Store contact name/phone in SwiftData | Simpler fetch logic | Stale data that silently misleads coaches | Never — this project explicitly ruled it out |
| Handle only `.authorized` in auth switch | Less code | Silent failure on iOS 18 limited access | Never on iOS 18+ deployment targets |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `CNContactPickerViewController` in SwiftUI | Wrapping directly without `UINavigationController` causes blank picker sheet | Wrap in `UINavigationController` inside `UIViewControllerRepresentable`; assign delegate to `context.coordinator` |
| `CNContactPickerViewController` delegate | Implementing delegate on a SwiftUI `struct` (value type) | Create a `Coordinator` class conforming to `CNContactPickerDelegate`; use `makeCoordinator()` |
| `CNContactStore` on main thread | Fetching all contacts synchronously blocks UI | Use `Task { await ... }` or a background `Task` with `async` CNContactStore APIs |
| `NSContactsUsageDescription` in XcodeGen | Forgetting to add to `project.yml` plist section | Add `INFOPLIST_KEY_NSContactsUsageDescription` to the `plist` section of `project.yml` |
| SwiftData migration + iCloud | Custom migration stages are not supported when CloudKit sync is enabled | Use lightweight-only migration stages (adding/removing/renaming fields); no custom willMigrate/didMigrate with data transforms |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Fetching all contacts with all keys on view appear | Noticeable lag when opening the contact display | Fetch only by stored identifier with a minimal key set; do it async | Immediately on devices with large contact lists (500+) |
| Re-fetching the same contact identifier on every view render | Repeated `CNContactStore` calls per render cycle | Cache the fetched `CNContact` in `@State` or a view model; only re-fetch on re-appear or explicit refresh | Small teams won't notice, but it's wasteful |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Missing `NSContactsUsageDescription` in Info.plist | App crashes when any `CNContactStore` access is attempted, even in non-obvious code paths | Add the key in `project.yml` at the start of the Contacts integration phase, before writing any store code |
| Logging `CNContact` data (name, phone) to console or analytics | PII leakage in logs | Never print contact data; treat `CNContact` properties as sensitive at all times |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Presenting a full contacts permission dialog before the user has taken any action | Users distrust apps that ask for broad access upfront; rejection rate is high | Request access only when the user taps "Link a Contact" for the first time, or rely on the picker (which requires no permission at all) |
| No handling for a linked contact that has been deleted from iOS Contacts | UI shows an empty or broken contact card with no explanation | Catch `CNErrorCodeRecordDoesNotExist` and show "Contact no longer available — tap to re-link" |
| No affordance to unlink a contact | Coaches can add contacts but not remove them | Include a swipe-to-delete or explicit "Remove" action on each linked contact entry |
| Showing raw `CNContact.identifier` strings in debug/error UI | Confuses users | Use the contact's display name or "Unknown contact" as fallback |

---

## "Looks Done But Isn't" Checklist

- [ ] **VersionedSchema:** Current model wrapped in `SchemaV1` and shipped before any migration code is written — verify by checking that `ModelContainer` uses a `SchemaMigrationPlan`.
- [ ] **NSContactsUsageDescription:** Present in `project.yml` plist section before any `CNContactStore` call is compiled — verify by building and checking Info.plist in the derived data output.
- [ ] **CNContactPickerViewController delegate:** Assigned to `context.coordinator` (not to the `UIViewControllerRepresentable` struct itself) — verify that selection callback fires in simulator.
- [ ] **keysToFetch completeness:** Every property accessed in any view is listed in the shared `contactKeys` constant — verify by accessing all contact views with a contact that has all fields populated.
- [ ] **Limited access handling:** `CNAuthorizationStatus.limited` case handled explicitly — verify on iOS 18 simulator by granting limited access and confirming no silent empty-state failures.
- [ ] **Stale-identifier recovery:** Code gracefully handles `CNErrorCodeRecordDoesNotExist` — verify by saving a contact identifier, deleting the contact from iOS Contacts, and opening the player detail.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Shipped migration without V1 intermediary (users crashing) | HIGH | Hotfix release that catches `ModelContainer` creation failure, deletes the corrupt store, and recreates it; data loss is unavoidable. Then ship proper V1 → V2 migration. |
| Missing `NSContactsUsageDescription` (store calls crashing) | LOW | Add key, resubmit. No data loss. |
| Stored contact data snapshots instead of identifiers | MEDIUM | Add a migration that drops snapshot fields; users re-link contacts manually. |
| Wrong coordinator pattern (picker delegate never fires) | LOW | Refactor `UIViewControllerRepresentable`; no data involved. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Unversioned schema before migration | Data model / migration phase — must ship V1 schema first | `ModelContainer` uses `SchemaMigrationPlan`; no crash on upgrade from previous build |
| Missing `NSContactsUsageDescription` | Contact picker integration phase — add at the start | Build succeeds; `CNContactStore.requestAccess` does not crash |
| Blank picker sheet (missing nav controller) | Contact picker integration phase | Picker appears with real contacts in simulator |
| Wrong delegate pattern (struct instead of coordinator) | Contact picker integration phase | Selection callback fires and returns a `CNContact` |
| keysToFetch mismatch crash | Contact display phase | All contact property accesses use the shared key constant |
| iOS 18 limited access silent failure | Permission flow phase | Limited access tested explicitly in iOS 18 simulator |
| Stale contact identifier not found | Contact re-fetch / error handling phase | Deleting a linked contact produces graceful UI, not crash |
| Contact data stored in model (stale data) | Data model design phase | Schema review confirms no contact-data fields on `Player` |

---

## Sources

- [Never use SwiftData without VersionedSchema — Mert Bulan](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema)
- [SwiftData unversioned migration crash — Apple Developer Forums](https://developer.apple.com/forums/thread/761735)
- [An Unauthorized Guide to SwiftData Migrations — Atomic Robot](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)
- [SwiftData custom migration crash — Apple Developer Forums](https://developer.apple.com/forums/thread/758874)
- [SwiftData Migration Plan does not work — Apple Developer Forums](https://developer.apple.com/forums/thread/748049)
- [CNContactPickerViewController — Apple Developer Documentation](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller)
- [CNContactPickerViewController does not require permission — Apple Developer Forums](https://developer.apple.com/forums/thread/12275)
- [Meet the Contact Access Button (iOS 18 limited access) — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10121/)
- [iOS 18 CNAuthorizationStatusLimited — react-native-permissions issue #894](https://github.com/zoontek/react-native-permissions/issues/894)
- [Fetch CNContacts blocking UI — Hacking with Swift forums](https://www.hackingwithswift.com/forums/swiftui/fetch-cncontacts-and-update-ui-blocking-ui-while-fetching/4614)
- [SwiftUI: Working with User Contacts — Itsuki on Medium](https://medium.com/@itsuki.enjoy/swiftui-working-with-user-contacts-2745dc875de1)
- [ContactPicker in SwiftUI — Sharath Sriram](https://sharaththegeek.substack.com/p/contactpicker-in-swiftui)
- [How to migrate to a new schema with SwiftData — tanaschita.com](https://tanaschita.com/20231120-migration-with-swiftdata/)
- [How SwiftData works with Swift concurrency — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency)

---
*Pitfalls research for: iOS Contacts framework + SwiftData migration (PigeonPlay roster-manager)*
*Researched: 2026-03-22*
