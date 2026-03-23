# Roadmap: PigeonPlay — Contact Management

## Overview

Three phases that follow the hard dependency chain of the Contacts integration: the data model must exist before the picker can store identifiers, and identifiers must be stored before the display layer can fetch anything. Phase 1 handles the SwiftData migration in isolation because an unversioned schema crash is the highest-severity risk in this milestone. Phase 2 adds the contact picker and permission infrastructure. Phase 3 closes the loop with live contact display, tap-to-communicate actions, and runtime permission handling.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Schema Migration** - Safely version and migrate the Player model to drop legacy parent fields and add contact storage fields
- [ ] **Phase 2: Contact Picker** - Let coaches link and unlink iOS Contacts to a player from the edit form
- [ ] **Phase 3: Contact Display and Actions** - Show live contact info and enable tap-to-call, tap-to-text, tap-to-email

## Phase Details

### Phase 1: Schema Migration
**Goal**: The Player model is versioned and migrated — legacy parent fields are gone, contact fields are live, and the app launches without crashing on existing persisted data
**Depends on**: Nothing (first phase)
**Requirements**: SCHEMA-01, SCHEMA-02, SCHEMA-03, SCHEMA-04
**Success Criteria** (what must be TRUE):
  1. App launches on a device with existing Player data without a crash or data loss
  2. Player model no longer exposes parentName, parentPhone, or parentEmail fields anywhere in the codebase
  3. Player has a phoneNumber (String?) field that can be set and persisted
  4. Player has a contactIdentifiers ([String]) field that persists an array of contact ID strings
**Plans:** 1 plan
Plans:
- [x] 01-01-PLAN.md — Version and migrate Player model (V1/V2 schemas, migration plan, strip legacy fields, update tests)

### Phase 2: Contact Picker
**Goal**: A coach can open the iOS contact picker from a player's edit form, link one or more contacts, and remove a previously linked contact — with NSContactsUsageDescription in place so the app is not rejected on review
**Depends on**: Phase 1
**Requirements**: PICKER-01, PICKER-02, PICKER-03, PERM-01
**Success Criteria** (what must be TRUE):
  1. Tapping "Add Contact" on the player edit form opens the native iOS contact picker (not a blank sheet)
  2. Selecting a contact from the picker stores its identifier on the player and the contact appears in the linked contacts list
  3. User can remove a linked contact from the player edit form
  4. NSContactsUsageDescription is present in the built app's Info.plist
**Plans:** 2 plans
Plans:
- [x] 02-01-PLAN.md — ContactPickerRepresentable UIKit bridge + tests + NSContactsUsageDescription in project.yml
- [x] 02-02-PLAN.md — PlayerFormView integration (phone field, Contacts section, picker sheet, swipe-to-delete)
**UI hint**: yes

### Phase 3: Contact Display and Actions
**Goal**: Linked contacts display live name, phone, and email fetched from the device Contacts store, every communication action works, permission states are handled gracefully, and inaccessible contacts do not crash the app
**Depends on**: Phase 2
**Requirements**: DISPLAY-01, DISPLAY-02, DISPLAY-03, DISPLAY-04, DISPLAY-05, PERM-02, PERM-03
**Success Criteria** (what must be TRUE):
  1. Each linked contact shows the current name, phone number, and email address from the device Contacts store (not stale cached data)
  2. Tapping a phone number initiates a call; tapping it again offers a text message
  3. Tapping an email address opens the system mail compose sheet
  4. When Contacts access is denied or restricted, the player detail view shows an explanatory message instead of empty or crashed UI
  5. A linked contact that has been deleted from the device Contacts app shows a graceful fallback label, not a crash
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Schema Migration | 0/1 | Planning complete | - |
| 2. Contact Picker | 0/2 | Planning complete | - |
| 3. Contact Display and Actions | 0/TBD | Not started | - |
