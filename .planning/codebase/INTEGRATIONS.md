# External Integrations

**Analysis Date:** 2026-03-17

## APIs & External Services

**None detected:**
- No third-party API integrations
- No HTTP clients or network requests in codebase
- No webhook implementations
- All functionality is offline-first

## Data Storage

**Databases:**
- SwiftData (local on-device database)
  - Connection: Local device storage managed by iOS
  - Client: `import SwiftData` with `@Model` decorators
  - Models: `Player`, `Game`, `GamePoint`, `PointPlayer`, `SavedPlay`
  - Config location: `PigeonPlay/App/PigeonPlayApp.swift` - `.modelContainer(for: [Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self])`

**File Storage:**
- Local filesystem only
- Drawing elements serialized within SwiftData models via `Codable`
- No cloud storage integration

**Caching:**
- In-memory state management via SwiftUI `@State`, `@Environment`, `@Binding`
- No external caching layer

## Authentication & Identity

**Auth Provider:**
- None - Standalone iOS app with no user authentication
- No sign-in or authorization system
- Parent contact information stored locally in `Player` model (`parentName`, `parentPhone`, `parentEmail`) for reference only

## Monitoring & Observability

**Error Tracking:**
- None configured
- No Crashlytics, Sentry, or similar service

**Logs:**
- No centralized logging system
- No telemetry or analytics integration

## CI/CD & Deployment

**Hosting:**
- App Store (implied - no backend or web hosting)

**CI Pipeline:**
- None detected - No GitHub Actions, CircleCI, or other CI service configuration

## Environment Configuration

**Required env vars:**
- None - App is entirely self-contained

**Secrets location:**
- N/A - No secrets or API keys in use

## Webhooks & Callbacks

**Incoming:**
- None - App has no server component

**Outgoing:**
- None - App cannot make external HTTP requests

---

*Integration audit: 2026-03-17*
