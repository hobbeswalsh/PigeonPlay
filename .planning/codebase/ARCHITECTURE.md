# Architecture

**Analysis Date:** 2026-03-17

## Pattern Overview

**Overall:** SwiftUI-based Model-View-Service pattern with SwiftData persistence

**Key Characteristics:**
- Tab-based navigation with four primary features
- Single source of truth: SwiftData model layer with automatic persistence
- Stateful views managing game play logic during active sessions
- Service layer for complex algorithms (line suggestion)
- View-driven state management using @State, @Bindable, @Query

## Layers

**App Entry Point:**
- Purpose: Bootstraps the application and configures data persistence
- Location: `PigeonPlay/App/PigeonPlayApp.swift`
- Contains: App root with SwiftData model container initialization
- Depends on: SwiftData framework, all model classes
- Used by: System launch

**Navigation/Routing:**
- Purpose: Provides top-level tab navigation and screen routing
- Location: `PigeonPlay/App/ContentView.swift`
- Contains: TabView with four primary navigation paths
- Depends on: View layer (Roster, Game, Playbook, History)
- Used by: PigeonPlayApp

**Models (Persistence Layer):**
- Purpose: Define domain data structures with SwiftData persistence
- Location: `PigeonPlay/Models/`
- Contains: `Player.swift`, `Game.swift`, `SavedPlay.swift`
- Depends on: SwiftData framework, Foundation
- Used by: All views and services

**Views (Presentation Layer):**
- Purpose: Render UI and capture user input
- Location: `PigeonPlay/Views/`
- Contains: Four feature areas: Game, Roster, Playbook, History
- Depends on: Models, Services, SwiftUI
- Used by: NavigationStack and TabView

**Services (Business Logic):**
- Purpose: Implement domain algorithms and computations
- Location: `PigeonPlay/Services/`
- Contains: `LineSuggester.swift` for line suggestion algorithm
- Depends on: Models
- Used by: GameView and related views

## Data Flow

**Game Creation Flow:**

1. User taps "New Game" on GameView
2. Sheet opens with NewGameFlow (opponent name + player check-in)
3. CheckInView presents available players with toggle selection
4. User selects players, confirms
5. createGame() inserts Game into modelContext with selected players
6. SwiftData persists Game and relationships automatically
7. ActiveGameView displays, queries active games via @Query

**Game Point Recording Flow:**

1. User selects gender ratio via Picker
2. LineSelectionView displays available players
3. User manually edits line or taps "Shuffle" to invoke LineSuggester
4. LineSuggester.suggest() returns balanced line respecting played points and bench time
5. User confirms with "Lock In", phase transitions to .recordingPoint
6. LineSelectionView selected line becomes GamePoint.onFieldPlayers
7. RecordPointView displays point outcome options
8. User selects outcome, scorer, assist
9. recordPoint() creates GamePoint, appends to game.points, ModelContext auto-persists
10. NextLineQueueView pre-suggests next line for smooth transition
11. Cycle repeats until game ends

**Next-Line Queue Flow:**

1. When transitioning to .recordingPoint, invokes LineSuggester excluding current line
2. Suggested line displayed in collapsible NextLineQueueView
3. User can modify queue (add/remove players, toggle gender matching for X players)
4. Changes only affect @State binding, not persisted until point recorded
5. On point record, queuedLine becomes next selectedLine

**State Management:**
- @Query properties auto-fetch from SwiftData and track changes
- @State properties manage ephemeral UI state (form inputs, selections)
- @Bindable wraps model instances to provide two-way binding
- @Environment(\.modelContext) provides SwiftData insertion/deletion access
- Models themselves are sources of truth (not view models)

## Key Abstractions

**Player:**
- Purpose: Represents a team member with gender and parent contact
- Examples: `PigeonPlay/Models/Player.swift`
- Pattern: SwiftData @Model with Gender and GenderMatching enums

**Game:**
- Purpose: Tracks a single match with points, scores, and availability
- Examples: `PigeonPlay/Models/Game.swift`
- Pattern: @Model with computed properties (ourScore, theirScore) and methods (undoLastPoint)

**GamePoint:**
- Purpose: Atomically tracks one point with players, outcome, scorer
- Examples: References in `Game.points: [GamePoint]`
- Pattern: @Model relationship, composed of PointPlayer entries

**PointPlayer:**
- Purpose: Represents player assignment to a point with effective gender matching
- Examples: Used in `GamePoint.onFieldPlayers: [PointPlayer]`
- Pattern: Bridges Player with runtime gender designation (Bx/Gx)

**SavedPlay:**
- Purpose: Persists drawing annotations with metadata
- Examples: `PigeonPlay/Models/SavedPlay.swift`
- Pattern: @Model storing DrawingElement array (codable enum)

**DrawingElement:**
- Purpose: Represents canvas drawing primitives
- Examples: stroke, arrow, circle
- Pattern: Codable enum enabling persistence to SwiftData

**LineSuggestion:**
- Purpose: Immutable result of line suggestion algorithm
- Examples: Returned from `LineSuggester.suggest()`
- Pattern: Struct with computed allEntries, no side effects

**GamePhase:**
- Purpose: Enum-based state machine for point recording workflow
- Examples: .selectingLine, .recordingPoint
- Pattern: Used to control conditional rendering in ActiveGameView

## Entry Points

**App Launch:**
- Location: `PigeonPlay/App/PigeonPlayApp.swift`
- Triggers: System launch
- Responsibilities: Initialize SwiftData container, configure model schema, present root WindowGroup

**Tab Navigation:**
- Location: `PigeonPlay/App/ContentView.swift`
- Triggers: App launch or tab selection
- Responsibilities: Route to Roster, Game, Playbook, or History tabs

**Game Recording:**
- Location: `PigeonPlay/Views/Game/GameView.swift`
- Triggers: User navigates to Game tab or new game creation
- Responsibilities: Query active games, manage game creation flow, dispatch to ActiveGameView

**Playbook Canvas:**
- Location: `PigeonPlay/Views/Playbook/FieldCanvasView.swift`
- Triggers: Playbook tab selected
- Responsibilities: Handle drawing gestures, render canvas with DrawingElement primitives

**History Browsing:**
- Location: `PigeonPlay/Views/History/HistoryView.swift`
- Triggers: History tab selected
- Responsibilities: Query inactive games sorted by date, provide game detail navigation

## Error Handling

**Strategy:** Implicit (no thrown errors in codebase)

**Patterns:**
- Optional unwrapping: activeGame check, Game.scorer/assist optionals
- Guard statements for validation: opponentName not empty before game creation
- @Query filters handle empty result sets (ContentUnavailableView)
- No network or database error paths exposed (local SwiftData only)

## Cross-Cutting Concerns

**Logging:** None implemented

**Validation:**
- opponentName trim and isEmpty check before game creation
- Gender ratio validation via enum (CaseIterable)
- Point count validation (line must be exactly 5 players to lock in)

**Authentication:** None required (local app)

---

*Architecture analysis: 2026-03-17*
