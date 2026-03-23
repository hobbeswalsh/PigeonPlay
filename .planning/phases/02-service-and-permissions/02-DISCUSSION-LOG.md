# Phase 2: Contact Picker - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-22
**Phase:** 02-service-and-permissions
**Areas discussed:** Contact section placement, Add Contact UX, Linked contact display, Phone number field

---

## Contact Section Placement

| Option | Description | Selected |
|--------|-------------|----------|
| New section in form | Add a "Contacts" section below "Player Info" in the existing PlayerFormView form | ✓ |
| Separate detail view | Create a new PlayerDetailView that shows player info + contacts | |
| You decide | Claude picks the best approach | |

**User's choice:** New section in form
**Notes:** Keeps the existing navigation pattern intact (tap player → edit form).

---

## Add Contact UX

| Option | Description | Selected |
|--------|-------------|----------|
| Button in contacts section | A row at the bottom of the contacts section with plus icon | ✓ |
| Toolbar button | A contacts icon in the navigation toolbar | |
| You decide | Claude picks based on iOS conventions | |

**User's choice:** Button in contacts section
**Notes:** None.

---

## Linked Contact Display

| Option | Description | Selected |
|--------|-------------|----------|
| Name only | Just the contact's full name, swipe-to-delete to remove | ✓ |
| Name + phone preview | Contact name with primary phone as secondary text, swipe-to-delete | |
| You decide | Claude picks the best display pattern | |

**User's choice:** Name only
**Notes:** Phase 3 will add live data display with phone/email.

---

## Phone Number Field

| Option | Description | Selected |
|--------|-------------|----------|
| In Player Info section | Add phone TextField after gender/matching fields | ✓ |
| In Contacts section | At the top of contacts section, above linked contacts | |
| You decide | Claude picks placement | |

**User's choice:** In Player Info section
**Notes:** None.

---

## Claude's Discretion

- CNContactPickerViewController wrapping approach
- Contact count badge on PlayerRow
- Contact picker configuration (single vs multi-select)

## Deferred Ideas

None.
