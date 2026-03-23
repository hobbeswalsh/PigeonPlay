# PigeonPlay — Contact Management

## What This Is

PigeonPlay is an iOS app for managing youth sports team rosters, tracking games with line suggestions, and drawing up plays. The app now includes contact management — coaches can link players to iOS Contacts and reach parents/guardians with one tap.

## Core Value

Coaches can quickly reach a player's contacts (parents, guardians) directly from the roster without leaving the app.

## Requirements

### Validated

- ✓ Player roster management (name, gender, gender matching) — existing
- ✓ Game creation and tracking with point-by-point scoring — existing
- ✓ Line suggestion algorithm based on bench time and gender ratio — existing
- ✓ Playbook canvas with drawing tools — existing
- ✓ Game history with detail views — existing
- ✓ Optional phone number stored directly on each player — v1.0
- ✓ Link 0+ iOS Contacts to each player via contact identifiers (live reference) — v1.0
- ✓ View linked contact info (name, phone, email) pulled live from Contacts framework — v1.0
- ✓ Tap-to-call, tap-to-text, tap-to-email from linked contact info — v1.0
- ✓ Contacts framework permission request flow — v1.0
- ✓ Remove existing parentName, parentPhone, parentEmail fields from Player model — v1.0

### Active

(None — next milestone not yet planned)

### Out of Scope

- Relationship labels on linked contacts — unnecessary complexity for this use case
- Storing snapshot copies of contact data — live reference keeps things simple and current
- Contact search/filtering within the app — iOS Contacts picker handles this
- Group messaging or bulk communication features — future capability

## Context

- App targets iOS 18.0+ with Swift 6.0 and SwiftData persistence
- No third-party dependencies — all Apple frameworks
- Player model has `phoneNumber` (String?) and `contactIdentifiers` ([String])
- ContactsService enum isolates all CNContactStore interaction
- ContactPickerRepresentable wraps CNContactPickerViewController for SwiftUI
- PlayerFormView shows live contact data with call/text/email action buttons
- Migration plan removed — no shipped V1 data to migrate

## Constraints

- **Platform**: iOS 18.0+ only — can use latest Contacts framework APIs
- **Privacy**: Must request Contacts access with a clear usage description in Info.plist
- **No third-party deps**: Stay with Apple frameworks only

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Live contact reference (ID only) | Always shows current info, no stale data to manage | ✓ Good |
| Drop existing parent fields without migration | User confirmed data loss is acceptable | ✓ Good |
| No relationship labels on contacts | Keeps the model simple, not needed for quick-dial use case | ✓ Good |
| Player's own phone number as separate field | Distinct from linked contacts — player's direct number | ✓ Good |
| Enum-with-static-methods for services | Follows LineSuggester pattern, no instance state needed | ✓ Good |
| UINavigationController wrapper for CNContactPickerViewController | Required to avoid empty-sheet UIKit bug | ✓ Good |
| Remove migration plan | NSException bypasses Swift catch; no shipped V1 data to migrate | ✓ Good |
| nonisolated(unsafe) for keysToFetch | CNKeyDescriptor not Sendable but values are constant strings | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-23 after v1.0 milestone*
