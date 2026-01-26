# Timeliner Core Design

**Date**: 2026-01-26
**Status**: Approved
**Scope**: Data model, document persistence, UI display layer (v1)

---

## Overview

Timeliner is a multiplatform (Catalyst) timeline visualization app using SwiftUI and SwiftData. Users create timeline documents containing events organized into lanes and tagged for filtering.

### Design Principles

- **Flexible**: supports historical dates ("1776") to precise datetimes
- **Visual**: horizontal timeline with stacked lane rows
- **Lean v1**: text-only events, no attachments or relationships yet — model designed for future extension

---

## Data Model

### TimelineEvent

The central entity representing something that happened (or will happen).

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary identifier |
| `title` | `String` | Required, displayed on timeline |
| `eventDescription` | `String?` | Optional detail text |
| `startDate` | `FlexibleDate` | Required |
| `endDate` | `FlexibleDate?` | Nil = point-in-time event |
| `lane` | `Lane?` | Optional lane assignment |
| `tags` | `[Tag]` | Many-to-many relationship |
| `createdAt` | `Date` | Metadata |
| `modifiedAt` | `Date` | Metadata |

### Lane

Visual grouping track displayed as a horizontal row.

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary identifier |
| `name` | `String` | Display name |
| `color` | `String` | Hex or named color |
| `sortOrder` | `Int` | For lane arrangement |
| `events` | `[TimelineEvent]` | Inverse relationship |

### Tag

Cross-cutting labels for filtering.

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary identifier |
| `name` | `String` | Display name |
| `color` | `String?` | Optional color |
| `events` | `[TimelineEvent]` | Inverse relationship |

### FlexibleDate

Variable-precision timestamp supporting year-only through full datetime.

| Property | Type | Notes |
|----------|------|-------|
| `year` | `Int` | Required |
| `month` | `Int?` | Nil = year-only precision |
| `day` | `Int?` | Nil = month precision |
| `time` | `DateComponents?` | Hour/minute/second; nil = day precision |

**Computed properties**:
- `precision: DatePrecision` — enum: `.year`, `.month`, `.day`, `.time`
- `asDate: Date` — for sorting and positioning

---

## Document Persistence

### Package Structure

Documents use the `.timeliner` extension and are packages (appear as single files in Finder):

```
MyTimeline.timeliner/
├── Info.plist          # Document metadata (version, created date)
├── timeline.store      # SwiftData SQLite database
├── timeline.store-shm  # SQLite shared memory (auto-managed)
├── timeline.store-wal  # SQLite write-ahead log (auto-managed)
└── Attachments/        # Reserved for future media (empty for v1)
```

### UTType Registration

| Property | Value |
|----------|-------|
| Identifier | `com.yourcompany.timeliner-document` |
| Extension | `.timeliner` |
| Conforms to | `com.apple.package` |

### SwiftData Configuration

- `ModelContainer` configured per-document via `DocumentGroup`
- Schema includes: `TimelineEvent`, `Lane`, `Tag`
- `FlexibleDate` embedded as struct or coded property
- Versioned schema via `TimelinerVersionedSchema` with migration plan
- Built-in undo/redo via `ModelContext.undoManager`
- Autosave handled by `DocumentGroup`

---

## UI Display Layer

### View Hierarchy

```
ContentView
├── NavigationSplitView
│   ├── Sidebar
│   │   ├── LaneListView        # List of lanes with add/edit/reorder
│   │   └── TagListView         # Collapsible section, filter toggles
│   │
│   └── Detail
│       └── TimelineCanvasView  # Main visualization
│           ├── TimeAxisView    # Ruler showing dates at top
│           ├── LanesContainerView
│           │   └── LaneRowView # One per lane
│           │       └── EventView
│           └── GestureLayer    # Pan + zoom handling
```

### Key Components

#### TimelineCanvasView

The core visualization container.

**State**:
- `visibleRange: ClosedRange<Date>` — currently visible time window
- `scale: TimeInterval` — seconds per point (zoom level)

**Responsibilities**:
- Coordinate pan/zoom gestures
- Pass viewport info to children for positioning

#### TimeAxisView

The time ruler at the top of the timeline.

- Renders tick marks and labels based on zoom level
- Adapts granularity automatically: decades → years → months → days → hours

#### LaneRowView

One horizontal track per lane.

- Fixed height
- Horizontally scrollable with the canvas
- Positions `EventView` children based on event dates

#### EventView

Individual event display.

- **Point events**: marker/dot at position
- **Span events**: horizontal bar from start to end
- Shows title; selection reveals detail in inspector or popover

### Interaction Model

| Action | Behavior |
|--------|----------|
| Pan | Drag to scroll through time |
| Zoom | Pinch (trackpad/touch) or scroll-wheel + modifier |
| Select | Tap/click event for selection |
| Filter | Toggle tags in sidebar to show/hide events |

---

## Future Considerations (Out of Scope for v1)

These are explicitly deferred but the model accommodates them:

- **Attachments**: images, files, links (Attachments/ directory reserved)
- **Event relationships**: links between events (causal, sequential)
- **Vertical orientation**: alternative timeline layout
- **Collapsible lanes**: expand/collapse for focus
- **Minimap**: overview navigation for large timelines

---

## Next Steps

1. Implement data model (`TimelineEvent`, `Lane`, `Tag`, `FlexibleDate`)
2. Configure document package and UTType registration
3. Build `TimelineCanvasView` and child components
4. Wire up sidebar for lane/tag management
5. Add selection and detail editing
