# Pigeon Play - Design Document

An iOS app for managing an elementary school ultimate frisbee team during games.

## Problem

Coaching a large elementary ultimate roster during games requires:
- Tracking who's on the team
- Ensuring every kid gets roughly equal playing time
- Respecting gender ratio rules on the field (2B-side/3G-side or 3B-side/2G-side)
- Drawing up plays to show kids on a field diagram

## Data Model

### Player
- Name (required)
- Gender: B, G, or X (required)
- Default matching: Bx or Gx (required for X players only)
- Parent name (optional)
- Parent phone (optional)
- Parent email (optional)

### Game
- Date
- Opponent name
- List of points

### Point
- Point number
- 5 players on field, each with their effective gender for that point (B/Bx/G/Gx)
- Ratio used (2B-side/3G-side or 3B-side/2G-side)
- Outcome: us or them
- Scorer (if us) - which player scored
- Assist (if us, optional) - which player assisted

### Play (saved)
- Name
- Drawing data (strokes, arrows, circles)
- Date created

## Tech Stack

- SwiftUI (UI framework)
- SwiftData (persistence)
- No backend, local storage only
- iOS only

## Screens & Navigation

Four-tab layout:

### 1. Roster Tab
- List of all players, grouped by gender (B / G / X)
- Tap player to edit details
- "Add Player" button
- Swipe to delete

### 2. Game Tab (main game-day screen)
- "New Game" button when no game is active
- During a game:
  - Score display at top (Us vs Them)
  - Current point number
  - Ratio picker (2B-side/3G-side or 3B-side/2G-side), defaults to alternating
  - Suggested line: player cards showing name, gender, points played so far
  - X players show a toggle to flip Bx/Gx for this point
  - Swap players by tapping bench/field players
  - "Lock In" to confirm the line
  - After the point: "Us" / "Them" buttons
    - "Us" prompts for scorer and optional assist
- "End Game" to finish early if needed

### 3. Playbook Tab
- Whiteboard view with an ultimate field as the backdrop (end zones, brick marks, sidelines)
- Drawing tools:
  - Freehand pen (finger drawing) with color picker (preset colors)
  - Arrow tool: tap start and end point, draws an arrow
  - Circle/dot tool: for marking player positions
  - Eraser
  - Undo/redo
  - Clear all
- Save/load:
  - "Save Play" button: name the play, saves to playbook
  - Playbook list: browse saved plays, tap to load onto whiteboard
  - Delete saved plays
- Field orientation toggleable (horizontal/vertical)

### 4. History Tab
- List of past games (date, opponent, final score)
- Tap a game to see per-player stats: points played, goals, assists

## Auto-Suggest Algorithm

1. Sort all players by points played this game (ascending, fewest first)
2. Fill slots respecting the chosen ratio:
   - For the B-side slots: pick B players + X players defaulting to Bx, sorted by fewest points played
   - For the G-side slots: pick G players + X players defaulting to Gx, sorted by fewest points played
3. Tie-breaking: if players have equal points played, prefer whoever has sat out the longest (most consecutive points on bench)

## Game Flow

1. Start game: enter opponent name, app loads roster
2. Before each point:
   - Choose ratio (defaults to alternating from previous point)
   - App suggests a line of 5 using the algorithm above
   - Adjust X player assignments if needed
   - Swap players in/out manually if needed (app warns if ratio breaks)
   - Confirm the line
3. Play the point
4. Record outcome:
   - "Them" - just record the score
   - "Us" - tap scorer, optionally tap assister, record the score
5. Repeat until someone reaches 10
6. Game summary: per-player stats, final score

## Games

- Games are played to 10 (max 21 points if alternating scores)
- Substitutions happen between points
- The team on offense chooses the gender ratio for the point
