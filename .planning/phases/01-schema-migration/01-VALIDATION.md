---
phase: 1
slug: schema-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (@Test macro) |
| **Config file** | PigeonPlayTests/ directory |
| **Quick run command** | `xcodebuild test -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PigeonPlayTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -40` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | SCHEMA-01 | unit | `xcodebuild test` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 1 | SCHEMA-02 | unit | `xcodebuild test` | ❌ W0 | ⬜ pending |
| 1-01-03 | 01 | 1 | SCHEMA-03 | unit | `xcodebuild test` | ❌ W0 | ⬜ pending |
| 1-01-04 | 01 | 1 | SCHEMA-04 | unit | `xcodebuild test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Update `PigeonPlayTests/PlayerTests.swift` — remove tests for dropped parent fields, add stubs for phoneNumber and contactIdentifiers
- [ ] Verify existing test infrastructure compiles with new model shape

*Existing Swift Testing framework covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| App launches without crash on existing data | SCHEMA-01 | Requires device/simulator with pre-migration persisted data | 1. Install current app 2. Create a player 3. Install migrated build 4. Verify app launches and player data intact |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
