# Project Research Summary

**Project:** PigeonPlay Contacts Integration (roster-manager)
**Domain:** iOS Contacts framework integration in a SwiftUI/SwiftData youth sports roster app
**Researched:** 2026-03-22
**Confidence:** HIGH

## Executive Summary

PigeonPlay is an iOS-native team roster app built with SwiftUI and SwiftData. The milestone under research adds contact management: linking iOS Contacts to players, displaying live contact info (name, phone, email), and providing tap-to-call/text/email. The entire feature set is achievable using only Apple's built-in `Contacts` and `ContactsUI` frameworks with no third-party dependencies, which aligns with the project's existing constraint. The recommended approach is identifier-only persistence — store `CNContact.identifier` strings in SwiftData, never copy contact data into the model, and fetch live from `CNContactStore` at display time. This is the correct choice for freshness and avoids a whole class of sync complexity.

The central risk of this milestone is the SwiftData schema migration. The current `Player` model has no `VersionedSchema`, and dropping three fields while adding two new ones without properly versioning the schema first will crash every existing user on upgrade. The safe approach requires a two-step strategy: ship a V1 versioned schema first (model unchanged), then ship V2 with the actual field changes. Given the app's current small user base, both steps can be compressed into one release only if there are no existing TestFlight or App Store users with persisted data — but this is a known risk if that assumption is wrong.

The contact picker flow (`CNContactPickerViewController`) requires no upfront permission prompt, which simplifies the UX significantly. However, re-fetching stored identifiers via `CNContactStore` does require permission, and `NSContactsUsageDescription` must be in the Info.plist from day one. iOS 18's `CNAuthorizationStatus.limited` case is a real concern given the deployment target and must be handled explicitly in the permission flow.

## Key Findings

### Recommended Stack

No new package dependencies are needed. The feature is built entirely on `import Contacts` and `import ContactsUI`, both available since iOS 9 and fully supported on the iOS 18 deployment target. SwiftData's `VersionedSchema` and `SchemaMigrationPlan` are the correct migration path; dropping optional fields and adding optional fields or empty-array defaults both qualify as lightweight migrations — no custom migration closure code is required.

**Core technologies:**
- `Contacts` (`CNContactStore`, `CNContact`): Live contact data lookup by stored identifier — the only correct approach for live-reference semantics
- `ContactsUI` (`CNContactPickerViewController`): System contact picker, out-of-process, no upfront permission required
- `@Environment(\.openURL)` / `UIApplication.shared.open`: Tap-to-call (`tel:`), tap-to-text (`sms:`), tap-to-email (`mailto:`) — zero additional frameworks needed
- `SwiftData VersionedSchema` + `SchemaMigrationPlan`: Required schema migration; drop `parentName`/`parentPhone`/`parentEmail`, add `phone: String?` and `contactIdentifiers: [String]`

### Expected Features

**Must have (table stakes):**
- SwiftData schema migration (V1 → V2): drops legacy parent fields, adds `phone` and `contactIdentifiers` — nothing else works without it
- `CNContactPickerViewController` link flow — the primary user action to associate an iOS Contact with a player
- Live contact display (name, phone, email via `CNContactStore`) — validates the value of the link
- Tap-to-call, tap-to-text, tap-to-email — converts display into action; core value proposition
- Unlink a contact from a player — any link UI must allow correction
- Player's own phone number field in the edit view — distinct from guardian contacts

**Should have (competitive):**
- Multiple contacts per player — most youth athletes have two guardians; `[String]` identifier array already supports this with minimal extra work
- Live contact data (never stale) — this is the deliberate architecture, not an afterthought; worth validating as the key differentiator over TeamSnap/Spond

**Defer (v2+):**
- `ContactAccessButton` search flow (iOS 18) — adds polish once core linking works; confirm limited-access UX is worth the added complexity first
- Relationship labels (Mom, Dad, etc.) — low coach maintenance, low query value; defer unless explicitly requested
- Group messaging — requires server infrastructure; out of scope for a local app

### Architecture Approach

The feature maps cleanly onto four new/modified components sitting above two Apple framework boundaries. The `Player` SwiftData model grows a `contactIDs: [String]` array and a `phoneNumber: String?` field. A new `ContactsService` enum with static async methods centralizes all `CNContactStore` interactions and keeps views free of authorization logic. A `ContactPickerRepresentable` (`UIViewControllerRepresentable`) bridges the UIKit picker into SwiftUI; it must wrap `CNContactPickerViewController` in a `UINavigationController` or the picker sheet will appear blank. The view layer splits into `PlayerFormView` (edit + link) and `PlayerDetailView` (read + call/text/email), with `ContactRowView` as a reusable subview for each linked contact.

**Major components:**
1. `ContactPickerRepresentable` — UIKit bridge wrapping `CNContactPickerViewController` in `UINavigationController`; hands back identifier via closure callback
2. `ContactsService` — enum with static async methods; single chokepoint for all `CNContactStore` access; handles authorization status check, access request, and fetch-by-identifier
3. `Player` (updated) — `contactIDs: [String]` and `phoneNumber: String?` added via `VersionedSchema` lightweight migration
4. `PlayerDetailView` / `ContactRowView` — display live-fetched contact data, provide tap-to-call/text/email actions
5. `PlayerFormView` (updated) — contacts section with link/unlink actions, triggers picker sheet

### Critical Pitfalls

1. **Shipping schema migration without first versioning the existing model** — the current `Player` has no `VersionedSchema`; adding a migration plan that references an unrecognized on-disk version crashes on launch for all existing users. Prevention: wrap current model in `SchemaV1` first, ship it, then define `SchemaV2` with actual changes.

2. **`CNContactPickerViewController` presented without `UINavigationController` wrapper** — the picker renders as a blank sheet. Prevention: always `return UINavigationController(rootViewController: picker)` from `makeUIViewController`; never return the picker directly.

3. **Accessing a `CNContact` property not included in `keysToFetch`** — throws `CNPropertyNotFetchedException` immediately with no graceful fallback. Prevention: define a single shared `contactKeys: [CNKeyDescriptor]` constant used everywhere; never inline separate key arrays per call site.

4. **iOS 18 `CNAuthorizationStatus.limited` treated as `.denied` or ignored** — returns an empty result set with no error, causing linked contacts to silently appear deleted. Prevention: handle all four auth cases explicitly; treat `.limited` like `.authorized` for `unifiedContact(withIdentifier:)` calls, and handle `CNErrorCodeRecordDoesNotExist` gracefully when the specific contact is outside the permitted set.

5. **Storing contact data snapshots in SwiftData instead of the identifier** — creates stale data that misleads coaches silently. Prevention: enforce at schema review; no field named `contactName`, `contactPhone`, or `contactEmail` should appear on `Player`.

## Implications for Roadmap

Based on the build-order dependency chain identified in architecture research:

### Phase 1: Schema Migration
**Rationale:** The `Player` model must be in its new shape before any other component can be written or tested. The migration is a foundational dependency — not just a cleanup item. More importantly, the two-step migration risk (unversioned base model) means V1 schema wrapping should happen in isolation so it can ship cleanly before V2 changes are introduced.
**Delivers:** `PlayerSchemaV1`, `PlayerSchemaV2`, `PlayerMigrationPlan`; updated `PigeonPlayApp.swift` with `migrationPlan:`; `Player.contactIDs` and `Player.phoneNumber` fields live; legacy parent fields removed.
**Addresses:** Schema migration table-stakes feature; player phone number field.
**Avoids:** Unversioned-schema crash pitfall (Pitfall 1); storing contact data in model (Pitfall 5).

### Phase 2: Contact Picker Integration
**Rationale:** Linking a contact is the entry point for all downstream features. Nothing can be displayed or called without first storing an identifier. `ContactPickerRepresentable` has no SwiftData dependency beyond the already-migrated model, making it the natural next step.
**Delivers:** `ContactPickerRepresentable.swift` (UIKit bridge), updated `PlayerFormView` with contacts section (add/unlink), `NSContactsUsageDescription` in `project.yml`.
**Addresses:** Link contact to player (table stakes); unlink contact (table stakes).
**Avoids:** Blank picker sheet (Pitfall 2); upfront permission prompt before picker (Pitfall 2 / UX pitfalls).

### Phase 3: Contact Display and Actions
**Rationale:** With identifiers stored, the display and action layer can be built and tested end-to-end. `ContactsService` is a pure service with no UI dependencies — build it first in this phase, then the views that consume it.
**Delivers:** `ContactsService.swift` (auth check, fetch-by-identifier); `PlayerDetailView.swift`; `ContactRowView.swift`; tap-to-call/text/email via `UIApplication.shared.open`.
**Addresses:** Live contact display (table stakes); tap-to-call/text/email (table stakes); multiple contacts per player (differentiator).
**Avoids:** `keysToFetch` mismatch crash (Pitfall 3); iOS 18 limited access silent failure (Pitfall 4); `CNContactStore` called from views directly (architecture anti-pattern 3).

### Phase Ordering Rationale

- The dependency chain from architecture research is explicit: migration → picker → service → views. Violating this order means writing code against a model that doesn't compile yet or building UI before the persistence layer exists.
- The schema migration is deliberately isolated as Phase 1 because the two-step migration risk is the highest-severity pitfall in the project. Giving it its own phase ensures it gets reviewed and tested before anything depends on it.
- `ContactsService` and the display views are grouped in Phase 3 because the service is only testable once real identifiers can be stored (Phase 2), and the views are only meaningful once the service works.

### Research Flags

Phases with well-documented patterns (can skip `/gsd:research-phase`):
- **Phase 1 (Schema Migration):** The `VersionedSchema` pattern is well-documented in Apple docs and Hacking with Swift; the exact migration plan structure is specified in STACK.md and ARCHITECTURE.md with code examples.
- **Phase 2 (Contact Picker):** `CNContactPickerViewController` + `UIViewControllerRepresentable` is a well-understood pattern; the `UINavigationController` wrapper gotcha is documented in ARCHITECTURE.md with a full code example.
- **Phase 3 (Display + Actions):** URL scheme tap-to-call/text/email is boilerplate. `ContactsService` design is fully specified in ARCHITECTURE.md.

No phases require additional research before execution. All key implementation details are covered in the research files at HIGH confidence.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommendations verified against Apple official docs and WWDC24 session material |
| Features | HIGH | Requirements already validated in PROJECT.md; research confirms expected patterns and competitive positioning |
| Architecture | HIGH | All findings verified against Apple official docs or developer forum discussions; code examples provided for every major pattern |
| Pitfalls | HIGH | Multiple primary sources including Apple Developer Forums for the most critical pitfalls; confirmed by practical community sources |

**Overall confidence:** HIGH

### Gaps to Address

- **Two-step migration risk:** Whether to compress V1 and V2 into a single release or ship them separately depends on whether any users have existing persisted data. This is a deployment decision, not a technical one — flag it before Phase 1 ships.
- **`CNContact.identifier` cross-device stability:** Low risk for this single-device app currently, but if any iCloud sync feature is ever added, stored identifiers may break after restore-to-new-device. The error handling for `CNErrorCodeRecordDoesNotExist` (Phase 3) mitigates this partially, but the user experience of re-linking all contacts after a device restore is poor. Track as a future concern.
- **`ContactAccessButton` (iOS 18) deferred to v1.x:** The decision to defer the search-flow enhancement is correct for the MVP, but the limited-access permission handling in Phase 3 should be implemented robustly enough that adding `ContactAccessButton` later does not require a redesign.

## Sources

### Primary (HIGH confidence)
- [CNContactPickerViewController — Apple Developer Documentation](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller)
- [CNContactStore.unifiedContact(withIdentifier:keysToFetch:) — Apple Developer Documentation](https://developer.apple.com/documentation/contacts/cncontactstore/1403256-unifiedcontact)
- [CNContact.identifier — Apple Developer Documentation](https://developer.apple.com/documentation/contacts/cncontact/1403103-identifier)
- [SchemaMigrationPlan — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [Meet the Contact Access Button — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10121/)

### Secondary (MEDIUM confidence)
- [Lightweight vs complex migrations — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/lightweight-vs-complex-migrations) — what qualifies as lightweight; verified against Apple forums
- [How to create a complex migration using VersionedSchema — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) — migration pattern
- [Contact Management: Working with CNContactPickerViewController — Create with Swift](https://www.createwithswift.com/contact-management-working-with-the-contact-picker-view-controller/) — UIViewControllerRepresentable coordinator pattern
- [How to read user contacts with ContactAccessButton — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-read-user-contacts-with-contactaccessbutton) — identifier persistence pattern
- [Never use SwiftData without VersionedSchema — Mert Bulan](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema)
- [SwiftData unversioned migration crash — Apple Developer Forums](https://developer.apple.com/forums/thread/761735)
- [CNContactPickerViewController does not require permission — Apple Developer Forums](https://developer.apple.com/forums/thread/12275)
- [tanaschita.com: SwiftData schema migration](https://tanaschita.com/20231120-migration-with-swiftdata/)

### Tertiary (MEDIUM confidence, cross-platform confirmation)
- [iOS 18 CNAuthorizationStatusLimited — react-native-permissions issue #894](https://github.com/zoontek/react-native-permissions/issues/894) — `.limited` behavior confirmed by Apple docs independently

---
*Research completed: 2026-03-22*
*Ready for roadmap: yes*
