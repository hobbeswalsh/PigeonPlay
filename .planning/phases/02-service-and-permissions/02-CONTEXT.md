# Phase 2: Contact Picker - Context

**Gathered:** 2026-03-22
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the contact picker integration: coaches can link/unlink iOS Contacts to a player from the edit form. Also adds the player's own phone number field and sets up NSContactsUsageDescription. Does NOT include live contact display or tap-to-communicate actions (that's Phase 3).

</domain>

<decisions>
## Implementation Decisions

### Form Layout
- **D-01:** Contacts appear as a new Form section ("Contacts") below "Player Info" in PlayerFormView
- **D-02:** Player's own phone number is a TextField in the "Player Info" section, after gender/matching fields

### Add Contact UX
- **D-03:** "Add Contact" is a button row at the bottom of the Contacts section with a plus icon
- **D-04:** Tapping "Add Contact" opens CNContactPickerViewController via UIViewControllerRepresentable

### Linked Contact Display
- **D-05:** Each linked contact shows name only (no phone preview) in Phase 2 — Phase 3 adds live data display
- **D-06:** Swipe-to-delete removes a linked contact from the player

### Claude's Discretion
- CNContactPickerViewController wrapping approach (UIViewControllerRepresentable vs UINavigationController wrapper)
- Whether to show contact count badge on PlayerRow in the roster list
- Contact picker configuration (single vs multi-select, which contact properties to request)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs — requirements fully captured in decisions above.

### Codebase
- `PigeonPlay/Views/Roster/PlayerFormView.swift` — The form where contacts section will be added
- `PigeonPlay/Views/Roster/RosterView.swift` — Roster list with PlayerRow (may need contact count)
- `PigeonPlay/Models/Player.swift` — Player model with contactIdentifiers and phoneNumber fields
- `PigeonPlay/Models/PlayerMigration.swift` — Migration infrastructure from Phase 1
- `project.yml` — XcodeGen config where NSContactsUsageDescription must be added

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PlayerFormView` — Already a Form-based view with sections, easy to add a new "Contacts" section
- `Player.contactIdentifiers: [String]` — Already exists from Phase 1, stores CNContact IDs
- `Player.phoneNumber: String?` — Already exists from Phase 1

### Established Patterns
- Form with Section("label") for grouping — used in PlayerFormView
- `@State` for ephemeral form state, `@Bindable` for model binding
- `@Environment(\.modelContext)` for persistence
- Swipe `.onDelete` for removing items in lists (used in RosterView)
- Sheet presentation for new items (used in RosterView for add player)

### Integration Points
- `PlayerFormView` — main integration point, add contacts section and phone field
- `RosterView.PlayerRow` — optional: show linked contact count
- `project.yml` — NSContactsUsageDescription must be added here

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-service-and-permissions*
*Context gathered: 2026-03-22*
