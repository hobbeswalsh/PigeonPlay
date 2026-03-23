# PigeonPlay — Contact Management

## What This Is

PigeonPlay is an iOS app for managing youth sports team rosters, tracking games with line suggestions, and drawing up plays. This milestone adds contact management — linking players to their phone numbers and iOS Contacts for quick communication with parents/guardians.

## Core Value

Coaches can quickly reach a player's contacts (parents, guardians) directly from the roster without leaving the app.

## Requirements

### Validated

- ✓ Player roster management (name, gender, gender matching) — existing
- ✓ Game creation and tracking with point-by-point scoring — existing
- ✓ Line suggestion algorithm based on bench time and gender ratio — existing
- ✓ Playbook canvas with drawing tools — existing
- ✓ Game history with detail views — existing

### Active

- [x] Optional phone number stored directly on each player — Phase 2
- [x] Link 0+ iOS Contacts to each player via contact identifiers (live reference) — Phase 2
- [ ] View linked contact info (name, phone, email) pulled live from Contacts framework
- [ ] Tap-to-call, tap-to-text, tap-to-email from linked contact info
- [ ] Contacts framework permission request flow
- [x] Remove existing parentName, parentPhone, parentEmail fields from Player model — Phase 1

### Out of Scope

- Relationship labels on linked contacts — unnecessary complexity for this use case
- Storing snapshot copies of contact data — live reference keeps things simple and current
- Migrating existing parent contact data — user confirmed drop-it approach
- Contact search/filtering within the app — iOS Contacts picker handles this
- Group messaging or bulk communication features — future capability

## Context

- App targets iOS 18.0+ with Swift 6.0 and SwiftData persistence
- No third-party dependencies — all Apple frameworks
- Player model currently has `parentName`, `parentPhone`, `parentEmail` fields that will be removed
- Will need `import Contacts` and `import ContactsUI` for the Contacts framework
- CNContactPickerViewController (via UIViewControllerRepresentable) is the standard way to pick contacts in SwiftUI
- Contact identifiers (`CNContact.identifier`) are stable strings that persist across app launches
- SwiftData schema migration will be needed to drop old fields and add new ones

## Constraints

- **Platform**: iOS 18.0+ only — can use latest Contacts framework APIs
- **Privacy**: Must request Contacts access with a clear usage description in Info.plist
- **Data model**: SwiftData migration required — dropping 3 fields, adding phone + contact identifier storage
- **No third-party deps**: Stay with Apple frameworks only

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Live contact reference (ID only) | Always shows current info, no stale data to manage | — Pending |
| Drop existing parent fields without migration | User confirmed data loss is acceptable | — Pending |
| No relationship labels on contacts | Keeps the model simple, not needed for quick-dial use case | — Pending |
| Player's own phone number as separate field | Distinct from linked contacts — player's direct number | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-22 after Phase 2 completion*
