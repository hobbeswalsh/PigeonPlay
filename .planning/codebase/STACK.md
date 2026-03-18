# Technology Stack

**Analysis Date:** 2026-03-17

## Languages

**Primary:**
- Swift 6.0 - All application and test code

## Runtime

**Environment:**
- iOS 18.0 (minimum deployment target)
- Xcode with Swift toolchain

**Build System:**
- XcodeGen - Project generation from `project.yml`

## Frameworks

**Core UI & Data:**
- SwiftUI - UI framework for all views in `PigeonPlay/Views/**/*.swift`
- SwiftData - Data persistence and model layer (`PigeonPlay/Models/**/*.swift`)

**Testing:**
- Swift Testing (`@Test` macro) - Unit testing framework
  - Used in `PigeonPlayTests/*.swift` for model and service tests

## Key Dependencies

**None (First-party only):**
- All functionality built with standard Apple frameworks
- No third-party package dependencies in use
- No CocoaPods, Carthage, or SPM packages configured

**Infrastructure:**
- Foundation - Standard library utilities across all Swift files
- SwiftUI animations, state management, and view lifecycle

## Configuration

**Environment:**
- iOS app requires device/simulator running iOS 18.0 or later
- No external API keys or environment configuration files detected
- No secrets management system in place

**Build:**
- `project.yml` - XcodeGen configuration for project structure
- Xcode 15+ required (Swift 6.0 support)
- Auto-generated Info.plist enabled via `GENERATE_INFOPLIST_FILE: YES`

## Platform Requirements

**Development:**
- macOS with Xcode 15+
- Swift 6.0 compatible Swift toolchain
- iOS 18.0 SDK

**Production:**
- iOS 18.0+ on iPhone or iPad
- Supports both portrait and landscape orientations (iPhone and iPad have different orientation support per `project.yml`)

## Data Models

**Local Storage:**
- SwiftData models defined in `PigeonPlay/Models/`:
  - `Player.swift` - Player roster with contact info
  - `Game.swift` - Game records with points and outcomes
  - `SavedPlay.swift` - Playbook drawings and tactical plays
  - Related value objects: `GamePoint`, `PointPlayer`, `GenderRatio`, `PointOutcome`, `Gender`, `GenderMatching`

**Serialization:**
- Models conform to `Codable` for persistence via SwiftData
- `DrawingElement` enum handles drawing data (strokes, arrows, circles)

---

*Stack analysis: 2026-03-17*
