# Testing Patterns

**Analysis Date:** 2026-03-17

## Test Framework

**Runner:**
- Swift Testing framework (new in Xcode 16+)
- Config: Part of `project.yml` (target `PigeonPlayTests`, platform iOS)

**Assertion Library:**
- Swift Testing's `#expect()` macro for assertions
- No XCTest framework usage detected

**Run Commands:**
```bash
xcodebuild test -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16'
# or via Xcode UI: Product > Test
```

## Test File Organization

**Location:**
- Co-located in `PigeonPlayTests/` directory (separate from source)
- Test target defined in `project.yml` with dependency on main target

**Naming:**
- `[Subject]Tests.swift`: `GameTests.swift`, `LineSuggesterTests.swift`, `PlayerTests.swift`

**Structure:**
```
PigeonPlayTests/
├── GameTests.swift          # Tests for Game, GamePoint, GenderRatio models
├── LineSuggesterTests.swift # Tests for LineSuggester algorithm
├── PlayerTests.swift        # Tests for Player model
└── PigeonPlayTests.swift    # Placeholder/discovery file
```

## Test Structure

**Suite Organization:**
```swift
import Testing
import Foundation
import SwiftData
@testable import PigeonPlay

@Test func gameCreation() {
    let game = Game(opponent: "Hawks", date: Date())
    #expect(game.opponent == "Hawks")
    #expect(game.points.isEmpty)
}
```

**Patterns:**
- Each test is a top-level function decorated with `@Test`
- No test class grouping; flat namespace per file
- Clear naming: function names describe what is tested
- Setup: Inline object creation with test-specific data
- Teardown: None needed (no persistent state between tests)
- Assertion: `#expect(condition)` for single checks; multiple `#expect` per test when related

**Example from `GameTests.swift`:**
```swift
@Test func undoLastPoint() {
    // Setup
    let game = Game(opponent: "Hawks", date: Date())
    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .us)
    let p2 = GamePoint(number: 2, ratio: .threeBTwoG, outcome: .them)
    game.points = [p1, p2]

    // Execute
    let removed = game.undoLastPoint()

    // Assert
    #expect(removed?.outcome == .them)
    #expect(game.points.count == 1)
    #expect(game.ourScore == 1)
    #expect(game.theirScore == 0)
}
```

## Mocking

**Framework:** No mocking framework detected

**Patterns:**
- Direct object construction with test data
- No stubbing; real objects used
- Test isolation via transient objects (no persistence between tests)

**What to Mock:**
- Not applicable; codebase doesn't use mocking

**What NOT to Mock:**
- Models are always constructed directly; no need for fakes
- Services (like LineSuggester) are stateless enums with no side effects

**Example from `LineSuggesterTests.swift`:**
```swift
let b1 = Player(name: "B1", gender: .b)
let b2 = Player(name: "B2", gender: .b)
let available = [b1, b2, g1, g2, g3, g4]
let suggestion = LineSuggester.suggest(
    available: available,
    ratio: .twoBThreeG,
    pointsPlayed: pointsPlayed,
    lastPointOnBench: lastPointOnBench
)
```

## Fixtures and Factories

**Test Data:**
- Inline construction preferred for clarity
- No fixture files or factories used
- Minimal test data (2-4 objects per test)

**Location:**
- Test data created at start of each test function
- Reused through parameters and variable assignments within test

**Example from `PlayerTests.swift`:**
```swift
@Test func playerWithParentInfo() {
    let player = Player(
        name: "Sam",
        gender: .g,
        parentName: "Pat",
        parentPhone: "555-1234",
        parentEmail: "pat@example.com"
    )
    #expect(player.parentName == "Pat")
}
```

## Coverage

**Requirements:** Not enforced; no coverage targets detected

**View Coverage:**
- Not tested; only models and services tested
- SwiftUI views tested manually in simulator or through Previews

## Test Types

**Unit Tests:**
- Scope: Individual models and pure functions
- Approach: Direct input → output validation
- Coverage: Model initialization, computed properties, state mutations
- Files: `GameTests.swift`, `PlayerTests.swift`, `LineSuggesterTests.swift`

**Example - Model behavior test from `GameTests.swift`:**
```swift
@Test func gameScore() {
    let game = Game(opponent: "Hawks", date: Date())
    let p1 = GamePoint(number: 1, ratio: .twoBThreeG, outcome: .us)
    let p2 = GamePoint(number: 2, ratio: .threeBTwoG, outcome: .them)
    let p3 = GamePoint(number: 3, ratio: .twoBThreeG, outcome: .us)
    game.points = [p1, p2, p3]
    #expect(game.ourScore == 2)
    #expect(game.theirScore == 1)
}
```

**Integration Tests:**
- Not present; view layer untested
- SwiftData persistence not tested in unit tests

**E2E Tests:**
- Not applicable; mobile app uses manual/simulator testing for UI

## Common Patterns

**Enum Testing:**
```swift
@Test func ratioDisplayValues() {
    #expect(GenderRatio.twoBThreeG.displayName == "2B / 3G")
    #expect(GenderRatio.threeBTwoG.displayName == "3B / 2G")
}

@Test func ratioAlternation() {
    #expect(GenderRatio.twoBThreeG.alternated == .threeBTwoG)
    #expect(GenderRatio.threeBTwoG.alternated == .twoBThreeG)
}
```

**Algorithm Correctness - Iteration Pattern:**
```swift
@Test func shuffleNeverPromotesHigherPointsPlayed() {
    // Setup players and play counts
    let pointsPlayed: [Player: Int] = [
        b1: 1, b2: 0, b3: 0,
        g1: 1, g2: 0, g3: 0, g4: 0
    ]

    // Run multiple times to validate stochastic behavior
    for _ in 0..<20 {
        let suggestion = LineSuggester.suggest(
            available: available,
            ratio: .twoBThreeG,
            pointsPlayed: pointsPlayed,
            lastPointOnBench: [:]
        )
        let picked = suggestion.allEntries.map { $0.player }
        #expect(!picked.contains(where: { $0 === b1 }))
        #expect(!picked.contains(where: { $0 === g1 }))
    }
}
```

**Object Identity Testing:**
Use `===` operator to verify same object instance (common in collection tests):
```swift
#expect(suggestion.bSide.map(\.player).contains(where: { $0 === x1 }))
#expect(suggestion.bSide.first(where: { $0.player === x1 })?.matching == .bx)
```

**Set-Based Assertions:**
```swift
let firstPlayers = Set(first.allEntries.map { ObjectIdentifier($0.player) })
let shuffledPlayers = Set(shuffled.allEntries.map { ObjectIdentifier($0.player) })
#expect(shuffledPlayers.contains(ObjectIdentifier(b3)))
#expect(shuffledPlayers != firstPlayers)
```

## Test Totals

- **20 tests** across 3 test files
- **Model tests**: `GameTests.swift` (7 tests), `PlayerTests.swift` (7 tests)
- **Algorithm tests**: `LineSuggesterTests.swift` (8 tests)
- **Coverage**: ~100% of model logic and LineSuggester algorithm
- **Untested**: All SwiftUI views and SwiftData persistence layer

---

*Testing analysis: 2026-03-17*
