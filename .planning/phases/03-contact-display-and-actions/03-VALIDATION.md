---
phase: 3
slug: contact-display-and-actions
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 3 — Validation Strategy

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
| 3-01-01 | 01 | 1 | DISPLAY-01, DISPLAY-05, PERM-02, PERM-03 | unit | `xcodebuild test` | ❌ W0 | ⬜ pending |
| 3-02-01 | 02 | 2 | DISPLAY-02, DISPLAY-03, DISPLAY-04 | build | `xcodebuild build` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Create `PigeonPlayTests/ContactsServiceTests.swift` — stubs for URL construction, ContactResult handling, auth status branching
- [ ] Verify existing test suite passes

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live contact name/phone/email display | DISPLAY-01 | Requires device Contacts data | 1. Link a contact 2. Verify name/phone/email shown |
| Tap-to-call | DISPLAY-02 | Requires phone capability | 1. Tap phone number 2. Verify call initiated |
| Tap-to-text | DISPLAY-03 | Requires Messages app | 1. Tap text action 2. Verify Messages opens |
| Tap-to-email | DISPLAY-04 | Requires Mail app | 1. Tap email 2. Verify Mail compose opens |
| Deleted contact fallback | DISPLAY-05 | Requires deleting a contact mid-test | 1. Link contact 2. Delete from Contacts app 3. Verify fallback label |
| Permission denied guidance | PERM-03 | Requires denying Contacts permission | 1. Deny permission 2. Verify guidance shown |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
