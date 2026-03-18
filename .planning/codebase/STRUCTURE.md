# Codebase Structure

**Analysis Date:** 2026-03-17

## Directory Layout

```
roster-manager/
├── PigeonPlay/                      # Main app source
│   ├── App/                         # Entry points and routing
│   │   ├── PigeonPlayApp.swift      # App root with SwiftData config
│   │   └── ContentView.swift        # Tab navigation
│   ├── Models/                      # SwiftData models
│   │   ├── Player.swift             # Athlete definition
│   │   ├── Game.swift               # Match + GamePoint + PointPlayer
│   │   └── SavedPlay.swift          # Playbook drawing storage
│   ├── Services/                    # Business logic
│   │   └── LineSuggester.swift      # Line suggestion algorithm
│   └── Views/                       # UI layer, organized by feature
│       ├── Game/                    # Point recording UI
│       │   ├── GameView.swift       # Game tab, active game dispatcher
│       │   ├── ActiveGameView.swift # Game phase state machine
│       │   ├── LineSelectionView.swift    # On-field player selection
│       │   ├── NextLineQueueView.swift    # Next point preview
│       │   ├── RecordPointView.swift      # Outcome & credits form
│       │   └── CheckInView.swift         # Player availability
│       ├── Roster/                  # Player management
│       │   ├── RosterView.swift     # Player list by gender
│       │   └── PlayerFormView.swift  # Player create/edit
│       ├── Playbook/                # Drawing annotation
│       │   ├── PlaybookView.swift    # Canvas UI + drawing tools
│       │   └── FieldCanvasView.swift # Canvas rendering & gestures
│       └── History/                 # Game review
│           ├── HistoryView.swift    # Completed game list
│           └── GameDetailView.swift  # Single game review
├── PigeonPlayTests/                 # Test suite
│   ├── PigeonPlayTests.swift        # Basic app tests
│   ├── GameTests.swift              # Game logic tests
│   ├── LineSuggesterTests.swift     # Line suggestion algorithm tests
│   └── PlayerTests.swift            # Player model tests
├── PigeonPlay.xcodeproj/            # Xcode project metadata
└── docs/                            # External documentation
```

## Directory Purposes

**PigeonPlay/App/:**
- Purpose: App bootstrapping and top-level navigation
- Contains: @main App and root TabView
- Key files: `PigeonPlayApp.swift` initializes SwiftData container for [Player, Game, GamePoint, PointPlayer, SavedPlay]

**PigeonPlay/Models/:**
- Purpose: Domain data model definitions with persistence
- Contains: All @Model classes and supporting enums (Gender, GenderRatio, PointOutcome, etc.)
- Key files: `Player.swift` (47 lines), `Game.swift` (107 lines), `SavedPlay.swift` (21 lines)

**PigeonPlay/Services/:**
- Purpose: Extracted business logic algorithms
- Contains: Line balancing/suggestion logic
- Key files: `LineSuggester.swift` — static suggest() method with deterministic shuffling

**PigeonPlay/Views/:**
- Purpose: SwiftUI presentation layer, organized by feature area
- Contains: Four sub-directories matching app tabs

**PigeonPlay/Views/Game/:**
- Purpose: Point-by-point game recording during play
- Contains: Game tab, game lifecycle, line selection, score recording
- Key files: `GameView.swift` (368 lines, the largest file), manages game creation and active game dispatcher

**PigeonPlay/Views/Roster/:**
- Purpose: Static player roster management
- Contains: Player CRUD, filtering by gender
- Key files: `RosterView.swift` (91 lines), `PlayerFormView.swift` (91 lines)

**PigeonPlay/Views/Playbook/:**
- Purpose: Drawing canvas for play annotation
- Contains: Gesture-driven drawing, tool palette, save/load plays
- Key files: `FieldCanvasView.swift` (203 lines), `PlaybookView.swift` (130 lines)

**PigeonPlay/Views/History/:**
- Purpose: Review completed games
- Contains: Finished game list, score browsing, detail view
- Key files: `HistoryView.swift` (44 lines), `GameDetailView.swift` (74 lines)

**PigeonPlayTests/:**
- Purpose: Unit and integration test suite
- Contains: Model behavior, algorithm validation, business logic
- Key files: `LineSuggesterTests.swift` (186 lines, comprehensive algorithm coverage)

## Key File Locations

**Entry Points:**
- `PigeonPlay/App/PigeonPlayApp.swift`: App root, SwiftData container config
- `PigeonPlay/App/ContentView.swift`: Tab-based navigation dispatcher

**Configuration:**
- `PigeonPlay.xcodeproj/`: Xcode build configuration
- `.planning/`: Documentation and planning artifacts

**Core Logic:**
- `PigeonPlay/Services/LineSuggester.swift`: Line balancing algorithm
- `PigeonPlay/Models/Game.swift`: Game state and point aggregation
- `PigeonPlay/Views/Game/GameView.swift`: Game creation and point recording orchestration

**Testing:**
- `PigeonPlayTests/LineSuggesterTests.swift`: Algorithm correctness (points played, bench time, exclusion)
- `PigeonPlayTests/GameTests.swift`: Game model behavior
- `PigeonPlayTests/PlayerTests.swift`: Player model tests

## Naming Conventions

**Files:**
- Views: PascalCase + "View" suffix (e.g., `GameView.swift`, `LineSelectionView.swift`)
- Models: PascalCase, no suffix (e.g., `Player.swift`, `Game.swift`)
- Services: PascalCase + service descriptor (e.g., `LineSuggester.swift`)
- Tests: Corresponding source name + "Tests" (e.g., `GameTests.swift` for `Game.swift`)

**Directories:**
- Feature areas: lowercase plural (Views/Game, Views/Roster, Views/Playbook, Views/History)
- Logical grouping: lowercase singular (Models, Services, App)

**Types:**
- Models: PascalCase with @Model or @enum decorator
- View structs: PascalCase ending in "View"
- Enums: PascalCase (Gender, GenderRatio, PointOutcome, GamePhase, DrawingTool)
- Structs: PascalCase (LineSuggestion, LineSuggestion.Entry, DrawingElement)

**Functions/Methods:**
- Lowercase with camelCase (suggest, recordPoint, createGame)
- Private helpers: prefixed with underscore or private keyword (e.g., `private func sortKey()`)

**Variables:**
- Properties: lowercase camelCase (opponent, onFieldPlayers, gender)
- Bindings: $ prefix in usage (e.g., $selectedLine)
- State: @State var, @Binding var descriptors in view code

## Where to Add New Code

**New Feature (e.g., new tab):**
- Primary code: `PigeonPlay/Views/[FeatureName]/[FeatureName]View.swift`
- Models (if needed): `PigeonPlay/Models/[Entity].swift`
- Services (if needed): `PigeonPlay/Services/[Feature]Service.swift`
- Tests: `PigeonPlayTests/[Feature]Tests.swift`
- Register in: `PigeonPlay/App/ContentView.swift` Tab addition

**New Component/Module within existing feature:**
- Implementation: `PigeonPlay/Views/[FeatureName]/[ComponentName].swift` (co-located)
- Tests: `PigeonPlayTests/[ComponentName]Tests.swift` (if logic-heavy)

**Business Logic/Algorithm:**
- Implementation: `PigeonPlay/Services/[Name]Service.swift` or single static struct like `LineSuggester`
- Tests: `PigeonPlayTests/[Name]Tests.swift` (comprehensive coverage expected)

**Utilities/Helpers:**
- Extension helpers: Inline in relevant model or service file
- Shared drawing/UI helpers: Can be added to FieldCanvasView.swift or extracted to new file as utility

## Special Directories

**PigeonPlay.xcodeproj/:**
- Purpose: Xcode project metadata, build settings, scheme configuration
- Generated: Partially (by Xcode)
- Committed: Yes (xcodeproj committed to version control for reproducibility)

**docs/plans/:**
- Purpose: External design documents and planning artifacts
- Generated: By human (Robin) or Claude
- Committed: Yes

**.planning/codebase/:**
- Purpose: GSD codebase mapping documents (ARCHITECTURE.md, STRUCTURE.md, etc.)
- Generated: By Claude GSD mapper
- Committed: Yes

**DerivedData/ (if present):**
- Purpose: Xcode build artifacts
- Generated: Yes (by Xcode build)
- Committed: No (typically in .gitignore)

## Import Patterns

**View files:**
```swift
import SwiftUI
import SwiftData  // For @Query, @Bindable, @Environment modelContext
```

**Model files:**
```swift
import Foundation
import SwiftData  // For @Model decorator
```

**Service files:**
```swift
import Foundation  // Only if needed
```

**Test files:**
```swift
import Testing
@testable import PigeonPlay
```

## Query and Filtering Patterns

**Active games only:**
```swift
@Query(filter: #Predicate<Game> { $0.isActive })
```

**Inactive games, sorted descending:**
```swift
@Query(
    filter: #Predicate<Game> { !$0.isActive },
    sort: \Game.date,
    order: .reverse
)
```

**Players sorted by name:**
```swift
@Query(sort: \Player.name)
```

**Grouping on client:**
```swift
private var boyPlayers: [Player] { players.filter { $0.gender == .b } }
private var girlPlayers: [Player] { players.filter { $0.gender == .g } }
private var xPlayers: [Player] { players.filter { $0.gender == .x } }
```

---

*Structure analysis: 2026-03-17*
