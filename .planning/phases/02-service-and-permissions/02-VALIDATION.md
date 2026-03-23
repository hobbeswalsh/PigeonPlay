---
phase: 2
slug: service-and-permissions
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (@Test macro) |
| **Config file** | PigeonPlayTests/ directory |
| **Quick run command** | `xcodebuild build -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \| grep -E "error:\|BUILD" \| head -20` |
| **Full suite command** | `xcodebuild test -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \| tail -30` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick build command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | PICKER-01 | build | `xcodebuild build` | ❌ W0 | ⬜ pending |
| 2-01-02 | 01 | 1 | PICKER-02, PICKER-03 | build | `xcodebuild build` | ❌ W0 | ⬜ pending |
| 2-01-03 | 01 | 1 | PERM-01 | build | `xcodebuild build` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Verify existing test suite still passes after Phase 1 migration
- [ ] Build verification sufficient — contact picker is UI-only, not unit-testable

*Contact picker interaction requires manual/UI testing — automated build verification confirms compilation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Contact picker opens (not blank) | PICKER-01 | Requires device Contacts app interaction | 1. Open player form 2. Tap "Add Contact" 3. Verify native picker appears with contacts |
| Selected contact stored | PICKER-02 | Requires picker interaction | 1. Pick a contact 2. Verify it appears in linked list 3. Close and reopen — verify persisted |
| Swipe-to-delete removes contact | PICKER-03 | Requires gesture interaction | 1. Swipe linked contact 2. Delete 3. Verify removed from list and model |
| NSContactsUsageDescription present | PERM-01 | Build output inspection | 1. Build app 2. Check Info.plist in built product |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
