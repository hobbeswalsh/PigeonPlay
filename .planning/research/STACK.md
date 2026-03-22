# Stack Research

**Domain:** iOS Contacts framework integration in SwiftUI/SwiftData app
**Researched:** 2026-03-22
**Confidence:** HIGH — all recommendations verified against Apple developer documentation and official WWDC sessions

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Contacts (`import Contacts`) | iOS 9+ / iOS 18 | Read/fetch contact data by identifier; store `CNContact.identifier` strings in SwiftData | The only Apple-native way to access the system address book. `CNContact.identifier` is a stable, persistent string suitable for long-term storage. `unifiedContact(withIdentifier:keysToFetch:)` fetches a contact at any time given only that string. |
| ContactsUI (`import ContactsUI`) | iOS 9+ / iOS 18 | `CNContactPickerViewController` — system contact picker UI | Required for presenting the system Contacts picker. Does not require a prior authorization prompt (the picker itself is the gated access point), which simplifies the permission flow for this use case. |
| SwiftUI `@Environment(\.openURL)` | iOS 14+ | Tap-to-call (`tel:`), tap-to-text (`sms:`), tap-to-email (`mailto:`) | Built into SwiftUI. No additional frameworks. Passes control to the system Phone/Messages/Mail apps. `Link` view is the declarative alternative when you don't need programmatic control. |
| SwiftData `VersionedSchema` + `SchemaMigrationPlan` | iOS 17+ | Model migration: drop `parentName`/`parentPhone`/`parentEmail`, add `phone` and `contactIdentifiers` | Required whenever changing a SwiftData model that has already shipped to devices. Dropping fields and adding fields with default values both qualify as lightweight migrations — no custom migration stage code needed. |

### Supporting APIs

| API | Version | Purpose | When to Use |
|-----|---------|---------|-------------|
| `CNContactPickerDelegate.contactPicker(_:didSelect:)` | iOS 9+ | Callback with the selected `CNContact`; extract `.identifier` here | Every contact-linking flow. Extract `contact.identifier` in this delegate method and store it in SwiftData. Do not store the `CNContact` object itself — it is not persistable. |
| `CNContactPickerDelegate.contactPickerDidCancel(_:)` | iOS 9+ | Dismiss picker without changes | Handle so the picker dismisses cleanly; required for the `UIViewControllerRepresentable` coordinator. |
| `CNContact.predicateForContacts(withIdentifiers:)` + `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)` | iOS 9+ | Fetch live contact data from stored identifiers | Every time contact info is displayed. Fetch on demand (not at startup), specify only the keys you need (`[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey]`). |
| `CNContactStore.authorizationStatus(for: .contacts)` | iOS 9+ / `.limited` case iOS 18 | Check current authorization level before fetch attempts | Before any `CNContactStore` fetch. Handle `.authorized`, `.limited`, `.denied`, `.notDetermined`, `.restricted`. |
| `ContactAccessButton` + `.contactAccessPicker()` modifier | iOS 18+ | Grant additional contacts under Limited access without full re-authorization | Only needed if the app uses `CNContactStore` directly and the user granted Limited access. For this project's flow (picker-based selection, identifier storage), this is a secondary concern — see Notes below. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode Privacy manifest / Info.plist `NSContactsUsageDescription` | Required privacy string for App Store submission | Must be present even though `CNContactPickerViewController` does not trigger a runtime prompt — `CNContactStore` fetches (for live data display) do. Keep the description specific: "PigeonPlay uses your contacts to display information about players' parents and guardians." |

## Installation

This milestone requires no new package dependencies. Add two new import statements to affected files:

```swift
import Contacts      // CNContact, CNContactStore, CNContactPickerDelegate
import ContactsUI    // CNContactPickerViewController
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `CNContactPickerViewController` (UIViewControllerRepresentable) for picking | `ContactAccessButton` (iOS 18 only) | Use `ContactAccessButton` only if you need an in-flow, incremental contact-granting UX embedded in a search field. For this project's "link a contact to a player" flow, `CNContactPickerViewController` is correct: it is a deliberate, discrete action, available at all authorization levels, and does not require managing authorization state before the picker is presented. |
| Store `CNContact.identifier` (String) in SwiftData | Store full contact snapshot (name, phone, email) in SwiftData | Use snapshots only if the app must work offline with no contacts access. The requirement explicitly rules this out — live reference is the intent. |
| `@Environment(\.openURL)` with `tel:`/`sms:`/`mailto:` | `MessageUI.MFMessageComposeViewController` / `MFMailComposeViewController` | Use MessageUI only if the app needs to compose the message body in-app (pre-fill, tracking sends, attachments). For simple tap-to-dial/text/email, the URL scheme approach requires zero additional frameworks and zero UI code. |
| SwiftData `VersionedSchema` lightweight migration | Custom migration stage | Custom migration is needed only when field values must be transformed (e.g., splitting one column into two, or populating a new field from existing data). Dropping three nullable fields and adding a nullable String and an empty array both qualify as lightweight — no migration closure code is required. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Storing `CNContact` objects or snapshots of contact data | Stale data. Contact phone numbers and names change. The requirement explicitly calls for live reference. Snapshot storage also makes you responsible for sync. | Store `CNContact.identifier` (a stable String) and fetch live via `CNContactStore.unifiedContact(withIdentifier:keysToFetch:)` at display time. |
| Requesting full Contacts authorization upfront with `CNContactStore.requestAccess(for:)` | iOS 18 introduces `CNAuthorizationStatusLimited` — users can grant limited access (a subset of contacts). More importantly, `CNContactPickerViewController` does not require any prior authorization at all; the picker is itself the privacy boundary. Requesting upfront authorization adds an unnecessary prompt and increases permission denial risk. | Let `CNContactPickerViewController` handle the first contact selection with zero upfront prompt. Only call `CNContactStore.requestAccess(for:)` if the app needs to fetch contacts outside of a picker flow — which it does (for displaying linked contact data). Request access at the point the user taps to view a linked contact, not at app launch. |
| `ABAddressBook` / `AddressBook.framework` | Deprecated since iOS 9, removed in iOS 14+. | Contacts framework. |
| Third-party contact picker libraries (KNContactsPicker, SwiftyContacts, etc.) | This project has a strict no-third-party-dependency constraint. These libraries also add unnecessary abstraction over an API that is well-documented and stable. | Apple's Contacts + ContactsUI frameworks directly. |
| Persisting `[CNContact]` in memory across app lifecycle | `CNContact` is not `Sendable` in Swift 6 strict concurrency mode. Holding references across actor boundaries will produce compiler errors. | Extract what you need (identifier, display values) immediately in the delegate callback and store only `String` or value types. |

## Stack Patterns by Variant

**For the contact-linking flow (player + contacts):**
- Wrap `CNContactPickerViewController` in `UIViewControllerRepresentable` with a `Coordinator: NSObject, CNContactPickerDelegate`
- In `contactPicker(_:didSelect:)`, extract `contact.identifier` and append to `player.contactIdentifiers: [String]`
- Support multi-select by also implementing `contactPicker(_:didSelectContacts:)` if multiple contacts per player are required
- No authorization request is needed before presenting the picker

**For the contact-display flow (show linked contact info):**
- On display, call `CNContactStore().authorizationStatus(for: .contacts)`
- If `.notDetermined`, call `requestAccess(for: .contacts)` and handle the result
- If `.authorized` or `.limited`, call `unifiedContact(withIdentifier:keysToFetch:)` for each stored identifier
- If `.limited` and the stored contact identifier is not in the limited set, the fetch will return a `CNContact` with empty fields — handle gracefully (show "Contact no longer accessible")
- Run fetches off the main actor; wrap in `Task` or an `async` function

**For tap-to-call/text/email:**
- Use `@Environment(\.openURL)` with `URL(string: "tel://\(phoneNumber)")`, `URL(string: "sms://\(phoneNumber)")`, `URL(string: "mailto:\(email)")`
- Strip non-digit characters from phone numbers before constructing `tel:` URLs
- Use SwiftUI `Link` view for static display; use `openURL` in a `Button` for dynamic/conditional behavior

**For the SwiftData migration:**
- Wrap the current `Player` definition in `enum SchemaV1: VersionedSchema`
- Create `enum SchemaV2: VersionedSchema` with `parentName`/`parentPhone`/`parentEmail` removed and `phone: String?` + `contactIdentifiers: [String]` added
- `contactIdentifiers` must default to `[]`; `phone` is optional (defaults to `nil`) — both qualify as lightweight
- Create `enum PlayerMigrationPlan: SchemaMigrationPlan` with `stages: [.lightweight(SchemaV1.self, SchemaV2.self)]`
- Pass `migrationPlan: PlayerMigrationPlan.self` to `ModelContainer`

## Version Compatibility

| Framework | iOS Minimum | Notes |
|-----------|-------------|-------|
| Contacts | iOS 9.0 | All required APIs available. `CNAuthorizationStatusLimited` is iOS 18+ only — check with `#available(iOS 18, *)` when inspecting authorization status. |
| ContactsUI (`CNContactPickerViewController`) | iOS 9.0 | Available and unchanged in iOS 18. The picker does not trigger the system authorization dialog. |
| `ContactAccessButton` | iOS 18.0 | Not needed for this milestone's core flow, but relevant if handling Limited authorization edge cases. |
| SwiftData `VersionedSchema` | iOS 17.0 | App already targets iOS 18.0 — no issue. |
| `@Environment(\.openURL)` | iOS 14.0 | App already targets iOS 18.0 — no issue. |

## Sources

- [Meet the Contact Access Button — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10121/) — `ContactAccessButton` vs `CNContactPickerViewController` distinction, Limited access flow (HIGH confidence)
- [CNContactPickerViewController — Apple Developer Documentation](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller) — delegate methods, no-auth-required behavior (HIGH confidence)
- [unifiedContact(withIdentifier:keysToFetch:) — Apple Developer Documentation](https://developer.apple.com/documentation/contacts/cncontactstore/1403256-unifiedcontact) — fetching by identifier (HIGH confidence)
- [Lightweight vs complex migrations — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/lightweight-vs-complex-migrations) — what qualifies as lightweight (MEDIUM confidence, verified against Apple forums)
- [How to create a complex migration using VersionedSchema — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) — migration pattern (MEDIUM confidence)
- [Contact Management: Working with CNContactPickerViewController — Create with Swift](https://www.createwithswift.com/contact-management-working-with-the-contact-picker-view-controller/) — UIViewControllerRepresentable coordinator pattern (MEDIUM confidence)
- [How to read user contacts with ContactAccessButton — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-read-user-contacts-with-contactaccessbutton) — ContactAccessButton usage, identifier persistence pattern (MEDIUM confidence)
- [iOS 18 CNAuthorizationStatusLimited — react-native-permissions issue thread](https://github.com/zoontek/react-native-permissions/issues/894) — behavior of `.limited` status (MEDIUM confidence — cross-platform issue, behavior confirmed by Apple docs)

---
*Stack research for: iOS Contacts framework integration in PigeonPlay (SwiftUI/SwiftData, iOS 18.0+)*
*Researched: 2026-03-22*
