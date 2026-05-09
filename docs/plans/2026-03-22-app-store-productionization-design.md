# PigeonPlay App Store Productionization Design

**Date:** 2026-03-22
**Goal:** Ship PigeonPlay to the App Store as a paid niche utility for youth ultimate coaches.

## Key Decisions

- **Target audience:** Youth ultimate coaches (niche utility)
- **Pricing:** Paid upfront, $3.99–$4.99 (no IAP)
- **Data strategy:** Local-only, single-device (no CloudKit/iCloud sync)

## Phase 1 — Ship-blocking

### Apple Requirements
- Enroll in Apple Developer Program ($99/year, personal account)
- Add `PrivacyInfo.xcprivacy` declaring no data collection
- Review app icon quality at small sizes; replace if too AI-generic
- Create privacy policy (GitHub Pages one-pager)
- Create support URL (GitHub issues or email landing page)
- Capture screenshots (6.7" and 6.1" minimum)
- Write App Store description, subtitle, keywords
- Age rating: 4+

### Data Safety
- Add `VersionedSchema` and `SchemaMigrationPlan` to lock in v1 schema before shipping
- Add safeguards to player deletion (confirmation dialog when player has game history, or soft-delete)
- Define SwiftData cascade/deny rules for Player → PointPlayer relationships

### Edge Cases & Robustness
- Guard check-in to require minimum 5 players before "Start Game" enables
- Add `ContentUnavailableView` to History tab when no completed games exist
- Add delete confirmation to History tab (swipe-to-delete on games)
- Add clear confirmation to Playbook canvas trash button

## Phase 2 — Worth-the-price polish

### Onboarding
- First-launch flow guiding user to add roster before starting a game
- Could be as simple as a conditional overlay on the Game tab pointing to Roster

### Game UX
- Haptic feedback on point recording (confirm, them, dead)
- Visual B-side/G-side grouping in LineBuilderView (color-code or section headers)
- "Select All" / "Deselect All" toggle on CheckInView
- Consider "Select All by gender" shortcut

### Playbook UX
- Undo last stroke (maintain stroke history stack)
- Warn before loading a play if canvas has unsaved changes

### Visual Polish
- Branded launch screen with app icon
- App-wide accent color / minimal theming
- Replace Playbook tab icon (`pencil.and.outline` → something more evocative)

### Marketing
- Simple landing page (GitHub Pages) for privacy policy, support, and ASO

## Phase 3 — Post-launch improvements

- Data export (CSV of game history/stats)
- Play thumbnails in playbook load sheet
- Duplicate player name validation on PlayerFormView
- Edge-case tests (empty rosters, single-gender rosters, <5 players)
- View/integration tests for critical game flow
- Accessibility labels on custom views (scoreboard, tap-to-select lists)
- TestFlight feedback items

## What We're Explicitly Not Doing

- No CloudKit/iCloud sync (single-device is acceptable)
- No backend/server infrastructure
- No analytics SDK (App Store Connect is sufficient)
- No in-app purchases or subscription model
- No iPad-specific layout optimization (works in compatibility mode)
