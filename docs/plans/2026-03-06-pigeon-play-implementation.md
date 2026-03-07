# Pigeon Play Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an iOS app (Pigeon Play) that manages elementary school ultimate frisbee game-day rosters with fair playing time, gender ratio enforcement, and a play-drawing whiteboard.

**Architecture:** SwiftUI app with four tabs (Roster, Game, Playbook, History). SwiftData for persistence. All local, no backend. The auto-suggest algorithm ensures fair playing time by prioritizing players who've played the fewest points.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, XcodeGen (project generation), Swift Testing (unit tests), iOS 18+ deployment target.

---

### Task 0: Project Scaffolding

**Files:**
- Create: `project.yml` (XcodeGen spec)
- Create: `PigeonPlay/App/PigeonPlayApp.swift`
- Create: `PigeonPlay/App/ContentView.swift`
- Create: `PigeonPlayTests/PigeonPlayTests.swift`

**Step 1: Create project structure**

```bash
mkdir -p PigeonPlay/App
mkdir -p PigeonPlay/Models
mkdir -p PigeonPlay/Views/Roster
mkdir -p PigeonPlay/Views/Game
mkdir -p PigeonPlay/Views/Playbook
mkdir -p PigeonPlay/Views/History
mkdir -p PigeonPlay/Services
mkdir -p PigeonPlayTests
```

**Step 2: Create XcodeGen spec**

Create `project.yml`:

```yaml
name: PigeonPlay
options:
  bundleIdPrefix: com.pigeonplay
  deploymentTarget:
    iOS: "18.0"
  xcodeVersion: "26.2"
settings:
  base:
    SWIFT_VERSION: "6.0"
targets:
  PigeonPlay:
    type: application
    platform: iOS
    sources:
      - PigeonPlay
    settings:
      base:
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
  PigeonPlayTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - PigeonPlayTests
    dependencies:
      - target: PigeonPlay
    settings:
      base:
        SWIFT_VERSION: "6.0"
```

**Step 3: Create app entry point**

Create `PigeonPlay/App/PigeonPlayApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct PigeonPlayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Player.self, Game.self, SavedPlay.self])
    }
}
```

**Step 4: Create placeholder ContentView with tab bar**

Create `PigeonPlay/App/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Roster", systemImage: "person.3") {
                Text("Roster")
            }
            Tab("Game", systemImage: "sportscourt") {
                Text("Game")
            }
            Tab("Playbook", systemImage: "pencil.and.outline") {
                Text("Playbook")
            }
            Tab("History", systemImage: "clock") {
                Text("History")
            }
        }
    }
}
```

**Step 5: Create placeholder test**

Create `PigeonPlayTests/PigeonPlayTests.swift`:

```swift
import Testing

@Test func appLaunches() {
    // Placeholder - will be replaced with real tests
    #expect(true)
}
```

**Step 6: Generate Xcode project and verify it builds**

```bash
xcodegen generate
xcodebuild -project PigeonPlay.xcodeproj -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 7: Add .gitignore and commit**

Create `.gitignore`:

```
# Xcode
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
DerivedData/
build/
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
.swiftpm/

# OS
.DS_Store
```

```bash
git add -A
git commit -m "feat: scaffold Pigeon Play iOS project with XcodeGen"
```

---

### Task 1: Player Model

**Files:**
- Create: `PigeonPlay/Models/Player.swift`
- Create: `PigeonPlayTests/PlayerTests.swift`

**Step 1: Write the failing test**

Create `PigeonPlayTests/PlayerTests.swift`:

```swift
import Testing
import SwiftData
@testable import PigeonPlay

@Test func playerRequiredFields() {
    let player = Player(name: "Alex", gender: .x, defaultMatching: .bx)
    #expect(player.name == "Alex")
    #expect(player.gender == .x)
    #expect(player.defaultMatching == .bx)
}

@Test func playerOptionalFields() {
    let player = Player(name: "Jordan", gender: .b)
    #expect(player.parentName == nil)
    #expect(player.parentPhone == nil)
    #expect(player.parentEmail == nil)
    #expect(player.defaultMatching == nil)
}

@Test func playerWithParentInfo() {
    let player = Player(
        name: "Sam",
        gender: .g,
        parentName: "Pat",
        parentPhone: "555-1234",
        parentEmail: "pat@example.com"
    )
    #expect(player.parentName == "Pat")
    #expect(player.parentPhone == "555-1234")
    #expect(player.parentEmail == "pat@example.com")
}

@Test func genderDisplayValues() {
    #expect(Gender.b.displayName == "B")
    #expect(Gender.g.displayName == "G")
    #expect(Gender.x.displayName == "X")
}

@Test func matchingDisplayValues() {
    #expect(GenderMatching.bx.displayName == "Bx")
    #expect(GenderMatching.gx.displayName == "Gx")
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -project PigeonPlay.xcodeproj -scheme PigeonPlayTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: FAIL - Player type not found

**Step 3: Write minimal implementation**

Create `PigeonPlay/Models/Player.swift`:

```swift
import Foundation
import SwiftData

enum Gender: String, Codable, CaseIterable {
    case b, g, x

    var displayName: String {
        rawValue.uppercased()
    }
}

enum GenderMatching: String, Codable, CaseIterable {
    case bx, gx

    var displayName: String {
        switch self {
        case .bx: "Bx"
        case .gx: "Gx"
        }
    }
}

@Model
final class Player {
    var name: String
    var gender: Gender
    var defaultMatching: GenderMatching?
    var parentName: String?
    var parentPhone: String?
    var parentEmail: String?

    init(
        name: String,
        gender: Gender,
        defaultMatching: GenderMatching? = nil,
        parentName: String? = nil,
        parentPhone: String? = nil,
        parentEmail: String? = nil
    ) {
        self.name = name
        self.gender = gender
        self.defaultMatching = defaultMatching
        self.parentName = parentName
        self.parentPhone = parentPhone
        self.parentEmail = parentEmail
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -project PigeonPlay.xcodeproj -scheme PigeonPlayTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: PASS

**Step 5: Commit**

```bash
git add PigeonPlay/Models/Player.swift PigeonPlayTests/PlayerTests.swift
git commit -m "feat: add Player model with Gender and GenderMatching enums"
```

---

### Task 2: Game & Point Models

**Files:**
- Create: `PigeonPlay/Models/Game.swift`
- Create: `PigeonPlayTests/GameTests.swift`

**Step 1: Write the failing test**

Create `PigeonPlayTests/GameTests.swift`:

```swift
import Testing
import SwiftData
@testable import PigeonPlay

@Test func gameCreation() {
    let game = Game(opponent: "Hawks", date: Date())
    #expect(game.opponent == "Hawks")
    #expect(game.points.isEmpty)
    #expect(game.availablePlayers.isEmpty)
    #expect(game.isActive == true)
}

@Test func ratioDisplayValues() {
    #expect(GenderRatio.twoBThreeG.displayName == "2B / 3G")
    #expect(GenderRatio.threeBTwoG.displayName == "3B / 2G")
}

@Test func ratioAlternation() {
    #expect(GenderRatio.twoBThreeG.alternated == .threeBTwoG)
    #expect(GenderRatio.threeBTwoG.alternated == .twoBThreeG)
}

@Test func ratioCounts() {
    let ratio = GenderRatio.twoBThreeG
    #expect(ratio.bSideCount == 2)
    #expect(ratio.gSideCount == 3)

    let other = GenderRatio.threeBTwoG
    #expect(other.bSideCount == 3)
    #expect(other.gSideCount == 2)
}

@Test func pointCreation() {
    let point = GamePoint(
        number: 1,
        ratio: .twoBThreeG,
        outcome: .us
    )
    #expect(point.number == 1)
    #expect(point.ratio == .twoBThreeG)
    #expect(point.outcome == .us)
    #expect(point.scorer == nil)
    #expect(point.assist == nil)
}

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

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -project PigeonPlay.xcodeproj -scheme PigeonPlayTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: FAIL

**Step 3: Write minimal implementation**

Create `PigeonPlay/Models/Game.swift`:

```swift
import Foundation
import SwiftData

enum GenderRatio: String, Codable {
    case twoBThreeG
    case threeBTwoG

    var displayName: String {
        switch self {
        case .twoBThreeG: "2B / 3G"
        case .threeBTwoG: "3B / 2G"
        }
    }

    var alternated: GenderRatio {
        switch self {
        case .twoBThreeG: .threeBTwoG
        case .threeBTwoG: .twoBThreeG
        }
    }

    var bSideCount: Int {
        switch self {
        case .twoBThreeG: 2
        case .threeBTwoG: 3
        }
    }

    var gSideCount: Int {
        switch self {
        case .twoBThreeG: 3
        case .threeBTwoG: 2
        }
    }
}

enum PointOutcome: String, Codable {
    case us, them
}

@Model
final class PointPlayer {
    var player: Player
    var effectiveGender: GenderMatching

    init(player: Player, effectiveGender: GenderMatching) {
        self.player = player
        self.effectiveGender = effectiveGender
    }
}

@Model
final class GamePoint {
    var number: Int
    var ratio: GenderRatio
    var outcome: PointOutcome
    var onFieldPlayers: [PointPlayer]
    var scorer: Player?
    var assist: Player?

    init(
        number: Int,
        ratio: GenderRatio,
        outcome: PointOutcome,
        onFieldPlayers: [PointPlayer] = [],
        scorer: Player? = nil,
        assist: Player? = nil
    ) {
        self.number = number
        self.ratio = ratio
        self.outcome = outcome
        self.onFieldPlayers = onFieldPlayers
        self.scorer = scorer
        self.assist = assist
    }
}

@Model
final class Game {
    var opponent: String
    var date: Date
    var points: [GamePoint]
    var availablePlayers: [Player]
    var isActive: Bool

    init(opponent: String, date: Date) {
        self.opponent = opponent
        self.date = date
        self.points = []
        self.availablePlayers = []
        self.isActive = true
    }

    var ourScore: Int {
        points.filter { $0.outcome == .us }.count
    }

    var theirScore: Int {
        points.filter { $0.outcome == .them }.count
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -project PigeonPlay.xcodeproj -scheme PigeonPlayTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: PASS

**Step 5: Commit**

```bash
git add PigeonPlay/Models/Game.swift PigeonPlayTests/GameTests.swift
git commit -m "feat: add Game, GamePoint, and GenderRatio models"
```

---

### Task 3: Auto-Suggest Algorithm

**Files:**
- Create: `PigeonPlay/Services/LineSuggester.swift`
- Create: `PigeonPlayTests/LineSuggesterTests.swift`

**Step 1: Write the failing tests**

Create `PigeonPlayTests/LineSuggesterTests.swift`:

```swift
import Testing
@testable import PigeonPlay

@Test func suggestsPlayersWithFewestPoints() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)
    let g4 = Player(name: "G4", gender: .g)

    let available = [b1, b2, g1, g2, g3, g4]
    // g1 has played 2 points, everyone else 0
    let pointsPlayed: [Player: Int] = [
        b1: 0, b2: 0, g1: 2, g2: 0, g3: 0, g4: 0
    ]
    let lastPointOnBench: [Player: Int] = [:]

    let suggestion = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )

    #expect(suggestion.bSide.count == 2)
    #expect(suggestion.gSide.count == 3)
    // g1 should NOT be suggested since she's played the most
    #expect(!suggestion.gSide.map(\.player).contains(where: { $0 === g1 }))
}

@Test func respectsGenderRatio() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let b3 = Player(name: "B3", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)

    let available = [b1, b2, b3, g1, g2, g3]
    let pointsPlayed: [Player: Int] = [:]
    let lastPointOnBench: [Player: Int] = [:]

    let twoBThreeG = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )
    #expect(twoBThreeG.bSide.count == 2)
    #expect(twoBThreeG.gSide.count == 3)

    let threeBTwoG = LineSuggester.suggest(
        available: available,
        ratio: .threeBTwoG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )
    #expect(threeBTwoG.bSide.count == 3)
    #expect(threeBTwoG.gSide.count == 2)
}

@Test func xPlayersUseDefaultMatching() {
    let b1 = Player(name: "B1", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)
    let x1 = Player(name: "X1", gender: .x, defaultMatching: .bx)

    let available = [b1, g1, g2, g3, x1]
    let pointsPlayed: [Player: Int] = [:]
    let lastPointOnBench: [Player: Int] = [:]

    let suggestion = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )

    // X1 defaults to Bx, so should be on B-side
    #expect(suggestion.bSide.map(\.player).contains(where: { $0 === x1 }))
    #expect(suggestion.bSide.first(where: { $0.player === x1 })?.matching == .bx)
}

@Test func tieBreaksByBenchTime() {
    let b1 = Player(name: "B1", gender: .b)
    let b2 = Player(name: "B2", gender: .b)
    let b3 = Player(name: "B3", gender: .b)
    let g1 = Player(name: "G1", gender: .g)
    let g2 = Player(name: "G2", gender: .g)
    let g3 = Player(name: "G3", gender: .g)

    let available = [b1, b2, b3, g1, g2, g3]
    // All have 1 point played
    let pointsPlayed: [Player: Int] = [
        b1: 1, b2: 1, b3: 1, g1: 1, g2: 1, g3: 1
    ]
    // b3 has been on bench since point 1 (longest), b1 since point 3 (shortest)
    let lastPointOnBench: [Player: Int] = [
        b1: 3, b2: 2, b3: 1
    ]

    let suggestion = LineSuggester.suggest(
        available: available,
        ratio: .twoBThreeG,
        pointsPlayed: pointsPlayed,
        lastPointOnBench: lastPointOnBench
    )

    // b3 should be picked over b1 (sat out longer)
    let bPlayers = suggestion.bSide.map(\.player)
    #expect(bPlayers.contains(where: { $0 === b3 }))
    #expect(bPlayers.contains(where: { $0 === b2 }))
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -project PigeonPlay.xcodeproj -scheme PigeonPlayTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: FAIL

**Step 3: Write minimal implementation**

Create `PigeonPlay/Services/LineSuggester.swift`:

```swift
import Foundation

struct LineSuggestion {
    struct Entry {
        let player: Player
        let matching: GenderMatching
    }

    let bSide: [Entry]
    let gSide: [Entry]

    var allEntries: [Entry] { bSide + gSide }
}

enum LineSuggester {
    static func suggest(
        available: [Player],
        ratio: GenderRatio,
        pointsPlayed: [Player: Int],
        lastPointOnBench: [Player: Int]
    ) -> LineSuggestion {
        func sortKey(_ player: Player) -> (Int, Int) {
            let played = pointsPlayed[player] ?? 0
            // Lower lastPointOnBench = sat out longer = higher priority.
            // Missing means never sat out (or first point), treat as 0.
            let bench = lastPointOnBench[player] ?? 0
            return (played, bench)
        }

        let bPool = available.filter { p in
            p.gender == .b || (p.gender == .x && p.defaultMatching == .bx)
        }.sorted { sortKey($0) < sortKey($1) }

        let gPool = available.filter { p in
            p.gender == .g || (p.gender == .x && p.defaultMatching == .gx)
        }.sorted { sortKey($0) < sortKey($1) }

        let bSide = Array(bPool.prefix(ratio.bSideCount)).map { player in
            LineSuggestion.Entry(
                player: player,
                matching: player.gender == .x ? .bx : .bx
            )
        }

        let gSide = Array(gPool.prefix(ratio.gSideCount)).map { player in
            LineSuggestion.Entry(
                player: player,
                matching: player.gender == .x ? .gx : .gx
            )
        }

        return LineSuggestion(bSide: bSide, gSide: gSide)
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -project PigeonPlay.xcodeproj -scheme PigeonPlayTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: PASS

**Step 5: Commit**

```bash
git add PigeonPlay/Services/LineSuggester.swift PigeonPlayTests/LineSuggesterTests.swift
git commit -m "feat: add LineSuggester algorithm for fair playing time"
```

---

### Task 4: Roster Tab UI

**Files:**
- Create: `PigeonPlay/Views/Roster/RosterView.swift`
- Create: `PigeonPlay/Views/Roster/PlayerFormView.swift`

**Step 1: Create RosterView**

Create `PigeonPlay/Views/Roster/RosterView.swift`:

```swift
import SwiftUI
import SwiftData

struct RosterView: View {
    @Query(sort: \Player.name) private var players: [Player]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddPlayer = false

    private var boyPlayers: [Player] { players.filter { $0.gender == .b } }
    private var girlPlayers: [Player] { players.filter { $0.gender == .g } }
    private var xPlayers: [Player] { players.filter { $0.gender == .x } }

    var body: some View {
        NavigationStack {
            List {
                if !boyPlayers.isEmpty {
                    Section("Boys") {
                        ForEach(boyPlayers) { player in
                            NavigationLink(value: player) {
                                PlayerRow(player: player)
                            }
                        }
                        .onDelete { offsets in
                            delete(offsets, from: boyPlayers)
                        }
                    }
                }
                if !girlPlayers.isEmpty {
                    Section("Girls") {
                        ForEach(girlPlayers) { player in
                            NavigationLink(value: player) {
                                PlayerRow(player: player)
                            }
                        }
                        .onDelete { offsets in
                            delete(offsets, from: girlPlayers)
                        }
                    }
                }
                if !xPlayers.isEmpty {
                    Section("X") {
                        ForEach(xPlayers) { player in
                            NavigationLink(value: player) {
                                PlayerRow(player: player)
                            }
                        }
                        .onDelete { offsets in
                            delete(offsets, from: xPlayers)
                        }
                    }
                }
            }
            .navigationTitle("Roster")
            .navigationDestination(for: Player.self) { player in
                PlayerFormView(player: player)
            }
            .toolbar {
                Button("Add Player", systemImage: "plus") {
                    showingAddPlayer = true
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                NavigationStack {
                    PlayerFormView(player: nil)
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet, from group: [Player]) {
        for index in offsets {
            modelContext.delete(group[index])
        }
    }
}

struct PlayerRow: View {
    let player: Player

    var body: some View {
        HStack {
            Text(player.name)
            Spacer()
            if let matching = player.defaultMatching {
                Text(matching.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

**Step 2: Create PlayerFormView**

Create `PigeonPlay/Views/Roster/PlayerFormView.swift`:

```swift
import SwiftUI
import SwiftData

struct PlayerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Player?

    @State private var name: String = ""
    @State private var gender: Gender = .b
    @State private var defaultMatching: GenderMatching = .bx
    @State private var parentName: String = ""
    @State private var parentPhone: String = ""
    @State private var parentEmail: String = ""

    private var isEditing: Bool { player != nil }

    var body: some View {
        Form {
            Section("Player Info") {
                TextField("Name", text: $name)
                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                if gender == .x {
                    Picker("Default Matching", selection: $defaultMatching) {
                        ForEach(GenderMatching.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                }
            }
            Section("Parent Contact (Optional)") {
                TextField("Parent Name", text: $parentName)
                TextField("Phone", text: $parentPhone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $parentEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
        }
        .navigationTitle(isEditing ? "Edit Player" : "Add Player")
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let player {
                name = player.name
                gender = player.gender
                defaultMatching = player.defaultMatching ?? .bx
                parentName = player.parentName ?? ""
                parentPhone = player.parentPhone ?? ""
                parentEmail = player.parentEmail ?? ""
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let player {
            player.name = trimmedName
            player.gender = gender
            player.defaultMatching = gender == .x ? defaultMatching : nil
            player.parentName = parentName.isEmpty ? nil : parentName
            player.parentPhone = parentPhone.isEmpty ? nil : parentPhone
            player.parentEmail = parentEmail.isEmpty ? nil : parentEmail
        } else {
            let newPlayer = Player(
                name: trimmedName,
                gender: gender,
                defaultMatching: gender == .x ? defaultMatching : nil,
                parentName: parentName.isEmpty ? nil : parentName,
                parentPhone: parentPhone.isEmpty ? nil : parentPhone,
                parentEmail: parentEmail.isEmpty ? nil : parentEmail
            )
            modelContext.insert(newPlayer)
        }
        dismiss()
    }
}
```

**Step 3: Wire up ContentView**

Update `PigeonPlay/App/ContentView.swift` to use `RosterView()` in the Roster tab instead of `Text("Roster")`.

**Step 4: Build and verify**

```bash
xcodebuild build -project PigeonPlay.xcodeproj -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add PigeonPlay/Views/Roster/ PigeonPlay/App/ContentView.swift
git commit -m "feat: add Roster tab with player list and add/edit form"
```

---

### Task 5: Game Tab - New Game & Check-In

**Files:**
- Create: `PigeonPlay/Views/Game/GameView.swift`
- Create: `PigeonPlay/Views/Game/CheckInView.swift`

**Step 1: Create CheckInView**

Create `PigeonPlay/Views/Game/CheckInView.swift`:

```swift
import SwiftUI
import SwiftData

struct CheckInView: View {
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Binding var checkedInPlayers: Set<PersistentIdentifier>
    let onConfirm: () -> Void

    var body: some View {
        List {
            ForEach(allPlayers) { player in
                Button {
                    toggle(player)
                } label: {
                    HStack {
                        Image(systemName: checkedInPlayers.contains(player.persistentModelID) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkedInPlayers.contains(player.persistentModelID) ? .green : .secondary)
                        Text(player.name)
                        Spacer()
                        Text(player.gender.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
        }
        .navigationTitle("Who's Here?")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Start Game") { onConfirm() }
                    .disabled(checkedInPlayers.isEmpty)
            }
        }
    }

    private func toggle(_ player: Player) {
        if checkedInPlayers.contains(player.persistentModelID) {
            checkedInPlayers.remove(player.persistentModelID)
        } else {
            checkedInPlayers.insert(player.persistentModelID)
        }
    }
}
```

**Step 2: Create GameView**

Create `PigeonPlay/Views/Game/GameView.swift`:

```swift
import SwiftUI
import SwiftData

struct GameView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Game> { $0.isActive }) private var activeGames: [Game]
    @Query(sort: \Player.name) private var allPlayers: [Player]

    @State private var showingNewGame = false
    @State private var opponentName = ""
    @State private var checkedInPlayerIDs: Set<PersistentIdentifier> = []

    private var activeGame: Game? { activeGames.first }

    var body: some View {
        NavigationStack {
            if let game = activeGame {
                ActiveGameView(game: game)
            } else {
                ContentUnavailableView {
                    Label("No Active Game", systemImage: "sportscourt")
                } description: {
                    Text("Start a new game to begin tracking.")
                } actions: {
                    Button("New Game") { showingNewGame = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Game")
        .sheet(isPresented: $showingNewGame) {
            NavigationStack {
                NewGameFlow(
                    opponentName: $opponentName,
                    checkedInPlayerIDs: $checkedInPlayerIDs,
                    onCreate: createGame
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingNewGame = false
                            opponentName = ""
                            checkedInPlayerIDs = []
                        }
                    }
                }
            }
        }
    }

    private func createGame() {
        let game = Game(opponent: opponentName, date: Date())
        game.availablePlayers = allPlayers.filter {
            checkedInPlayerIDs.contains($0.persistentModelID)
        }
        modelContext.insert(game)
        showingNewGame = false
        opponentName = ""
        checkedInPlayerIDs = []
    }
}

struct NewGameFlow: View {
    @Binding var opponentName: String
    @Binding var checkedInPlayerIDs: Set<PersistentIdentifier>
    let onCreate: () -> Void

    @State private var showingCheckIn = false

    var body: some View {
        Form {
            Section("Opponent") {
                TextField("Team name", text: $opponentName)
            }
            Section {
                Button("Next: Check In Players") {
                    showingCheckIn = true
                }
                .disabled(opponentName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("New Game")
        .navigationDestination(isPresented: $showingCheckIn) {
            CheckInView(
                checkedInPlayers: $checkedInPlayerIDs,
                onConfirm: onCreate
            )
        }
    }
}
```

**Step 3: Create placeholder ActiveGameView**

This will be fleshed out in Task 6. For now:

Add to the bottom of `PigeonPlay/Views/Game/GameView.swift`:

```swift
struct ActiveGameView: View {
    let game: Game

    var body: some View {
        Text("Game vs \(game.opponent) - \(game.ourScore) to \(game.theirScore)")
    }
}
```

**Step 4: Wire up ContentView**

Update `PigeonPlay/App/ContentView.swift` to use `GameView()` in the Game tab.

**Step 5: Build and verify**

```bash
xcodebuild build -project PigeonPlay.xcodeproj -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add PigeonPlay/Views/Game/ PigeonPlay/App/ContentView.swift
git commit -m "feat: add Game tab with new game flow and player check-in"
```

---

### Task 6: Active Game View - Line Selection & Point Recording

**Files:**
- Create: `PigeonPlay/Views/Game/LineSelectionView.swift`
- Create: `PigeonPlay/Views/Game/RecordPointView.swift`
- Modify: `PigeonPlay/Views/Game/GameView.swift` (replace ActiveGameView placeholder)

**Step 1: Create LineSelectionView**

Create `PigeonPlay/Views/Game/LineSelectionView.swift`:

```swift
import SwiftUI

struct LineSelectionView: View {
    let available: [Player]
    let ratio: GenderRatio
    let pointsPlayed: [Player: Int]
    let lastPointOnBench: [Player: Int]
    @Binding var selectedLine: [LineSuggestion.Entry]
    @State private var suggestion: LineSuggestion?

    private var onField: Set<ObjectIdentifier> {
        Set(selectedLine.map { ObjectIdentifier($0.player) })
    }

    private var bench: [Player] {
        available.filter { !onField.contains(ObjectIdentifier($0)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Ratio display
            Text(ratio.displayName)
                .font(.headline)
                .padding(.vertical, 8)

            // On field
            Section {
                ForEach(Array(selectedLine.enumerated()), id: \.offset) { index, entry in
                    HStack {
                        Text(entry.player.name)
                        Spacer()
                        if entry.player.gender == .x {
                            Button(entry.matching.displayName) {
                                toggleMatching(at: index)
                            }
                            .buttonStyle(.bordered)
                            .tint(entry.matching == .bx ? .blue : .pink)
                        } else {
                            Text(entry.player.gender.displayName)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(pointsPlayed[entry.player] ?? 0)pts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            removeFromLine(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("On Field (\(selectedLine.count)/5)")
                    .font(.subheadline.bold())
            }

            Divider().padding(.vertical, 8)

            // Bench
            Section {
                ForEach(bench) { player in
                    Button {
                        addToLine(player)
                    } label: {
                        HStack {
                            Text(player.name)
                            Spacer()
                            Text(player.gender.displayName)
                                .foregroundStyle(.secondary)
                            Text("\(pointsPlayed[player] ?? 0)pts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .tint(.primary)
                }
            } header: {
                Text("Bench")
                    .font(.subheadline.bold())
            }
        }
        .padding()
        .onAppear { autoSuggest() }
    }

    private func autoSuggest() {
        let s = LineSuggester.suggest(
            available: available,
            ratio: ratio,
            pointsPlayed: pointsPlayed,
            lastPointOnBench: lastPointOnBench
        )
        selectedLine = s.allEntries
        suggestion = s
    }

    private func toggleMatching(at index: Int) {
        let current = selectedLine[index]
        let newMatching: GenderMatching = current.matching == .bx ? .gx : .bx
        selectedLine[index] = LineSuggestion.Entry(player: current.player, matching: newMatching)
    }

    private func removeFromLine(at index: Int) {
        selectedLine.remove(at: index)
    }

    private func addToLine(_ player: Player) {
        guard selectedLine.count < 5 else { return }
        let matching: GenderMatching = switch player.gender {
        case .b: .bx
        case .g: .gx
        case .x: player.defaultMatching ?? .bx
        }
        selectedLine.append(LineSuggestion.Entry(player: player, matching: matching))
    }
}
```

**Step 2: Create RecordPointView**

Create `PigeonPlay/Views/Game/RecordPointView.swift`:

```swift
import SwiftUI

struct RecordPointView: View {
    let onFieldPlayers: [LineSuggestion.Entry]
    let onRecord: (PointOutcome, Player?, Player?) -> Void

    @State private var scorer: Player?
    @State private var assist: Player?
    @State private var showingScorerPicker = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Who scored?")
                .font(.title2.bold())

            Button {
                onRecord(.them, nil, nil)
            } label: {
                Text("Them")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Divider()

            Text("Us — tap scorer:")
                .font(.subheadline)

            ForEach(onFieldPlayers, id: \.player.persistentModelID) { entry in
                Button {
                    if scorer?.persistentModelID == entry.player.persistentModelID {
                        scorer = nil
                    } else {
                        scorer = entry.player
                    }
                } label: {
                    HStack {
                        Text(entry.player.name)
                        Spacer()
                        if scorer?.persistentModelID == entry.player.persistentModelID {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .tint(.primary)
            }

            if scorer != nil {
                Divider()
                Text("Assist (optional):")
                    .font(.subheadline)

                ForEach(onFieldPlayers.filter { $0.player.persistentModelID != scorer?.persistentModelID }, id: \.player.persistentModelID) { entry in
                    Button {
                        if assist?.persistentModelID == entry.player.persistentModelID {
                            assist = nil
                        } else {
                            assist = entry.player
                        }
                    } label: {
                        HStack {
                            Text(entry.player.name)
                            Spacer()
                            if assist?.persistentModelID == entry.player.persistentModelID {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                }
            }

            if scorer != nil {
                Button {
                    onRecord(.us, scorer, assist)
                } label: {
                    Text("Confirm")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

**Step 3: Replace ActiveGameView**

Replace the placeholder `ActiveGameView` in `PigeonPlay/Views/Game/GameView.swift` with:

```swift
struct ActiveGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var game: Game

    @State private var currentRatio: GenderRatio = .twoBThreeG
    @State private var selectedLine: [LineSuggestion.Entry] = []
    @State private var phase: GamePhase = .selectingLine
    @State private var showingAvailability = false

    enum GamePhase {
        case selectingLine
        case recordingPoint
    }

    private var pointsPlayed: [Player: Int] {
        var counts: [Player: Int] = [:]
        for player in game.availablePlayers {
            counts[player] = 0
        }
        for point in game.points {
            for pp in point.onFieldPlayers {
                counts[pp.player, default: 0] += 1
            }
        }
        return counts
    }

    private var lastPointOnBench: [Player: Int] {
        var last: [Player: Int] = [:]
        let onFieldIDs = Set(selectedLine.map { ObjectIdentifier($0.player) })
        for (index, point) in game.points.enumerated() {
            let playedIDs = Set(point.onFieldPlayers.map { ObjectIdentifier($0.player) })
            for player in game.availablePlayers where !playedIDs.contains(ObjectIdentifier(player)) {
                last[player] = index + 1
            }
        }
        return last
    }

    var body: some View {
        VStack {
            // Scoreboard
            HStack {
                VStack {
                    Text("Us")
                        .font(.caption)
                    Text("\(game.ourScore)")
                        .font(.largeTitle.bold())
                }
                Spacer()
                VStack {
                    Text("Point \(game.points.count + 1)")
                        .font(.caption)
                    Text("vs \(game.opponent)")
                        .font(.headline)
                }
                Spacer()
                VStack {
                    Text("Them")
                        .font(.caption)
                    Text("\(game.theirScore)")
                        .font(.largeTitle.bold())
                }
            }
            .padding()

            Divider()

            switch phase {
            case .selectingLine:
                // Ratio picker
                Picker("Ratio", selection: $currentRatio) {
                    Text("2B / 3G").tag(GenderRatio.twoBThreeG)
                    Text("3B / 2G").tag(GenderRatio.threeBTwoG)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView {
                    LineSelectionView(
                        available: game.availablePlayers,
                        ratio: currentRatio,
                        pointsPlayed: pointsPlayed,
                        lastPointOnBench: lastPointOnBench,
                        selectedLine: $selectedLine
                    )
                }

                Button("Lock In") {
                    phase = .recordingPoint
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedLine.count != 5)
                .padding()

            case .recordingPoint:
                RecordPointView(onFieldPlayers: selectedLine) { outcome, scorer, assist in
                    recordPoint(outcome: outcome, scorer: scorer, assist: assist)
                }
            }

            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Players", systemImage: "person.badge.plus") {
                    showingAvailability = true
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("End Game") {
                    game.isActive = false
                }
            }
        }
        .sheet(isPresented: $showingAvailability) {
            NavigationStack {
                AvailabilityView(game: game)
            }
        }
    }

    private func recordPoint(outcome: PointOutcome, scorer: Player?, assist: Player?) {
        let pointPlayers = selectedLine.map { entry in
            PointPlayer(player: entry.player, effectiveGender: entry.matching)
        }
        let point = GamePoint(
            number: game.points.count + 1,
            ratio: currentRatio,
            outcome: outcome,
            onFieldPlayers: pointPlayers,
            scorer: scorer,
            assist: assist
        )
        game.points.append(point)
        currentRatio = currentRatio.alternated
        selectedLine = []
        phase = .selectingLine
    }
}
```

**Step 4: Create AvailabilityView for mid-game roster changes**

Add to the bottom of `PigeonPlay/Views/Game/GameView.swift`:

```swift
struct AvailabilityView: View {
    @Bindable var game: Game
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Environment(\.dismiss) private var dismiss

    private var availableIDs: Set<PersistentIdentifier> {
        Set(game.availablePlayers.map(\.persistentModelID))
    }

    var body: some View {
        List {
            ForEach(allPlayers) { player in
                Button {
                    toggle(player)
                } label: {
                    HStack {
                        Image(systemName: availableIDs.contains(player.persistentModelID) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(availableIDs.contains(player.persistentModelID) ? .green : .secondary)
                        Text(player.name)
                        Spacer()
                        Text(player.gender.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
        }
        .navigationTitle("Available Players")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func toggle(_ player: Player) {
        if let index = game.availablePlayers.firstIndex(where: { $0.persistentModelID == player.persistentModelID }) {
            game.availablePlayers.remove(at: index)
        } else {
            game.availablePlayers.append(player)
        }
    }
}
```

**Step 5: Build and verify**

```bash
xcodebuild build -project PigeonPlay.xcodeproj -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add PigeonPlay/Views/Game/
git commit -m "feat: add active game view with line selection and point recording"
```

---

### Task 7: Playbook Tab - Field Canvas & Drawing

**Files:**
- Create: `PigeonPlay/Models/SavedPlay.swift`
- Create: `PigeonPlay/Views/Playbook/PlaybookView.swift`
- Create: `PigeonPlay/Views/Playbook/FieldCanvasView.swift`
- Create: `PigeonPlay/Views/Playbook/DrawingToolbar.swift`

**Step 1: Create SavedPlay model**

Create `PigeonPlay/Models/SavedPlay.swift`:

```swift
import Foundation
import SwiftData

enum DrawingElement: Codable {
    case stroke(points: [CGPoint], color: String, lineWidth: CGFloat)
    case arrow(from: CGPoint, to: CGPoint, color: String)
    case circle(center: CGPoint, color: String)
}

extension CGPoint: @retroactive Codable {
    enum CodingKeys: String, CodingKey { case x, y }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decode(CGFloat.self, forKey: .x), y: try c.decode(CGFloat.self, forKey: .y))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
    }
}

@Model
final class SavedPlay {
    var name: String
    var elements: [DrawingElement]
    var dateCreated: Date

    init(name: String, elements: [DrawingElement] = [], dateCreated: Date = Date()) {
        self.name = name
        self.elements = elements
        self.dateCreated = dateCreated
    }
}
```

**Step 2: Create FieldCanvasView**

Create `PigeonPlay/Views/Playbook/FieldCanvasView.swift`:

```swift
import SwiftUI

enum DrawingTool {
    case pen, arrow, circle, eraser
}

struct FieldCanvasView: View {
    @Binding var elements: [DrawingElement]
    @Binding var currentTool: DrawingTool
    @Binding var currentColor: String
    let isHorizontal: Bool

    @State private var currentStrokePoints: [CGPoint] = []
    @State private var arrowStart: CGPoint?
    @State private var undoStack: [[DrawingElement]] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Field background
                FieldBackground(isHorizontal: isHorizontal)

                // Rendered elements
                Canvas { context, size in
                    for element in elements {
                        draw(element, in: &context, size: size)
                    }
                    // Current stroke in progress
                    if !currentStrokePoints.isEmpty {
                        let stroke = DrawingElement.stroke(points: currentStrokePoints, color: currentColor, lineWidth: 3)
                        draw(stroke, in: &context, size: size)
                    }
                }
                .gesture(drawingGesture(in: geo.size))
            }
        }
    }

    private func draw(_ element: DrawingElement, in context: inout GraphicsContext, size: CGSize) {
        switch element {
        case .stroke(let points, let color, let lineWidth):
            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(path, with: .color(Color(namedColor: color)), lineWidth: lineWidth)

        case .arrow(let from, let to, let color):
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            // Arrowhead
            let angle = atan2(to.y - from.y, to.x - from.x)
            let headLength: CGFloat = 15
            let head1 = CGPoint(
                x: to.x - headLength * cos(angle - .pi / 6),
                y: to.y - headLength * sin(angle - .pi / 6)
            )
            let head2 = CGPoint(
                x: to.x - headLength * cos(angle + .pi / 6),
                y: to.y - headLength * sin(angle + .pi / 6)
            )
            path.move(to: to)
            path.addLine(to: head1)
            path.move(to: to)
            path.addLine(to: head2)
            context.stroke(path, with: .color(Color(namedColor: color)), lineWidth: 3)

        case .circle(let center, let color):
            let radius: CGFloat = 12
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Color(namedColor: color)))
        }
    }

    private func drawingGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = value.location
                switch currentTool {
                case .pen:
                    currentStrokePoints.append(point)
                case .arrow:
                    if arrowStart == nil {
                        arrowStart = point
                    }
                case .circle:
                    break
                case .eraser:
                    currentStrokePoints.append(point)
                }
            }
            .onEnded { value in
                let point = value.location
                switch currentTool {
                case .pen:
                    if currentStrokePoints.count > 1 {
                        saveUndo()
                        elements.append(.stroke(points: currentStrokePoints, color: currentColor, lineWidth: 3))
                    }
                    currentStrokePoints = []
                case .arrow:
                    if let start = arrowStart {
                        saveUndo()
                        elements.append(.arrow(from: start, to: point, color: currentColor))
                    }
                    arrowStart = nil
                case .circle:
                    saveUndo()
                    elements.append(.circle(center: point, color: currentColor))
                case .eraser:
                    // Remove elements that intersect with the eraser path
                    saveUndo()
                    removeIntersecting(with: currentStrokePoints)
                    currentStrokePoints = []
                }
            }
    }

    private func removeIntersecting(with eraserPoints: [CGPoint]) {
        let threshold: CGFloat = 20
        elements.removeAll { element in
            switch element {
            case .stroke(let points, _, _):
                return points.contains { sp in
                    eraserPoints.contains { ep in
                        hypot(sp.x - ep.x, sp.y - ep.y) < threshold
                    }
                }
            case .arrow(let from, let to, _):
                return eraserPoints.contains { ep in
                    hypot(from.x - ep.x, from.y - ep.y) < threshold ||
                    hypot(to.x - ep.x, to.y - ep.y) < threshold
                }
            case .circle(let center, _):
                return eraserPoints.contains { ep in
                    hypot(center.x - ep.x, center.y - ep.y) < threshold
                }
            }
        }
    }

    func undo() {
        if let previous = undoStack.popLast() {
            elements = previous
        }
    }

    private func saveUndo() {
        undoStack.append(elements)
    }
}

struct FieldBackground: View {
    let isHorizontal: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let endZoneDepth: CGFloat = isHorizontal ? w * 0.15 : h * 0.15

            Canvas { context, size in
                // Field
                let fieldRect = CGRect(origin: .zero, size: size)
                context.fill(Path(fieldRect), with: .color(.green.opacity(0.3)))

                // End zones
                if isHorizontal {
                    let leftEZ = CGRect(x: 0, y: 0, width: endZoneDepth, height: h)
                    let rightEZ = CGRect(x: w - endZoneDepth, y: 0, width: endZoneDepth, height: h)
                    context.fill(Path(leftEZ), with: .color(.green.opacity(0.5)))
                    context.fill(Path(rightEZ), with: .color(.green.opacity(0.5)))
                    // Lines
                    var left = Path(); left.move(to: CGPoint(x: endZoneDepth, y: 0)); left.addLine(to: CGPoint(x: endZoneDepth, y: h))
                    var right = Path(); right.move(to: CGPoint(x: w - endZoneDepth, y: 0)); right.addLine(to: CGPoint(x: w - endZoneDepth, y: h))
                    var mid = Path(); mid.move(to: CGPoint(x: w / 2, y: 0)); mid.addLine(to: CGPoint(x: w / 2, y: h))
                    context.stroke(left, with: .color(.white.opacity(0.6)), lineWidth: 2)
                    context.stroke(right, with: .color(.white.opacity(0.6)), lineWidth: 2)
                    context.stroke(mid, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                } else {
                    let topEZ = CGRect(x: 0, y: 0, width: w, height: endZoneDepth)
                    let bottomEZ = CGRect(x: 0, y: h - endZoneDepth, width: w, height: endZoneDepth)
                    context.fill(Path(topEZ), with: .color(.green.opacity(0.5)))
                    context.fill(Path(bottomEZ), with: .color(.green.opacity(0.5)))
                    var top = Path(); top.move(to: CGPoint(x: 0, y: endZoneDepth)); top.addLine(to: CGPoint(x: w, y: endZoneDepth))
                    var bottom = Path(); bottom.move(to: CGPoint(x: 0, y: h - endZoneDepth)); bottom.addLine(to: CGPoint(x: w, y: h - endZoneDepth))
                    var mid = Path(); mid.move(to: CGPoint(x: 0, y: h / 2)); mid.addLine(to: CGPoint(x: w, y: h / 2))
                    context.stroke(top, with: .color(.white.opacity(0.6)), lineWidth: 2)
                    context.stroke(bottom, with: .color(.white.opacity(0.6)), lineWidth: 2)
                    context.stroke(mid, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
        }
    }
}

extension Color {
    init(namedColor: String) {
        switch namedColor {
        case "red": self = .red
        case "blue": self = .blue
        case "yellow": self = .yellow
        case "white": self = .white
        case "black": self = .black
        default: self = .white
        }
    }
}
```

**Step 3: Create PlaybookView**

Create `PigeonPlay/Views/Playbook/PlaybookView.swift`:

```swift
import SwiftUI
import SwiftData

struct PlaybookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlay.dateCreated, order: .reverse) private var savedPlays: [SavedPlay]

    @State private var elements: [DrawingElement] = []
    @State private var currentTool: DrawingTool = .pen
    @State private var currentColor: String = "white"
    @State private var isHorizontal: Bool = true
    @State private var showingSaveDialog = false
    @State private var showingPlaybook = false
    @State private var playName = ""

    private let colors = ["white", "red", "blue", "yellow", "black"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FieldCanvasView(
                    elements: $elements,
                    currentTool: $currentTool,
                    currentColor: $currentColor,
                    isHorizontal: isHorizontal
                )

                // Toolbar
                HStack {
                    // Tool picker
                    ForEach([
                        (DrawingTool.pen, "pencil.tip"),
                        (.arrow, "arrow.right"),
                        (.circle, "circle.fill"),
                        (.eraser, "eraser"),
                    ], id: \.1) { tool, icon in
                        Button {
                            currentTool = tool
                        } label: {
                            Image(systemName: icon)
                                .padding(8)
                                .background(currentTool == tool ? Color.accentColor.opacity(0.3) : Color.clear)
                                .cornerRadius(8)
                        }
                    }

                    Divider().frame(height: 24)

                    // Color picker
                    ForEach(colors, id: \.self) { color in
                        Button {
                            currentColor = color
                        } label: {
                            Circle()
                                .fill(Color(namedColor: color))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(currentColor == color ? Color.accentColor : Color.gray, lineWidth: currentColor == color ? 3 : 1)
                                )
                        }
                    }

                    Spacer()

                    Button {
                        elements = []
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Playbook")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Save Play", systemImage: "square.and.arrow.down") {
                            showingSaveDialog = true
                        }
                        Button("Load Play", systemImage: "folder") {
                            showingPlaybook = true
                        }
                        Divider()
                        Button {
                            isHorizontal.toggle()
                        } label: {
                            Label(
                                isHorizontal ? "Vertical Field" : "Horizontal Field",
                                systemImage: isHorizontal ? "rectangle.portrait" : "rectangle.landscape.rotate"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Save Play", isPresented: $showingSaveDialog) {
                TextField("Play name", text: $playName)
                Button("Save") {
                    let play = SavedPlay(name: playName, elements: elements)
                    modelContext.insert(play)
                    playName = ""
                }
                Button("Cancel", role: .cancel) { playName = "" }
            }
            .sheet(isPresented: $showingPlaybook) {
                NavigationStack {
                    List {
                        ForEach(savedPlays) { play in
                            Button(play.name) {
                                elements = play.elements
                                showingPlaybook = false
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(savedPlays[index])
                            }
                        }
                    }
                    .navigationTitle("Saved Plays")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingPlaybook = false }
                        }
                    }
                }
            }
        }
    }
}
```

**Step 4: Wire up ContentView**

Update `PigeonPlay/App/ContentView.swift` to use `PlaybookView()` in the Playbook tab.

**Step 5: Build and verify**

```bash
xcodebuild build -project PigeonPlay.xcodeproj -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add PigeonPlay/Models/SavedPlay.swift PigeonPlay/Views/Playbook/ PigeonPlay/App/ContentView.swift
git commit -m "feat: add Playbook tab with field canvas, drawing tools, and save/load"
```

---

### Task 8: History Tab

**Files:**
- Create: `PigeonPlay/Views/History/HistoryView.swift`
- Create: `PigeonPlay/Views/History/GameDetailView.swift`

**Step 1: Create HistoryView**

Create `PigeonPlay/Views/History/HistoryView.swift`:

```swift
import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<Game> { !$0.isActive },
        sort: \Game.date,
        order: .reverse
    ) private var games: [Game]

    var body: some View {
        NavigationStack {
            List(games) { game in
                NavigationLink(value: game) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("vs \(game.opponent)")
                                .font(.headline)
                            Text(game.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(game.ourScore) - \(game.theirScore)")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(game.ourScore > game.theirScore ? .green : game.ourScore < game.theirScore ? .red : .secondary)
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Game.self) { game in
                GameDetailView(game: game)
            }
        }
    }
}
```

**Step 2: Create GameDetailView**

Create `PigeonPlay/Views/History/GameDetailView.swift`:

```swift
import SwiftUI

struct GameDetailView: View {
    let game: Game

    private var playerStats: [(player: Player, points: Int, goals: Int, assists: Int)] {
        var stats: [PersistentIdentifier: (points: Int, goals: Int, assists: Int)] = [:]
        var playerLookup: [PersistentIdentifier: Player] = [:]

        for point in game.points {
            for pp in point.onFieldPlayers {
                let id = pp.player.persistentModelID
                playerLookup[id] = pp.player
                stats[id, default: (0, 0, 0)].points += 1
            }
            if let scorer = point.scorer {
                let id = scorer.persistentModelID
                playerLookup[id] = scorer
                stats[id, default: (0, 0, 0)].goals += 1
            }
            if let assist = point.assist {
                let id = assist.persistentModelID
                playerLookup[id] = assist
                stats[id, default: (0, 0, 0)].assists += 1
            }
        }

        return stats.map { (playerLookup[$0.key]!, $0.value.points, $0.value.goals, $0.value.assists) }
            .sorted { $0.points > $1.points }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack {
                        Text("\(game.ourScore) - \(game.theirScore)")
                            .font(.largeTitle.bold().monospacedDigit())
                        Text("vs \(game.opponent)")
                        Text(game.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            Section("Player Stats") {
                HStack {
                    Text("Player").bold()
                    Spacer()
                    Text("Pts").bold().frame(width: 40)
                    Text("G").bold().frame(width: 30)
                    Text("A").bold().frame(width: 30)
                }
                .font(.caption)

                ForEach(playerStats, id: \.player.persistentModelID) { stat in
                    HStack {
                        Text(stat.player.name)
                        Spacer()
                        Text("\(stat.points)").frame(width: 40)
                        Text("\(stat.goals)").frame(width: 30)
                        Text("\(stat.assists)").frame(width: 30)
                    }
                    .font(.body.monospacedDigit())
                }
            }
        }
        .navigationTitle("Game Detail")
    }
}
```

**Step 3: Wire up ContentView**

Update `PigeonPlay/App/ContentView.swift` to use `HistoryView()` in the History tab.

**Step 4: Update model container**

Ensure `PigeonPlayApp.swift` model container includes all models: `Player.self, Game.self, GamePoint.self, PointPlayer.self, SavedPlay.self`.

**Step 5: Build and verify**

```bash
xcodebuild build -project PigeonPlay.xcodeproj -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 6: Run all tests**

```bash
xcodebuild test -project PigeonPlay.xcodeproj -scheme PigeonPlayTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: All tests pass

**Step 7: Commit**

```bash
git add PigeonPlay/Views/History/ PigeonPlay/App/ContentView.swift PigeonPlay/App/PigeonPlayApp.swift
git commit -m "feat: add History tab with game list and per-player stats"
```

---

### Task 9: Polish & Final Verification

**Step 1: Run full build**

```bash
xcodebuild build -project PigeonPlay.xcodeproj -scheme PigeonPlay -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

**Step 2: Run all tests**

```bash
xcodebuild test -project PigeonPlay.xcodeproj -scheme PigeonPlayTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

**Step 3: Fix any issues found**

**Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address build/test issues from final verification"
```
