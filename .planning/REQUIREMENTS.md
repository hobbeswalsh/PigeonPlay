# Requirements: PigeonPlay — Contact Management

**Defined:** 2026-03-22
**Core Value:** Coaches can quickly reach a player's contacts directly from the roster without leaving the app.

## v1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Schema Migration

- [ ] **SCHEMA-01**: Player model wrapped in VersionedSchema V1/V2 with SchemaMigrationPlan
- [ ] **SCHEMA-02**: parentName, parentPhone, parentEmail fields removed from Player model
- [ ] **SCHEMA-03**: Player has optional phoneNumber (String?) for player's own number
- [ ] **SCHEMA-04**: Player has contactIdentifiers ([String]) for linked iOS Contact IDs

### Contact Picker

- [ ] **PICKER-01**: CNContactPickerViewController wrapped as SwiftUI view via UIViewControllerRepresentable
- [ ] **PICKER-02**: User can link one or more iOS Contacts to a player from the player edit form
- [ ] **PICKER-03**: User can unlink a previously linked contact from a player

### Contact Display

- [ ] **DISPLAY-01**: Linked contacts show name, phone, and email fetched live from CNContactStore
- [ ] **DISPLAY-02**: User can tap to call a linked contact's phone number
- [ ] **DISPLAY-03**: User can tap to send a text to a linked contact's phone number
- [ ] **DISPLAY-04**: User can tap to email a linked contact's email address
- [ ] **DISPLAY-05**: Deleted or inaccessible contacts display graceful fallback (not a crash)

### Permission

- [ ] **PERM-01**: NSContactsUsageDescription set in Info.plist/project.yml
- [ ] **PERM-02**: App requests Contacts authorization before CNContactStore access
- [ ] **PERM-03**: Denied/restricted authorization state shows user guidance

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### iOS 18 Enhancements

- **IOS18-01**: ContactAccessButton for inline contact search/grant flow
- **IOS18-02**: CNAuthorizationStatus.limited handling with user-facing explanation

### Communication

- **COMM-01**: Group messaging or bulk communication to multiple contacts

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Relationship labels on contacts | Unnecessary complexity — coaches just need to reach people |
| Snapshot copies of contact data | Live reference is simpler, always current |
| Migrating existing parent data | User confirmed data loss is acceptable |
| Contact search/filtering in-app | iOS Contacts picker handles this natively |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCHEMA-01 | — | Pending |
| SCHEMA-02 | — | Pending |
| SCHEMA-03 | — | Pending |
| SCHEMA-04 | — | Pending |
| PICKER-01 | — | Pending |
| PICKER-02 | — | Pending |
| PICKER-03 | — | Pending |
| DISPLAY-01 | — | Pending |
| DISPLAY-02 | — | Pending |
| DISPLAY-03 | — | Pending |
| DISPLAY-04 | — | Pending |
| DISPLAY-05 | — | Pending |
| PERM-01 | — | Pending |
| PERM-02 | — | Pending |
| PERM-03 | — | Pending |

---
*Last updated: 2026-03-22 after requirements definition*
