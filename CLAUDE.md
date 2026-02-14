# CLAUDE.md - Timeliner Project Guide

## Project Overview

Timeliner is a macOS Catalyst timeline visualization app built with SwiftUI and SwiftData. Users create `.timeliner` documents containing events organized into lanes (horizontal tracks).

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
| `TimelineEvent` | Main entity with title, description, start/end dates, and lane |
| `Lane` | Visual grouping track (horizontal row) with name, color, sortOrder |

**Key design decisions:**
- `FlexibleDate` is stored as JSON-encoded `Data` in `TimelineEvent` (SwiftData doesn't directly support custom structs)
- `FlexibleDate` timezone convention: day-precision and coarser store raw calendar values (no timezone); time-precision (hour/minute) stores UTC internally. Use `fromLocalTime(...)` to create time-precision dates and `localDisplayComponents` to read them back in local time.
- Relationships: Lane → Events (one-to-many)
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
│   │   └── LaneListView    # CRUD for lanes
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
│   └── Lane.swift
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
│       └── LaneListView.swift
├── Scripting/
│   ├── Timeliner.sdef              # AppleScript dictionary definition
│   ├── DocumentRegistry.swift      # Singleton mapping documents to ModelContexts
│   ├── ScriptableDocument.swift    # NSObject wrapper for document scripting
│   ├── ScriptableLane.swift        # NSObject wrapper for Lane scripting
│   ├── ScriptableEvent.swift       # NSObject wrapper for TimelineEvent scripting
│   ├── CreateDocumentCommand.swift # Custom NSCreateCommand for make/lane/event creation
│   ├── TimelinerDeleteCommand.swift # Custom delete handler
│   └── NSApplication+Scripting.swift  # KVC entry point for scriptableDocuments
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
- ✅ Sidebar for lane management
- ✅ System tooltips on events showing title (replaced hover popovers to avoid click interference)
- ✅ Point event labels: toggled via View > Show Point Labels (⌘L) and toolbar button, with vertical connector lines and tiered stagger layout (up to 4 above tiers, 2 below tiers) to avoid collisions; biased above, lanes expand dynamically; two-pass layout — first assigns tiers via label-to-label collision, then computes horizontal offsets so label text avoids connector lines from higher-tier labels
- ✅ Sample data generation (idempotent) — 20 events across Work and Personal lanes with overlapping spans and point events
- ✅ Point event creation: double-click on lane row to create a point event with zoom-appropriate precision and auto-generated title from date
- ✅ Event inspector panel: trailing `.inspector()` panel toggled via toolbar button (info.circle) or ⌘I; live-edits title, description, start/end dates with segmented precision picker (Year|Month|Day|Time) for FlexibleDate fields; lane reassignment via Picker (with colored circles); delete button with confirmation dialog; auto-opens on event creation; changing start date shifts end date to preserve duration; end date clamped to at least one day after start; FlexibleDateEditor syncs from external binding changes
- ✅ Menu event creation: File > New Point Event (⌘E) and New Span Event (⇧⌘E); places at viewport center, uses selected event's lane (fallback to first lane); span default durations vary by precision (time: +4h, day: +7d, month: +3mo, year: +5yr); auto-selects and opens inspector
- ✅ Event dragging: drag point or span events to move them in time; drag left/right edges of spans to resize (change start/end date); 6pt edge hit zones for resize detection; dates snap to event's own precision on commit; minimum duration of one precision unit enforced; global coordinate space for jitter-free dragging; GeometryReader-based edge detection for spans
- ✅ AppleScript support: full CRUD via `osascript` — `make new document`, `make new lane`, `make new timeline event` (all return usable object specifiers for variable storage), `delete`, `count`, `exists`, property get/set, `whose` clause filtering, lane assignment and reassignment, date string comparison. SDEF scripting dictionary, DocumentRegistry bridging SwiftUI DocumentGroup to Cocoa Scripting, NSObject wrappers (ScriptableDocument/Lane/Event) with KVC properties, custom TimelinerCreateCommand handling all object creation, TimelinerDeleteCommand for deletion, FlexibleDate ISO string parsing (`init?(isoString:)` / `.isoString`). **Known limitation:** `save`, `close`, and `open` commands do not work via script due to SwiftUI DocumentGroup dispatching these commands to ScriptableDocument wrappers rather than the underlying NSDocument; the app auto-saves so this is not critical for automation workflows.
- ✅ Lane color picker: click a lane in the sidebar to open an editor sheet with name and ColorPicker; new-lane flow also includes a ColorPicker instead of hardcoded blue; `Color.toHex()` extension for Color↔hex conversion; sheet presented on List (not inside List cells) to avoid SwiftUI re-presentation bugs

## Future Work (Out of Scope for v1)

These were explicitly deferred but the model accommodates them:

1. **Attachments** - Images, files, links (Attachments/ directory reserved in doc package)
2. **Event Relationships** - Links between events (causal, sequential)
3. **Vertical Orientation** - Alternative timeline layout
4. **Collapsible Lanes** - Expand/collapse for focus
5. **Minimap** - Overview navigation for large timelines
6. **Search** - Find events by title/description
7. **Eras / Periods** - Cross-lane date ranges that span all lanes (e.g. "Renaissance", "Q3 2025"); rendered as a background band or overlay across the full timeline height, distinct from per-lane events

## Design Documents

- `docs/plans/2026-01-26-timeline-core-design.md` - Approved design spec
- `docs/plans/2026-01-26-timeline-implementation.md` - Implementation plan with 13 tasks
- `docs/plans/2026-02-01-extract-timeline-layout-engine.md` - Plan to extract duplicated layout code into shared TimelineLayoutEngine (completed)
- `docs/plans/2026-02-02-point-event-creation-design.md` - Design for double-click point event creation
- `docs/plans/2026-02-02-point-event-creation.md` - Implementation plan for point event creation (completed)
- `docs/plans/2026-02-02-event-inspector-design.md` - Design for event inspector panel
- `docs/plans/2026-02-02-event-inspector.md` - Implementation plan for event inspector (completed)
- `docs/plans/2026-02-02-event-dragging-design.md` - Design for event dragging (move and resize)
- `docs/plans/2026-02-13-applescript-support-design.md` - Design for AppleScript automation support

## Git Remote

- Origin: `git@github.com:ctp/Timeliner.git`
- Branch: `main`
