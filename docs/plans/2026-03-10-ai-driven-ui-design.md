# AI-Driven UI Model Design

## Overview

Shift Timeliner from a direct-manipulation editing app to a visualization-first app where Claude Code drives edits via AppleScript. The app becomes primarily a viewer/renderer; the existing AppleScript CRUD capabilities become the primary editing interface.

## Decisions

| Surface | Decision |
|---------|----------|
| Inspector panel | Read-only with copy-to-clipboard |
| Event dragging (move/resize) | Keep |
| Double-click event creation | Remove |
| Sidebar (lanes/eras) | Keep as-is |
| Menu event creation (⌘E, ⇧⌘E) | Remove |
| Sample data button | Keep |

## Approach: Surgical Removal

Targeted changes to existing views — no rewrites, no feature flags.

## Section 1: Read-Only Inspector

Replace `EventDetailForm` with a read-only `EventDetailView`:

- **Title** — `Text`, not TextField
- **Description** — `Text` (or "No description" placeholder)
- **Lane** — colored circle + lane name as `Text`
- **Start Date** — formatted text at stored precision
- **End Date** — formatted text (or "Point event" if nil)
- **Copy button** — copies structured summary to clipboard:
  ```
  Title: Project Kickoff
  Lane: Work
  Start: 2026-03-10
  Type: Point event
  Description: Initial planning meeting
  ```
- **"No Selection" text** — update from "Select an event to edit" to "Select an event to view details"

`FlexibleDateEditor` stays in the project (still used by `EraEditorSheet`).

## Section 2: Canvas Interaction Changes

**Remove:**
- `SpatialTapGesture(count: 2)` on `LaneRowView` (double-click creation)
- Associated VoiceOver "Create Event" accessibility action
- `onCreateEvent` callback from `LaneRowView` interface
- `createPointEvent` and `createSpanEvent` state variables from `ContentView`
- `FocusedValueKey` definitions and `focusedSceneValue` wiring for creation
- `createPointEvent(at:in:viewportWidth:)` method from `TimelineCanvasView`
- Creation-related parameters passed through the view hierarchy

**Keep:**
- All drag gestures on `EventView` (move, resize-start, resize-end)
- `commitDrag()` and snapping logic
- Pan and zoom navigation

## Section 3: Menu & Toolbar Changes

**Remove from `TimelinerApp`:**
- File > New Point Event (⌘E)
- File > New Span Event (⇧⌘E)

**Keep:**
- Export as PDF (⇧⌘P) and Export as PNG (⇧⌘G)
- View > Fit to Content (⌘0)
- View > Show Point Labels (⌘L)
- View > Show Inspector (⌘I)
- All toolbar buttons (inspector, labels, fit-to-content, sample data)

No changes to sidebar or its editor sheets.

## Files Affected

| File | Change |
|------|--------|
| `EventInspectorView.swift` | Replace `EventDetailForm` with read-only view + copy button |
| `ContentView.swift` | Remove creation state vars, focused values, creation wiring |
| `TimelineCanvasView.swift` | Remove creation method, remove creation params |
| `LaneRowView.swift` | Remove double-click gesture, remove `onCreateEvent` |
| `TimelinerApp.swift` | Remove creation menu commands |
| `FlexibleDateEditor.swift` | No changes (still used by era editor) |
| `LaneListView.swift` | No changes |
| `EraListView.swift` | No changes |
| `EventView.swift` | No changes (dragging stays) |
