# Feature Research

**Domain:** Contact management integration in iOS youth sports roster app
**Researched:** 2026-03-22
**Confidence:** HIGH (requirements already validated in PROJECT.md; research confirms patterns)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Link iOS Contact to a player | Core premise — coaches already have parents in Contacts; re-entering data is a dealbreaker | MEDIUM | Use `CNContactPickerViewController` via `UIViewControllerRepresentable`; no permission prompt needed since app only sees final selection |
| View linked contact's name, phone, email | Useless to store a link if you can't see the data | LOW | Fetch live via `CNContactStore` using stored `CNContact.identifier`; always current |
| Tap-to-call a phone number | Every coach's first instinct — one tap to reach a parent | LOW | `tel://` URL scheme; standard iOS pattern |
| Tap-to-text a phone number | Near-universal expectation on iOS; texting is primary parent communication channel | LOW | `sms://` URL scheme; opens Messages |
| Tap-to-email an address | Required for formal communications; coaches expect it alongside call/text | LOW | `mailto://` URL scheme |
| Contacts permission flow | Required by iOS to access contact data at all | LOW | In-app usage description in Info.plist; only needed when fetching stored contacts, not when using the picker |
| Remove / unlink a contact from a player | Any link management UI must allow un-linking | LOW | Delete identifier from stored array; no Contacts framework involvement |
| Store player's own phone number | Player's direct number is distinct from guardian contacts and must have a home | LOW | Simple `String?` field on `Player` model; SchemaV2 migration |
| Drop legacy parent fields | Existing `parentName`, `parentPhone`, `parentEmail` fields are now redundant | LOW | SwiftData schema migration; user confirmed data loss acceptable |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Multiple contacts per player | Most youth players have two guardians; linking both prevents a separate app for the second parent | LOW | Store `[String]` of contact identifiers; iterate to display each |
| Live contact data (never stale) | Apps that cache contact snapshots break silently when parents change numbers; live reference stays correct | LOW | This IS the chosen architecture — fetch by identifier at display time; no extra work, but worth calling out as a deliberate win |
| iOS 18 `ContactAccessButton` for search | Inline contact search that surfaces ungranted contacts without a full permission prompt; polished privacy-respecting UX | MEDIUM | Available iOS 18+ (matches deployment target); `ContactAccessButton` + `.contactAccessButtonCaption` modifier; adds a search flow on top of the picker |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Snapshot/copy contact data into the app | "What if contacts change?" or "works offline" | Creates stale data to manage; defeats live-reference model; requires manual re-sync; bloats SwiftData store | Store only `CNContact.identifier`; fetch live at display time |
| Relationship labels on contacts (Mom, Dad, Coach) | Feels like useful metadata | Adds a free-text or enum field per contact-player pair; coaches won't maintain it; query value is low | Position in display list is sufficient context for a 2-3 contact list |
| Group messaging / bulk contact blast | Common ask from coaches wanting mass communication | This is a platform (TeamSnap, Spond) feature requiring server infrastructure and opt-in; far out of scope for a local-only app | Defer to OS: coach can select multiple contacts from the roster and initiate a group thread manually |
| In-app contact editing | "One stop shop" UX appeal | Contacts are shared system data owned by the user; editing them from a third-party app creates surprising mutations; Apple's Contacts app is the right place | Deep-link to Contacts.app if editing is needed |
| Full Contacts list access / browsing | Power-user discoverability | iOS 18's limited access model makes full Contacts permission increasingly difficult to justify and obtain; users distrust it | `CNContactPickerViewController` (no permission required) + `ContactAccessButton` (limited grant) covers all real use cases |
| Storing contact photo in SwiftData | Profile picture on player card | Binary data bloat; photo in Contacts.app is already accessible live; not needed for quick-dial use case | Fetch `CNContact.thumbnailImageData` at display time if ever needed |

## Feature Dependencies

```
[Contacts permission/Info.plist usage description]
    └──required by──> [Fetch contact details by CNContact.identifier]
                          └──required by──> [Display contact name / phone / email]
                                                └──enables──> [Tap-to-call / tap-to-text / tap-to-email]

[CNContactPickerViewController (UIViewControllerRepresentable)]
    └──required by──> [Link iOS Contact to player]
                          └──populates──> [Stored CNContact.identifier array on Player]
                                              └──feeds──> [Fetch contact details by CNContact.identifier]

[SwiftData schema migration (SchemaV2)]
    └──required by──> [Player.phone field addition]
    └──required by──> [Remove parentName/parentPhone/parentEmail fields]

[ContactAccessButton (iOS 18)]
    └──enhances──> [Link iOS Contact to player] (surfaces contacts not yet granted)
    └──requires──> [Contacts permission/Info.plist usage description]
```

### Dependency Notes

- **Contacts permission requires Info.plist entry:** `NSContactsUsageDescription` must be present before any `CNContactStore` fetch; the picker itself does not require permission but fetching stored contacts does.
- **Schema migration gates player.phone and contact identifier storage:** Must happen before any contact-linking UI can persist data. Drop and add happen in the same migration version.
- **ContactAccessButton enhances but does not replace the picker:** The picker (`CNContactPickerViewController`) is the primary link-a-contact flow. `ContactAccessButton` is an additive search UX, not a replacement.
- **Tap-to-X requires display first:** Can't provide call/text/email actions without first displaying the linked contact's data — display is a prerequisite.

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] SwiftData schema migration: drop `parentName`/`parentPhone`/`parentEmail`, add `phone: String?`, add `contactIdentifiers: [String]` — foundational; nothing else works without it
- [ ] `CNContactPickerViewController` wrapper for linking a contact to a player — primary interaction
- [ ] Fetch and display linked contact name/phone/email live from `CNContactStore` — shows the value
- [ ] Tap-to-call, tap-to-text, tap-to-email — converts display into action; core value prop
- [ ] Unlink a contact from a player — any link UI must allow correction
- [ ] Player direct phone number field in edit view — separate from linked contacts

### Add After Validation (v1.x)

- [ ] `ContactAccessButton` search flow — adds polish once core linking works; requires confirming iOS 18 limited-access flow UX is worth the complexity
- [ ] Multiple contacts per player displayed in a clean list — straightforward once single-contact display is working

### Future Consideration (v2+)

- [ ] Group messaging — requires server infrastructure; out of scope for local app
- [ ] Relationship labels — low value, deferred until coaches explicitly request it with a clear use case

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Schema migration (phone + identifiers) | HIGH | LOW | P1 |
| CNContactPickerViewController link flow | HIGH | MEDIUM | P1 |
| Display linked contact info (live fetch) | HIGH | LOW | P1 |
| Tap-to-call / tap-to-text / tap-to-email | HIGH | LOW | P1 |
| Unlink contact | HIGH | LOW | P1 |
| Player phone number field | MEDIUM | LOW | P1 |
| Multiple contacts per player | MEDIUM | LOW | P2 |
| ContactAccessButton search | MEDIUM | MEDIUM | P2 |
| Relationship labels | LOW | MEDIUM | P3 |
| Group messaging | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | TeamSnap | Spond | PigeonPlay Approach |
|---------|----------|-------|---------------------|
| Contact storage | Own database, manual entry | Own database, manual entry | Live reference to iOS Contacts — no re-entry |
| Multiple contacts per player | Yes (family members) | Yes (guardians) | Yes, via multiple CNContact identifiers |
| Tap-to-call | Yes | Yes | Yes, via `tel://` URL scheme |
| Group messaging | Yes (in-app) | Yes (in-app) | Out of scope — defer to OS |
| Permission model | Own login/account | Own login/account | iOS Contacts permission only — no account needed |
| Stale data risk | High (manual updates) | High (manual updates) | None — live fetch from system Contacts |

## Sources

- [Apple Developer: CNContactPickerViewController](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller)
- [Apple Developer: CNContact.identifier](https://developer.apple.com/documentation/contacts/cncontact/1403103-identifier)
- [WWDC24: Meet the Contact Access Button](https://developer.apple.com/videos/play/wwdc2024/10121/)
- [HackingWithSwift: ContactAccessButton](https://www.hackingwithswift.com/quick-start/swiftui/how-to-read-user-contacts-with-contactaccessbutton)
- [CreateWithSwift: CNContactPickerViewController in SwiftUI](https://www.createwithswift.com/contact-management-working-with-the-contact-picker-view-controller/)
- [TeamSnap roster/contact features](https://www.teamsnap.com/teams/features/rosters)
- [Spond: 5 Best Sports Team Management Apps 2025](https://www.spond.com/en-us/news-and-blog/5-best-sports-team-management-apps/)

---
*Feature research for: iOS contact management in youth sports roster app (PigeonPlay)*
*Researched: 2026-03-22*
