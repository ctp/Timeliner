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
| `Era` | Cross-lane date range (background band) with name, start/end dates, sortOrder |

**Key design decisions:**
- `FlexibleDate` is stored as JSON-encoded `Data` in `TimelineEvent` and `Era` (SwiftData doesn't directly support custom structs)
- `FlexibleDate` timezone convention: day-precision and coarser store raw calendar values (no timezone); time-precision (hour/minute) stores UTC internally. Use `fromLocalTime(...)` to create time-precision dates and `localDisplayComponents` to read them back in local time.
- Relationships: Lane → Events (one-to-many)
- Events without a lane appear in an "Unassigned" section
- Eras are independent overlays — no relationship to lanes or events; rendered as subtle background bands spanning all lanes

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
│   │   ├── LaneListView    # Lane list with selection highlight
│   │   └── EraListView     # Era list with selection highlight
│   └── Detail
│       └── TimelineCanvasView
│           ├── TimeAxisView      # Time ruler with adaptive ticks
│           ├── EraBandView[]     # Background bands behind lanes (ZStack)
│           ├── LaneRowView[]     # One per lane, dynamic height via overlap layout
│           │   └── EventView[]   # Point (dot) or span (bar), with system tooltips
│           ├── .inspector()       # InspectorView (trailing panel, ⌘I) — event detail, lane editor, or era editor
│           ├── Gesture handlers  # Pan and zoom, fit-to-content
│           └── TimelineExporter  # PDF/PNG export (⇧⌘P / ⇧⌘G)
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
│   └── Era.swift
├── Views/
│   ├── TimelineLayoutEngine.swift  # Shared layout types, collision layout, label placement, connection lines
│   ├── TimelineConstants.swift     # Centralized layout constants (row heights, event sizing, etc.)
│   ├── TimelineViewport.swift
│   ├── TimelineCanvasView.swift
│   ├── TimelineExporter.swift      # PDF and PNG export with geometry matching live viewport
│   ├── TimeAxisView.swift
│   ├── EventView.swift
│   ├── LaneRowView.swift
│   ├── EraBandView.swift           # Background band for era/period date ranges
│   ├── EventInspectorView.swift    # Inspector panel: read-only event detail, editable lane/era properties
│   ├── FlexibleDateEditor.swift    # Reusable progressive date fields
│   ├── ScrollWheelOverlay.swift    # NSEvent local monitor for precise scroll/pan handling
│   ├── Color+Hex.swift             # Color↔hex string conversion extension
│   └── Sidebar/
│       ├── LaneListView.swift
│       └── EraListView.swift
├── Scripting/
│   ├── Timeliner.sdef              # AppleScript dictionary definition
│   ├── DocumentRegistry.swift      # Singleton mapping documents to ModelContexts
│   ├── ScriptableDocument.swift    # NSObject wrapper for document scripting
│   ├── ScriptableLane.swift        # NSObject wrapper for Lane scripting
│   ├── ScriptableEvent.swift       # NSObject wrapper for TimelineEvent scripting
│   ├── ScriptableEra.swift         # NSObject wrapper for Era scripting
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

## Current State (v1.2 — AI-Driven UI)

**Editing model:** Timeliner is a visualization-first app. The primary editing interface is Claude Code driving the app via AppleScript (`osascript`). The app UI is for viewing timelines and spatial interactions (dragging events). Event/lane/era creation and property editing are done through AppleScript CRUD commands.

Implemented:
- ✅ Core data model with FlexibleDate precision
- ✅ Document persistence with .timeliner extension
- ✅ Horizontal timeline visualization
- ✅ Stacked lane rows with interval-collision layout (spans pack into the first sub-row with no actual overlap; point events always occupy row 0, spans only bump down on real collisions; lanes expand dynamically)
- ✅ Point events (dots with outline) and span events (bars with outline and tinted lane-color fill)
- ✅ Git-style connection lines: railroad-track graph with 3pt lane-colored lines, S-curve fork/merge connectors (cubic Bézier), gradient fade at viewport edges; shared `ConnectionLinesShape` in `TimelineLayoutEngine`
- ✅ Pan (drag on time axis, or horizontal trackpad/scroll wheel anywhere) and zoom (pinch on time axis) navigation with viewport clamping (max 1 year beyond event bounds); scroll input via `ScrollWheelOverlay` (NSEvent local monitor) with hit-test scoping so vertical lane scrolling and inspector scrolling coexist
- ✅ Fit-to-content viewport scaling (auto-fits on document load via async task, toolbar button, and View menu item with ⌘0)
- ✅ Adaptive time axis (hours → decades) with refined tick spacing thresholds and calendar-anchored label cadence (labels stay stable during resize/scroll)
- ✅ Timezone-aware FlexibleDate (UTC storage for time-precision, local display)
- ✅ Sidebar for lane and era listing (view, reorder, delete); selecting a lane or era highlights it and opens the inspector for inline editing
- ✅ System tooltips on events showing title (replaced hover popovers to avoid click interference)
- ✅ Point event labels: toggled via View > Show Point Labels (⌘L) and toolbar button, with vertical connector lines and tiered stagger layout (up to 4 above tiers, 2 below tiers) to avoid collisions; biased above, lanes expand dynamically; two-pass layout — first assigns tiers via label-to-label collision, then computes horizontal offsets so label text avoids connector lines from higher-tier labels
- ✅ Inspector panel: trailing `.inspector()` panel toggled via toolbar button (info.circle) or ⌘I; shows read-only event details (title, description, lane, dates, copy-to-clipboard) when an event is selected, or editable lane properties (name, color) / era properties (name, start/end dates) when a lane or era is selected from the sidebar; auto-opens on lane/era selection
- ✅ Event dragging: drag point or span events to move them in time; drag left/right edges of spans to resize (change start/end date); 6pt edge hit zones for resize detection; dates snap to event's own precision on commit; minimum duration of one precision unit enforced; global coordinate space for jitter-free dragging; GeometryReader-based edge detection for spans
- ✅ PDF and PNG export: File > Export > Export as PDF (⇧⌘P) or Export as PNG (⇧⌘G); export geometry matches current viewport zoom level; PNG uses @2x rasterization for crisp output; always includes point event labels; light/dark appearance matches current app theme; `TimelineExporter` with self-contained `TimelineExportView` and export-only lane row views (no gesture handlers)
- ✅ AppleScript support (primary editing interface): full CRUD via `osascript` — `make new document`, `make new lane`, `make new timeline event`, `make new era` (all return usable object specifiers for variable storage), `delete`, `count`, `exists`, property get/set, `whose` clause filtering, lane assignment and reassignment, date string comparison. SDEF scripting dictionary, DocumentRegistry bridging SwiftUI DocumentGroup to Cocoa Scripting, NSObject wrappers (ScriptableDocument/Lane/Event/Era) with KVC properties, custom TimelinerCreateCommand handling all object creation, TimelinerDeleteCommand for deletion, FlexibleDate ISO string parsing (`init?(isoString:)` / `.isoString`). **Known limitation:** `save`, `close`, and `open` commands do not work via script due to SwiftUI DocumentGroup dispatching these commands to ScriptableDocument wrappers rather than the underlying NSDocument; the app auto-saves so this is not critical for automation workflows.
- ✅ Lane color picker: `Color+Hex.swift` extension for Color↔hex conversion; lane color editing via inspector panel
- ✅ Eras / Periods: cross-lane date ranges rendered as subtle background bands spanning all lanes; `EraBandView` renders with horizontal fade-in/fade-out at edges and centered name label with background pill; fixed `Color.primary.opacity(0.06)` color (works in light/dark mode); full AppleScript support (`make new era`, `delete era`, property get/set); schema migration v1.0.0 → v1.1.0
- ✅ Centralized layout constants in `TimelineConstants.swift` (baseRowHeight, eventHeight, spanCornerRadius, connectionLineWidth, etc.)

## Future Work (Out of Scope for v1)

These were explicitly deferred but the model accommodates them:

1. **Attachments** - Images, files, links (Attachments/ directory reserved in doc package)
2. **Event Relationships** - Links between events (causal, sequential)
3. **Vertical Orientation** - Alternative timeline layout
4. **Collapsible Lanes** - Expand/collapse for focus
5. **Minimap** - Overview navigation for large timelines
6. **Search** - Find events by title/description
7. ~~**Eras / Periods**~~ - Implemented in v1.1
8. ~~**Export**~~ - PDF and PNG export implemented in v1.2; CSV/JSON import/export still deferred
9. **Keyboard Navigation** - Arrow keys between events, Enter to open inspector, Delete to remove; power-user workflow
10. **Undo/Redo** - SwiftData + UndoManager integration for model mutations (inspector edits, dragging, creation)
11. **Multi-Select & Bulk Operations** - Shift/Cmd-click to select multiple events; bulk move, delete, or lane reassignment

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
- `docs/plans/2026-03-10-ai-driven-ui-design.md` - Design for AI-driven UI model (visualization-first)
- `docs/plans/2026-03-10-ai-driven-ui-implementation.md` - Implementation plan for AI-driven UI

## Git Remote

- Origin: `git@github.com:ctp/Timeliner.git`
- Branch: `main`
