# Coding Conventions

**Analysis Date:** 2026-03-17

## Naming Patterns

**Files:**
- Views: `[Name]View.swift` (e.g., `GameView.swift`, `LineSelectionView.swift`)
- Models: `[Name].swift` (e.g., `Game.swift`, `Player.swift`)
- Services: `[Name]Service.swift` (e.g., `LineSuggester.swift` - note: uses enum pattern instead of service class)
- Tests: `[Name]Tests.swift` (e.g., `GameTests.swift`, `LineSuggesterTests.swift`)

**Functions:**
- camelCase: `suggestLine()`, `removeFromLine()`, `toggleMatching()`
- Private functions: `private func methodName()`
- View body computed property: Always `var body: some View`

**Variables:**
- Properties: camelCase, descriptive names
- State variables: Explicitly annotated with `@State private var`
- Environment variables: `@Environment(\.modelContext)`, `@Query`
- Binding variables: Prefixed with underscore for parameter `@Binding var selectedLine`

**Types:**
- Model classes: PascalCase with `@Model` decorator: `class Game`, `class Player`
- Structs (Views): PascalCase: `struct GameView`
- Enums: PascalCase: `enum GenderRatio`, `enum PointOutcome`
- Computed properties: camelCase: `var ourScore: Int`

## Code Style

**Formatting:**
- Swift 6.0 enforced via `project.yml`
- Deployment target: iOS 18.0
- 4-space indentation (standard Swift)
- No configuration tool detected; style is manual/convention-based

**Linting:**
- No linter detected (no `.swiftlint.yml` or equivalent)
- Code quality relies on manual review and testing

## Import Organization

**Order:**
1. Framework imports first: `import SwiftUI`, `import Foundation`, `import SwiftData`
2. Test-specific imports: `import Testing` (in test files)
3. Module imports: `@testable import PigeonPlay` (in test files)

**Examples:**
```swift
// Model files
import Foundation
import SwiftData

// View files
import SwiftUI
import SwiftData

// Test files
import Testing
import Foundation
import SwiftData
@testable import PigeonPlay
```

## Error Handling

**Patterns:**
- Guard statements for nil checks: `guard !points.isEmpty else { return nil }`
- Guard with condition for validation: `guard selectedLine.count < 5 else { return }`
- Optional chaining: `game.availablePlayers.firstIndex(where: { ... })`
- Model layer throws errors implicitly through guard/return patterns (not explicit throws)

**Example from `LineSuggester.swift`:**
```swift
func suggest(available: [Player], ..., excluding: Set<Player> = []) -> LineSuggestion {
    let excludedIDs = Set(excluding.map { ObjectIdentifier($0) })
    // Early returns and guards for validation
}
```

## Logging

**Framework:** `print()` not observed in analyzed code; logging via UI state updates and test assertions

**Patterns:**
- No explicit logging framework used
- State mutations trigger SwiftUI view updates (implicit logging through state)
- Testing uses assertions for verification

## Comments

**When to Comment:**
- Explain non-obvious algorithm behavior: See `LineSuggester.swift` line 27-28 explaining bench time logic
- Clarify domain-specific logic: Comments explain gender ratio abbreviations (2B = 2 boys, 3G = 3 girls)
- Avoid commenting obvious code: `// Remove from line` is unnecessary

**JSDoc/TSDoc:**
- Not used in this codebase; parameters are self-documenting through type signatures

**Example from `LineSuggester.swift`:**
```swift
// Lower lastPointOnBench = sat out longer = higher priority.
// Missing means never sat out (or first point), treat as 0.
let bench = lastPointOnBench[player] ?? 0
```

## Function Design

**Size:**
- Most functions 5-20 lines
- Helper methods kept small and focused
- No methods exceed 30 lines (viewed through whole file analysis)

**Parameters:**
- Use named parameters for clarity: `suggest(available:, ratio:, pointsPlayed:, lastPointOnBench:, excluding:)`
- Prefer parameter labels to self-document intent
- Default parameters for optional parameters: `excluding: Set<Player> = []`

**Return Values:**
- Explicit optional returns: `func undoLastPoint() -> GamePoint?`
- Struct returns for grouped data: `LineSuggestion` contains `bSide` and `gSide`
- No early returns from multiple guard statements in business logic (see `LineSuggester`)

## Module Design

**Exports:**
- Models marked with `@Model` (SwiftData persistence)
- Views are `struct` implementing `View` protocol
- Services implemented as enums with static methods: `enum LineSuggester { static func suggest() }`

**Barrel Files:**
- No barrel/index files used; imports are direct: `import PigeonPlay` imports entire module
- File-level organization provides structure

**SwiftData Integration:**
- `@Model` decorator on persistent classes: `@Model final class Game`
- `@Query` for fetching data in views: `@Query(filter: #Predicate<Game> { $0.isActive })`
- `@Environment(\.modelContext)` for mutations: `@Environment(\.modelContext) private var modelContext`

## SwiftUI View Conventions

**State Management:**
- Local state: `@State private var variable = default`
- Received state: `@Binding var variable`
- Model binding: `@Bindable var game: Game`
- Environment queries: `@Query`, `@Environment`

**View Composition:**
- Nested structs for logical grouping: `NewGameFlow` and `ActiveGameView` defined in `GameView.swift`
- Helper views: `PlayerRow` in separate struct but same file as parent
- Computed properties for filtered data: See `RosterView.swift` lines 9-11

**Accessibility and Layout:**
- VStack/HStack with explicit spacing: `.padding()`, `.spacing(0)`
- Conditional rendering: `if let` and `switch` on state
- Safe area insets: `.safeAreaInset(edge: .bottom)` for persistent bottom UI
- Material backgrounds: `.ultraThinMaterial` for blur effect

---

*Convention analysis: 2026-03-17*
