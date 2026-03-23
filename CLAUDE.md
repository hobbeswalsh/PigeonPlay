## Coding on roster-manager

You will use the `gsd` skill when working on this project.
You will always work in on branches in git worktrees.

<!-- GSD:project-start source:PROJECT.md -->
## Project

**PigeonPlay — Contact Management**

PigeonPlay is an iOS app for managing youth sports team rosters, tracking games with line suggestions, and drawing up plays. This milestone adds contact management — linking players to their phone numbers and iOS Contacts for quick communication with parents/guardians.

**Core Value:** Coaches can quickly reach a player's contacts (parents, guardians) directly from the roster without leaving the app.

### Constraints

- **Platform**: iOS 18.0+ only — can use latest Contacts framework APIs
- **Privacy**: Must request Contacts access with a clear usage description in Info.plist
- **Data model**: SwiftData migration required — dropping 3 fields, adding phone + contact identifier storage
- **No third-party deps**: Stay with Apple frameworks only
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Swift 6.0 - All application and test code
## Runtime
- iOS 18.0 (minimum deployment target)
- Xcode with Swift toolchain
- XcodeGen - Project generation from `project.yml`
## Frameworks
- SwiftUI - UI framework for all views in `PigeonPlay/Views/**/*.swift`
- SwiftData - Data persistence and model layer (`PigeonPlay/Models/**/*.swift`)
- Swift Testing (`@Test` macro) - Unit testing framework
## Key Dependencies
- All functionality built with standard Apple frameworks
- No third-party package dependencies in use
- No CocoaPods, Carthage, or SPM packages configured
- Foundation - Standard library utilities across all Swift files
- SwiftUI animations, state management, and view lifecycle
## Configuration
- iOS app requires device/simulator running iOS 18.0 or later
- No external API keys or environment configuration files detected
- No secrets management system in place
- `project.yml` - XcodeGen configuration for project structure
- Xcode 15+ required (Swift 6.0 support)
- Auto-generated Info.plist enabled via `GENERATE_INFOPLIST_FILE: YES`
## Platform Requirements
- macOS with Xcode 15+
- Swift 6.0 compatible Swift toolchain
- iOS 18.0 SDK
- iOS 18.0+ on iPhone or iPad
- Supports both portrait and landscape orientations (iPhone and iPad have different orientation support per `project.yml`)
## Data Models
- SwiftData models defined in `PigeonPlay/Models/`:
- Models conform to `Codable` for persistence via SwiftData
- `DrawingElement` enum handles drawing data (strokes, arrows, circles)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Views: `[Name]View.swift` (e.g., `GameView.swift`, `LineSelectionView.swift`)
- Models: `[Name].swift` (e.g., `Game.swift`, `Player.swift`)
- Services: `[Name]Service.swift` (e.g., `LineSuggester.swift` - note: uses enum pattern instead of service class)
- Tests: `[Name]Tests.swift` (e.g., `GameTests.swift`, `LineSuggesterTests.swift`)
- camelCase: `suggestLine()`, `removeFromLine()`, `toggleMatching()`
- Private functions: `private func methodName()`
- View body computed property: Always `var body: some View`
- Properties: camelCase, descriptive names
- State variables: Explicitly annotated with `@State private var`
- Environment variables: `@Environment(\.modelContext)`, `@Query`
- Binding variables: Prefixed with underscore for parameter `@Binding var selectedLine`
- Model classes: PascalCase with `@Model` decorator: `class Game`, `class Player`
- Structs (Views): PascalCase: `struct GameView`
- Enums: PascalCase: `enum GenderRatio`, `enum PointOutcome`
- Computed properties: camelCase: `var ourScore: Int`
## Code Style
- Swift 6.0 enforced via `project.yml`
- Deployment target: iOS 18.0
- 4-space indentation (standard Swift)
- No configuration tool detected; style is manual/convention-based
- No linter detected (no `.swiftlint.yml` or equivalent)
- Code quality relies on manual review and testing
## Import Organization
## Error Handling
- Guard statements for nil checks: `guard !points.isEmpty else { return nil }`
- Guard with condition for validation: `guard selectedLine.count < 5 else { return }`
- Optional chaining: `game.availablePlayers.firstIndex(where: { ... })`
- Model layer throws errors implicitly through guard/return patterns (not explicit throws)
## Logging
- No explicit logging framework used
- State mutations trigger SwiftUI view updates (implicit logging through state)
- Testing uses assertions for verification
## Comments
- Explain non-obvious algorithm behavior: See `LineSuggester.swift` line 27-28 explaining bench time logic
- Clarify domain-specific logic: Comments explain gender ratio abbreviations (2B = 2 boys, 3G = 3 girls)
- Avoid commenting obvious code: `// Remove from line` is unnecessary
- Not used in this codebase; parameters are self-documenting through type signatures
## Function Design
- Most functions 5-20 lines
- Helper methods kept small and focused
- No methods exceed 30 lines (viewed through whole file analysis)
- Use named parameters for clarity: `suggest(available:, ratio:, pointsPlayed:, lastPointOnBench:, excluding:)`
- Prefer parameter labels to self-document intent
- Default parameters for optional parameters: `excluding: Set<Player> = []`
- Explicit optional returns: `func undoLastPoint() -> GamePoint?`
- Struct returns for grouped data: `LineSuggestion` contains `bSide` and `gSide`
- No early returns from multiple guard statements in business logic (see `LineSuggester`)
## Module Design
- Models marked with `@Model` (SwiftData persistence)
- Views are `struct` implementing `View` protocol
- Services implemented as enums with static methods: `enum LineSuggester { static func suggest() }`
- No barrel/index files used; imports are direct: `import PigeonPlay` imports entire module
- File-level organization provides structure
- `@Model` decorator on persistent classes: `@Model final class Game`
- `@Query` for fetching data in views: `@Query(filter: #Predicate<Game> { $0.isActive })`
- `@Environment(\.modelContext)` for mutations: `@Environment(\.modelContext) private var modelContext`
## SwiftUI View Conventions
- Local state: `@State private var variable = default`
- Received state: `@Binding var variable`
- Model binding: `@Bindable var game: Game`
- Environment queries: `@Query`, `@Environment`
- Nested structs for logical grouping: `NewGameFlow` and `ActiveGameView` defined in `GameView.swift`
- Helper views: `PlayerRow` in separate struct but same file as parent
- Computed properties for filtered data: See `RosterView.swift` lines 9-11
- VStack/HStack with explicit spacing: `.padding()`, `.spacing(0)`
- Conditional rendering: `if let` and `switch` on state
- Safe area insets: `.safeAreaInset(edge: .bottom)` for persistent bottom UI
- Material backgrounds: `.ultraThinMaterial` for blur effect
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Tab-based navigation with four primary features
- Single source of truth: SwiftData model layer with automatic persistence
- Stateful views managing game play logic during active sessions
- Service layer for complex algorithms (line suggestion)
- View-driven state management using @State, @Bindable, @Query
## Layers
- Purpose: Bootstraps the application and configures data persistence
- Location: `PigeonPlay/App/PigeonPlayApp.swift`
- Contains: App root with SwiftData model container initialization
- Depends on: SwiftData framework, all model classes
- Used by: System launch
- Purpose: Provides top-level tab navigation and screen routing
- Location: `PigeonPlay/App/ContentView.swift`
- Contains: TabView with four primary navigation paths
- Depends on: View layer (Roster, Game, Playbook, History)
- Used by: PigeonPlayApp
- Purpose: Define domain data structures with SwiftData persistence
- Location: `PigeonPlay/Models/`
- Contains: `Player.swift`, `Game.swift`, `SavedPlay.swift`
- Depends on: SwiftData framework, Foundation
- Used by: All views and services
- Purpose: Render UI and capture user input
- Location: `PigeonPlay/Views/`
- Contains: Four feature areas: Game, Roster, Playbook, History
- Depends on: Models, Services, SwiftUI
- Used by: NavigationStack and TabView
- Purpose: Implement domain algorithms and computations
- Location: `PigeonPlay/Services/`
- Contains: `LineSuggester.swift` for line suggestion algorithm
- Depends on: Models
- Used by: GameView and related views
## Data Flow
- @Query properties auto-fetch from SwiftData and track changes
- @State properties manage ephemeral UI state (form inputs, selections)
- @Bindable wraps model instances to provide two-way binding
- @Environment(\.modelContext) provides SwiftData insertion/deletion access
- Models themselves are sources of truth (not view models)
## Key Abstractions
- Purpose: Represents a team member with gender and parent contact
- Examples: `PigeonPlay/Models/Player.swift`
- Pattern: SwiftData @Model with Gender and GenderMatching enums
- Purpose: Tracks a single match with points, scores, and availability
- Examples: `PigeonPlay/Models/Game.swift`
- Pattern: @Model with computed properties (ourScore, theirScore) and methods (undoLastPoint)
- Purpose: Atomically tracks one point with players, outcome, scorer
- Examples: References in `Game.points: [GamePoint]`
- Pattern: @Model relationship, composed of PointPlayer entries
- Purpose: Represents player assignment to a point with effective gender matching
- Examples: Used in `GamePoint.onFieldPlayers: [PointPlayer]`
- Pattern: Bridges Player with runtime gender designation (Bx/Gx)
- Purpose: Persists drawing annotations with metadata
- Examples: `PigeonPlay/Models/SavedPlay.swift`
- Pattern: @Model storing DrawingElement array (codable enum)
- Purpose: Represents canvas drawing primitives
- Examples: stroke, arrow, circle
- Pattern: Codable enum enabling persistence to SwiftData
- Purpose: Immutable result of line suggestion algorithm
- Examples: Returned from `LineSuggester.suggest()`
- Pattern: Struct with computed allEntries, no side effects
- Purpose: Enum-based state machine for point recording workflow
- Examples: .selectingLine, .recordingPoint
- Pattern: Used to control conditional rendering in ActiveGameView
## Entry Points
- Location: `PigeonPlay/App/PigeonPlayApp.swift`
- Triggers: System launch
- Responsibilities: Initialize SwiftData container, configure model schema, present root WindowGroup
- Location: `PigeonPlay/App/ContentView.swift`
- Triggers: App launch or tab selection
- Responsibilities: Route to Roster, Game, Playbook, or History tabs
- Location: `PigeonPlay/Views/Game/GameView.swift`
- Triggers: User navigates to Game tab or new game creation
- Responsibilities: Query active games, manage game creation flow, dispatch to ActiveGameView
- Location: `PigeonPlay/Views/Playbook/FieldCanvasView.swift`
- Triggers: Playbook tab selected
- Responsibilities: Handle drawing gestures, render canvas with DrawingElement primitives
- Location: `PigeonPlay/Views/History/HistoryView.swift`
- Triggers: History tab selected
- Responsibilities: Query inactive games sorted by date, provide game detail navigation
## Error Handling
- Optional unwrapping: activeGame check, Game.scorer/assist optionals
- Guard statements for validation: opponentName not empty before game creation
- @Query filters handle empty result sets (ContentUnavailableView)
- No network or database error paths exposed (local SwiftData only)
## Cross-Cutting Concerns
- opponentName trim and isEmpty check before game creation
- Gender ratio validation via enum (CaseIterable)
- Point count validation (line must be exactly 5 players to lock in)
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
