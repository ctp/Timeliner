# Timeliner

A native macOS document-based app for visualizing events on a horizontal timeline. Built with SwiftUI and SwiftData.

Timeliner is a **visualization-first** app. The primary way to create and edit timeline data is through AppleScript automation (ideal for AI-assisted workflows via Claude Code or similar tools). The app UI focuses on viewing, navigating, and spatially interacting with timelines.

## Features

- **Document-based** — Each timeline is saved as a `.timeliner` file that you can create, open, and share
- **Flexible dates** — Events support year, month, day, or hour/minute precision, so you can mix "1776" with "June 15, 2024 at 3:00 PM" on the same timeline
- **Point and span events** — Represent moments as dots or durations as bars
- **Lanes** — Organize events into horizontal tracks with custom names and colors
- **Eras** — Mark date ranges as named background bands that span all lanes (e.g. "Q1", "Vacation")
- **Pan and zoom** — Drag or scroll horizontally to pan; pinch to zoom. Fit-to-content with **Cmd+0**
- **Adaptive time axis** — Tick labels adjust from hours to decades depending on zoom level
- **Drag to move and resize** — Drag events to reposition them in time; drag the edges of span events to change their start or end date
- **Inspector panel** — View event details (read-only) or edit lane/era properties inline in a sidebar panel (**Cmd+I**); auto-opens when selecting a lane or era
- **Point event labels** — Toggle labels on point events with **Cmd+L**; labels auto-stagger to avoid overlaps
- **Connection lines** — Git-style railroad-track lines connect events within a lane
- **Export** — Export the timeline as a PDF or PNG via **File > Export** (**Shift+Cmd+P** / **Shift+Cmd+G**)
- **AppleScript** — Full automation support for creating, querying, and modifying events, lanes, and eras

## Usage

### Creating and editing data

Events, lanes, and eras are created and modified via AppleScript. This makes Timeliner well-suited for AI-driven workflows where an assistant (e.g. Claude Code) populates timelines programmatically.

Lanes and eras can be viewed, reordered, and deleted from the sidebar. Click a lane or era to edit its properties in the inspector panel.

### Navigating

- **Drag** the time axis to pan
- **Scroll horizontally** (trackpad or scroll wheel) anywhere to pan
- **Pinch** on the time axis to zoom
- **Cmd+0** to fit all events in view

### Interacting with events

- **Drag** events to reposition them in time
- **Drag** the left or right edge of a span event to resize it
- **Cmd+I** to open the inspector and view event details
- **Hover** over an event to see its title in a tooltip

### Organizing

Use the sidebar to view, reorder, and delete lanes and eras. Click a lane or era to open the inspector panel where you can edit its properties (name, color, dates). Events without a lane appear in an "Unassigned" section at the bottom.

### Exporting

Use **File > Export > Export as PDF…** (**Shift+Cmd+P**) or **Export as PNG…** (**Shift+Cmd+G**) to save the full timeline as a static image. The export matches the current viewport zoom level and always includes point event labels. The color scheme (light or dark) matches the app's current appearance.

### AppleScript

Timeliner's primary data editing interface is AppleScript. You aren't expected to write AppleScript yourself — instead, an AI coding agent like Claude Code or Gemini CLI drives the app on your behalf using natural language. You describe what you want ("add a lane called Work with three events in June") and the agent translates that into the appropriate AppleScript commands.

Full CRUD support for documents, lanes, events, and eras:

```applescript
tell application "Timeliner"
    set doc to make new document
    set myLane to make new lane in doc with properties {name:"Work", color:"#3498DB"}
    make new timeline event in doc with properties {
        title:"Project Kickoff",
        start date:"2024-06-01",
        assigned lane:myLane
    }
    make new era in doc with properties {
        name:"Sprint 1",
        start date:"2024-06-01",
        end date:"2024-06-14"
    }
end tell
```

Supported operations: `make`, `delete`, `count`, `exists`, property get/set, `whose` clause filtering, lane assignment and reassignment.

## Building

Requires Xcode and macOS. Open the project in Xcode and build, or from the command line:

```bash
xcodebuild build -scheme Timeliner -destination 'platform=macOS'
```

### Running tests

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests
```

## Technical Overview

### Stack

- **Swift 6** with strict concurrency
- **SwiftUI** for the entire UI layer
- **SwiftData** for persistence via `DocumentGroup`
- **Swift Testing** for unit tests

### Data model

| Model | Role |
|-------|------|
| `FlexibleDate` | Variable-precision date (year through minute) with timezone-aware storage |
| `TimelineEvent` | Title, description, start/end `FlexibleDate`, and lane |
| `Lane` | Named horizontal track with color and sort order |
| `Era` | Named date range rendered as a background band across all lanes |

`FlexibleDate` is stored as JSON-encoded `Data` inside `TimelineEvent` and `Era` since SwiftData doesn't natively support custom value types. Day-precision and coarser dates store raw calendar values; time-precision dates store UTC internally and convert to local time for display.

### Document format

`.timeliner` files are document packages:

```
MyTimeline.timeliner/
  default.store     # SwiftData SQLite database
```

The schema is versioned. The current version is 1.1.0, which added `Era` support via a lightweight migration from 1.0.0.

### Coordinate system

`TimelineViewport` maps between dates and screen x-positions:

- `centerDate` — the date at the center of the viewport
- `scale` — seconds per point (higher values = more zoomed out)
- `xPosition(for:)` / `date(forX:)` — bidirectional conversion

### Layout

Events within a lane are packed into sub-rows using an interval-collision algorithm (`TimelineLayoutEngine`). Point events always go in row 0; spans are placed in the first sub-row without overlap. Lanes expand vertically to fit. Point event labels use a tiered stagger layout (up to 4 tiers above, 2 below) with a second pass to offset labels away from crossing connector lines. Layout constants are centralized in `TimelineConstants`.
