# CLAUDE.md - Timeliner Project Guide

## Project Overview

Timeliner is a macOS Catalyst timeline visualization app built with SwiftUI and SwiftData. Users create `.timeliner` documents containing events organized into lanes (horizontal tracks) and tagged for filtering.

## Tech Stack

- **Swift 6** with strict concurrency
- **SwiftUI** for UI
- **SwiftData** for persistence (document-based via `DocumentGroup`)
- **Swift Testing** framework for unit tests (not XCTest)

## Architecture

### Data Model

| Model | Purpose |
|-------|---------|
| `FlexibleDate` | Variable-precision date (year-only through minute-level) with timezone-aware storage |
| `TimelineEvent` | Main entity with title, description, start/end dates, lane, and tags |
| `Lane` | Visual grouping track (horizontal row) with name, color, sortOrder |
| `Tag` | Cross-cutting labels for filtering events |

**Key design decisions:**
- `FlexibleDate` is stored as JSON-encoded `Data` in `TimelineEvent` (SwiftData doesn't directly support custom structs)
- `FlexibleDate` timezone convention: day-precision and coarser store raw calendar values (no timezone); time-precision (hour/minute) stores UTC internally. Use `fromLocalTime(...)` to create time-precision dates and `localDisplayComponents` to read them back in local time.
- Relationships: Lane → Events (one-to-many), Tag ↔ Events (many-to-many)
- Events without a lane appear in an "Unassigned" section

### Document Structure

Documents use `.timeliner` extension and are packages (folders that appear as single files):
```
MyTimeline.timeliner/
├── default.store          # SwiftData SQLite database
└── (future: Attachments/) # Reserved for media
```

UTType: `com.timeliner.document`

### View Hierarchy

```
ContentView
├── NavigationSplitView
│   ├── Sidebar (List)
│   │   ├── LaneListView    # CRUD for lanes
│   │   └── TagListView     # CRUD for tags with filter toggles
│   └── Detail
│       └── TimelineCanvasView
│           ├── TimeAxisView      # Time ruler with adaptive ticks
│           ├── LaneRowView[]     # One per lane, dynamic height via overlap layout
│           │   └── EventView[]   # Point (dot) or span (bar), with system tooltips
│           ├── .inspector()       # EventInspectorView (trailing panel, ⌘I)
│           └── Gesture handlers  # Pan and zoom, fit-to-content
```

### Coordinate System

`TimelineViewport` manages the mapping between dates and screen positions:
- `centerDate`: Date at viewport center
- `scale`: Seconds per point (higher = more zoomed out)
- `xPosition(for: Date)` / `date(forX: CGFloat)`: Bidirectional conversion

## File Locations

```
Timeliner/
├── Models/
│   ├── FlexibleDate.swift
│   ├── TimelineEvent.swift
│   ├── Lane.swift
│   └── Tag.swift
├── Views/
│   ├── TimelineLayoutEngine.swift  # Shared layout types and functions
│   ├── TimelineViewport.swift
│   ├── TimelineCanvasView.swift
│   ├── TimeAxisView.swift
│   ├── EventView.swift
│   ├── LaneRowView.swift
│   ├── EventInspectorView.swift  # Trailing inspector for editing events
│   ├── FlexibleDateEditor.swift  # Reusable progressive date fields
│   └── Sidebar/
│       ├── LaneListView.swift
│       └── TagListView.swift
├── ContentView.swift
├── TimelinerApp.swift
└── Info.plist
```

## Running Tests

```bash
# All unit tests
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests

# Specific test file
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/FlexibleDateTests
```

**Note:** SourceKit may show false "No such module 'Testing'" errors in the IDE. These are indexing issues—tests compile and run correctly.

## Build Commands

```bash
cd /Users/ctp/Desktop/Local\ Sources/Timeliner

# Build
xcodebuild build -scheme Timeliner -destination 'platform=macOS'

# Run app
open ~/Library/Developer/Xcode/DerivedData/Timeliner-*/Build/Products/Debug/Timeliner.app
```

## Current State (v1 Complete)

Implemented:
- ✅ Core data model with FlexibleDate precision
- ✅ Document persistence with .timeliner extension
- ✅ Horizontal timeline visualization
- ✅ Stacked lane rows with interval-collision layout (spans pack into the first sub-row with no actual overlap; point events always occupy row 0, spans only bump down on real collisions; lanes expand dynamically)
- ✅ Point events (dots with outline) and span events (bars with outline and tinted lane-color fill)
- ✅ Git-style connection lines: railroad-track graph with 3pt lane-colored lines, S-curve fork/merge connectors, gradient fade at viewport edges
- ✅ Pan (drag on time axis, or horizontal trackpad/scroll wheel anywhere) and zoom (pinch on time axis) navigation with viewport clamping (max 1 year beyond event bounds); scroll input via NSEvent local monitor with hit-test scoping so vertical lane scrolling and inspector scrolling coexist; lane area reserved for future event dragging
- ✅ Fit-to-content viewport scaling (auto-fits on document load via async task, toolbar button, and View menu item with ⌘0)
- ✅ Adaptive time axis (hours → decades) with refined tick spacing thresholds and calendar-anchored label cadence (labels stay stable during resize/scroll)
- ✅ Timezone-aware FlexibleDate (UTC storage for time-precision, local display)
- ✅ Sidebar for lane/tag management
- ✅ System tooltips on events showing title (replaced hover popovers to avoid click interference)
- ✅ Point event labels: toggled via View > Show Point Labels (⌘L) and toolbar button, with vertical connector lines and tiered stagger layout (up to 4 above tiers, 2 below tiers) to avoid collisions; biased above, lanes expand dynamically; two-pass layout — first assigns tiers via label-to-label collision, then computes horizontal offsets so label text avoids connector lines from higher-tier labels
- ✅ Sample data generation (idempotent) — 20 events across Work and Personal lanes with overlapping spans, point events, and Important/Milestone tags
- ✅ Point event creation: double-click on lane row to create a point event with zoom-appropriate precision and auto-generated title from date
- ✅ Event inspector panel: trailing `.inspector()` panel toggled via toolbar button (info.circle) or ⌘I; live-edits title, description, start/end dates with segmented precision picker (Year|Month|Day|Time) for FlexibleDate fields; auto-opens on event creation; changing start date shifts end date to preserve duration; end date clamped to at least one day after start; FlexibleDateEditor syncs from external binding changes

## Future Work (Out of Scope for v1)

These were explicitly deferred but the model accommodates them:

1. **Event Editing UI** - Can create and edit events (title, description, dates); no deletion, lane reassignment, or tag editing yet
2. **Attachments** - Images, files, links (Attachments/ directory reserved in doc package)
3. **Event Relationships** - Links between events (causal, sequential)
4. **Vertical Orientation** - Alternative timeline layout
5. **Collapsible Lanes** - Expand/collapse for focus
6. **Minimap** - Overview navigation for large timelines
7. **Tag Filtering** - `activeTagFilters` state exists but isn't wired to filter displayed events
8. **Lane Color Picker** - Currently hardcoded; needs UI for user selection
9. **Search** - Find events by title/description

## Design Documents

- `docs/plans/2026-01-26-timeline-core-design.md` - Approved design spec
- `docs/plans/2026-01-26-timeline-implementation.md` - Implementation plan with 13 tasks
- `docs/plans/2026-02-01-extract-timeline-layout-engine.md` - Plan to extract duplicated layout code into shared TimelineLayoutEngine (completed)
- `docs/plans/2026-02-02-point-event-creation-design.md` - Design for double-click point event creation
- `docs/plans/2026-02-02-point-event-creation.md` - Implementation plan for point event creation (completed)
- `docs/plans/2026-02-02-event-inspector-design.md` - Design for event inspector panel
- `docs/plans/2026-02-02-event-inspector.md` - Implementation plan for event inspector (completed)

## Git Remote

- Origin: `git@github.com:ctp/Timeliner.git`
- Branch: `main`
