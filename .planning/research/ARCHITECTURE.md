# Architecture Research

**Domain:** iOS Contacts framework integration with SwiftUI / SwiftData
**Researched:** 2026-03-22
**Confidence:** HIGH (all findings verified against Apple official docs or official developer forum discussions)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        View Layer (SwiftUI)                      │
├──────────────────────┬──────────────────────┬────────────────────┤
│   PlayerFormView     │  PlayerDetailView    │   ContactRowView   │
│  (edit + link UI)    │  (read + call/text)  │  (per-contact row) │
└──────────┬───────────┴──────────┬───────────┴──────────┬─────────┘
           │                      │                       │
           ▼                      ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     UIKit Bridge Layer                           │
├─────────────────────────────────────────────────────────────────┤
│          ContactPickerRepresentable                              │
│   (UIViewControllerRepresentable wrapping                        │
│    CNContactPickerViewController via UINavigationController)     │
└──────────────────────────────────┬──────────────────────────────┘
                                   │ CNContact.identifier (String)
                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Service Layer                                │
├──────────────────────────────────────────────────────────────────┤
│             ContactsService  (enum, static methods)              │
│  - requestAccess()           (async, returns Bool)               │
│  - fetchContacts([String])   (async, returns [CNContact])        │
│  - authorizationStatus()     (sync, returns CNAuthorizationStatus)│
└──────────────────────────────────┬──────────────────────────────┘
                                   │
           ┌───────────────────────┼───────────────────────┐
           ▼                       ▼                       ▼
┌──────────────────┐  ┌────────────────────────┐  ┌───────────────┐
│  CNContactStore  │  │   SwiftData / Player   │  │  UIApplication│
│  (live contact   │  │  .phoneNumber: String? │  │  .open(url:)  │
│   data lookup)   │  │  .contactIDs: [String] │  │  (call/text/  │
└──────────────────┘  └────────────────────────┘  │   email)      │
                                                   └───────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `ContactPickerRepresentable` | Bridge CNContactPickerViewController into SwiftUI sheet presentation | `UIViewControllerRepresentable` struct with inner `Coordinator: NSObject, CNContactPickerDelegate` |
| `ContactsService` | All CNContactStore interactions: permission request, fetch-by-identifier, authorization status check | Enum with static async methods (no state, no singleton) |
| `Player` (updated SwiftData model) | Persist contact identifiers as `[String]` and own phone number as `String?` | `@Model final class` with new fields, old parent fields removed via `VersionedSchema` migration |
| `PlayerFormView` (updated) | Edit player info, manage linked contacts list, trigger picker | SwiftUI `Form` with a contacts section |
| `PlayerDetailView` (new or expanded) | Display live-fetched contact info, tap-to-call/text/email | Fetches contacts via `ContactsService` on appear, renders `Link` or `Button` with `UIApplication.open` |
| `ContactRowView` | Render a single linked contact's name, phone, email with action buttons | Small SwiftUI subview, receives `CNContact` |

## Recommended Project Structure

```
PigeonPlay/
├── Models/
│   └── Player.swift               # Updated: remove parentName/Phone/Email,
│                                  # add phoneNumber: String?, contactIDs: [String]
├── Services/
│   ├── LineSuggester.swift        # Unchanged
│   └── ContactsService.swift      # New: CNContactStore wrapper (enum, static)
├── Views/
│   └── Roster/
│       ├── RosterView.swift       # Unchanged
│       ├── PlayerFormView.swift   # Updated: new contacts section
│       ├── PlayerDetailView.swift # New (or expanded): live contact display
│       ├── ContactRowView.swift   # New: per-contact row with action buttons
│       └── ContactPickerRepresentable.swift  # New: UIKit bridge
└── App/
    └── PigeonPlayApp.swift        # Updated: modelContainer gains migration plan
```

### Structure Rationale

- **Services/ContactsService.swift:** Contacts fetching is I/O and permission logic — it does not belong in views. Keeping it as an enum with static methods is consistent with `LineSuggester`'s pattern and avoids introducing `@Observable` or `ObservableObject` ceremony.
- **Views/Roster/ContactPickerRepresentable.swift:** The UIKit bridge is isolated in its own file. It has no business logic — it just wraps the picker and hands back an identifier via a callback closure.
- **PlayerDetailView separate from PlayerFormView:** Detail (read + call) and edit (write + link) are distinct surfaces. Merging them leads to a view that manages two very different lifecycles (live-fetched CNContact data vs. editable SwiftData state).

## Architectural Patterns

### Pattern 1: Identifier-Only Persistence (Live Reference)

**What:** Store only `CNContact.identifier` (a `String`) in SwiftData. Never copy name, phone, or email into the model. Fetch live from `CNContactStore` when the view appears.

**When to use:** Always for this feature — the requirement is explicitly "live reference."

**Trade-offs:**
- Pro: Contact data is always current; no stale name/phone to manage.
- Pro: Model is minimal; no sync logic needed.
- Con: Fetch is async and can fail if permission is revoked. Views must handle the loading/empty/error states.
- Con: `CNContact.identifier` is stable on one device but not guaranteed to survive certain iCloud/CardDAV sync events (LOW risk in practice for this use case, but worth noting).

**Example:**
```swift
// Player model
@Model final class Player {
    var name: String
    var gender: Gender
    var defaultMatching: GenderMatching?
    var phoneNumber: String?          // player's own number
    var contactIDs: [String]          // 0+ CNContact.identifier values

    // ... init ...
}

// In a view
.task {
    linkedContacts = await ContactsService.fetchContacts(ids: player.contactIDs)
}
```

### Pattern 2: UIViewControllerRepresentable with UINavigationController Wrapper

**What:** `CNContactPickerViewController` must be embedded in a `UINavigationController` before presentation. Presenting the raw picker results in an empty sheet (a known UIKit quirk).

**When to use:** Any time you present the contact picker from SwiftUI.

**Trade-offs:**
- Pro: Avoids the empty-sheet bug definitively.
- Con: A small amount of boilerplate UIKit scaffolding is required.

**Example:**
```swift
struct ContactPickerRepresentable: UIViewControllerRepresentable {
    var onSelect: (CNContact) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Wrap in nav controller — direct presentation yields empty sheet
        return UINavigationController(rootViewController: picker)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, CNContactPickerDelegate {
        var onSelect: (CNContact) -> Void
        init(onSelect: @escaping (CNContact) -> Void) { self.onSelect = onSelect }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
        }
    }
}
```

### Pattern 3: SwiftData VersionedSchema Lightweight Migration

**What:** Wrap the current `Player` schema in a `VersionedSchema` enum (V1), define V2 with the new fields and removed fields, declare a `SchemaMigrationPlan`, and pass it to `modelContainer`. For dropping optional fields and adding new optional fields, a lightweight migration is sufficient — no `willMigrate`/`didMigrate` closures needed.

**When to use:** Any time the SwiftData model changes between app versions. This is the first schema change in this project.

**Trade-offs:**
- Pro: SwiftData handles the migration automatically on first launch after update.
- Pro: Lightweight migration requires no data transformation code.
- Con: V1 must be preserved in code indefinitely (or until the minimum supported version is bumped past the migration).
- Con: Adding a non-optional String property with a default value has a known bug in some iOS versions — keep new properties optional or `[String]` with default `[]`.

**Example:**
```swift
// Migration plan
enum PlayerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [PlayerSchemaV1.self, PlayerSchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: PlayerSchemaV1.self,
        toVersion: PlayerSchemaV2.self
    )
}

// PigeonPlayApp.swift
.modelContainer(
    for: [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self],
    migrationPlan: PlayerMigrationPlan.self
)
```

## Data Flow

### Adding a Linked Contact

```
User taps "Add Contact" button in PlayerFormView
    ↓
ContactPickerRepresentable presented as .sheet
    ↓
User selects a contact in CNContactPickerViewController
    ↓
Coordinator.contactPicker(_:didSelect:) fires → onSelect(contact)
    ↓
PlayerFormView receives CNContact.identifier (String)
    ↓
player.contactIDs.append(identifier) [SwiftData write]
    ↓
Sheet dismissed
```

### Viewing Linked Contact Info (Live Fetch)

```
User navigates to PlayerDetailView
    ↓
.task { linkedContacts = await ContactsService.fetchContacts(ids: player.contactIDs) }
    ↓
ContactsService.fetchContacts:
  - Checks CNContactStore.authorizationStatus
  - Calls store.unifiedContact(withIdentifier:keysToFetch:) for each ID
  - Returns [CNContact] (skips any identifiers that fail lookup)
    ↓
View renders ContactRowView for each CNContact
    ↓
User taps phone → UIApplication.shared.open(tel:// URL)
User taps email → UIApplication.shared.open(mailto:// URL)
User taps SMS → UIApplication.shared.open(sms:// URL)
```

### Permission Request Flow

```
App launch OR first tap of "Add Contact"
    ↓
ContactsService.authorizationStatus() → check current status
    ↓
.notDetermined → ContactsService.requestAccess() (async)
    ↓
.authorized → proceed
.denied / .restricted → show informational alert with Settings deep-link
```

### Key Data Flows

1. **Identifier round-trip:** Contact picker yields `CNContact` → extract `.identifier` → store in SwiftData → use to fetch live data on next view appearance. The `CNContact` object itself is never persisted.
2. **Action dispatch:** All call/text/email actions go through `UIApplication.shared.open(_:)` with scheme URLs — no custom communication layer needed.
3. **Permission gating:** `ContactsService` is the single chokepoint for all Contacts access. Views never call `CNContactStore` directly.

## Scaling Considerations

This is a local iOS app with no server component and a small roster (tens of players). Scaling is irrelevant. The only concern is UI responsiveness:

| Concern | Approach |
|---------|----------|
| Slow contact fetch on view appear | Use `.task` (not `.onAppear`) for async fetch; show `ProgressView` while loading |
| Stale contact data between navigation pushes | Re-fetch in `.task` on each appearance; the overhead is negligible for small rosters |
| Permission revocation mid-session | `ContactsService.fetchContacts` returns empty array gracefully; view shows "Contacts access required" prompt |

## Anti-Patterns

### Anti-Pattern 1: Copying Contact Data Into SwiftData

**What people do:** Snapshot `CNContact.givenName`, `familyName`, `phoneNumbers` into the `Player` model at link time.

**Why it's wrong:** Creates a second source of truth. The snapshot goes stale the moment the user edits the contact in the Contacts app. Worse, there is no notification mechanism to invalidate the cache without significant additional infrastructure (`CNContactStoreDidChange` notification + re-sync logic).

**Do this instead:** Store only the `CNContact.identifier` string. Fetch live on display.

### Anti-Pattern 2: Presenting CNContactPickerViewController Directly (Without UINavigationController)

**What people do:** Return `CNContactPickerViewController()` directly from `makeUIViewController`.

**Why it's wrong:** On current iOS, presenting the picker directly results in an empty sheet with no contacts listed. This is a UIKit quirk specific to this view controller.

**Do this instead:** Wrap the picker in `UINavigationController(rootViewController: picker)` and return the nav controller from `makeUIViewController`.

### Anti-Pattern 3: Accessing CNContactStore From Views

**What people do:** Instantiate `CNContactStore()` inside a SwiftUI view body or `.onAppear` closure, call `requestAccess`, fetch contacts.

**Why it's wrong:** Makes views untestable (impossible to inject a mock store), duplicates authorization logic across views, and risks calling `requestAccess` multiple times (which the OS only honors once — subsequent calls silently return the current status without prompting).

**Do this instead:** Route all Contacts I/O through `ContactsService`. Views call service methods and handle the result.

### Anti-Pattern 4: Skipping VersionedSchema for the Model Migration

**What people do:** Directly delete fields from the `@Model` class and ship without a migration plan, relying on SwiftData to figure it out.

**Why it's wrong:** SwiftData may crash or fail silently on first launch when the on-disk schema does not match the in-code schema. This is not guaranteed to work as an implicit migration.

**Do this instead:** Define `PlayerSchemaV1` (preserving the current model verbatim), define `PlayerSchemaV2` (the new shape), declare `SchemaMigrationPlan` with a lightweight stage, and pass the plan to `modelContainer`.

## Integration Points

### External Frameworks

| Framework | Integration Pattern | Notes |
|-----------|---------------------|-------|
| `Contacts` | `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)` for live fetch; `CNContact.identifier` stored as `String` | Fetch only the keys you display: `[.givenName, .familyName, .phoneNumbers, .emailAddresses]` |
| `ContactsUI` | `CNContactPickerViewController` wrapped in `UIViewControllerRepresentable` | Must wrap in `UINavigationController` — see anti-pattern above |
| `UIApplication` | `UIApplication.shared.open(URL(string: "tel://...")!)` for actions | Scheme URLs: `tel://`, `sms://`, `mailto://`. Check `canOpenURL` before calling. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| View → ContactsService | Direct async call | Views `await` service methods inside `.task` |
| View → ContactPickerRepresentable | Closure callback `onSelect: (CNContact) -> Void` | Picker hands back a `CNContact`; view extracts `.identifier` and writes to model |
| ContactPickerRepresentable → Player | Indirect (via view state) | Picker does not write to SwiftData; the view that owns the player does |
| ContactsService → Player | None | Service has no knowledge of the model layer; it receives `[String]` IDs and returns `[CNContact]` |

## Build Order Implications

The components have a clear dependency chain that dictates build order:

1. **SwiftData migration infrastructure first** — `PlayerSchemaV1`, `PlayerSchemaV2`, `PlayerMigrationPlan`. Nothing else can be tested until the model compiles with the new shape.
2. **ContactsService second** — Pure logic, no UI. Testable in isolation. All subsequent components depend on it.
3. **ContactPickerRepresentable third** — Depends only on `Contacts`/`ContactsUI` frameworks, no SwiftData dependency.
4. **PlayerFormView update fourth** — Depends on the updated `Player` model and `ContactPickerRepresentable`.
5. **PlayerDetailView / ContactRowView last** — Depends on `ContactsService` for live fetch and on the updated `Player` model for identifiers.

## Sources

- [CNContactPickerViewController — Apple Developer Documentation](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller)
- [CNContactStore.unifiedContact(withIdentifier:keysToFetch:) — Apple Developer Documentation](https://developer.apple.com/documentation/contacts/cncontactstore/1403256-unifiedcontact)
- [CNContact.identifier — Apple Developer Documentation](https://developer.apple.com/documentation/contacts/cncontact/1403103-identifier)
- [SchemaMigrationPlan — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [Contact Management: Working with the Contact Picker View Controller — createwithswift.com](https://www.createwithswift.com/contact-management-working-with-the-contact-picker-view-controller/) (MEDIUM confidence — independent blog, verified against Apple docs)
- [How to create a complex migration using VersionedSchema — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) (MEDIUM confidence — well-regarded community resource)
- [SwiftData schema migration — tanaschita.com](https://tanaschita.com/20231120-migration-with-swiftdata/) (MEDIUM confidence)
- [CNContactIdentifierKey is not persistent — Apple Developer Forums](https://developer.apple.com/forums/thread/26379) (MEDIUM confidence — flags identifier stability edge cases with CardDAV)

---
*Architecture research for: iOS Contacts framework integration (PigeonPlay)*
*Researched: 2026-03-22*
