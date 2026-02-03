# Timeliner

A native macOS document-based app for visualizing events on a horizontal timeline. Built with SwiftUI and SwiftData.

## Features

- **Document-based** -- Each timeline is saved as a `.timeliner` file that you can create, open, and share
- **Flexible dates** -- Events support year, month, day, or hour/minute precision, so you can mix "1776" with "June 15, 2024 at 3:00 PM" on the same timeline
- **Point and span events** -- Represent moments as dots or durations as bars
- **Lanes** -- Organize events into horizontal tracks with custom names and colors
- **Pan and zoom** -- Drag or scroll horizontally to pan; pinch to zoom. Fit-to-content with **Cmd+0**
- **Adaptive time axis** -- Tick labels adjust from hours to decades depending on zoom level
- **Drag to move and resize** -- Drag events to reposition them in time; drag the edges of span events to change their start or end date
- **Event inspector** -- Edit title, description, dates, and precision in a sidebar panel (**Cmd+I**)
- **Point event labels** -- Toggle labels on point events with **Cmd+L**; labels auto-stagger to avoid overlaps
- **Connection lines** -- Git-style railroad-track lines connect events within a lane

## Usage

### Creating events

- **Double-click** on a lane to create a point event at that position
- **Cmd+E** to create a point event at the viewport center
- **Shift+Cmd+E** to create a span event at the viewport center

New events are placed at a precision that matches the current zoom level. The inspector panel opens automatically so you can edit the title and dates.

### Navigating

- **Drag** the time axis to pan
- **Scroll horizontally** (trackpad or scroll wheel) anywhere to pan
- **Pinch** on the time axis to zoom
- **Cmd+0** to fit all events in view

### Editing events

Select an event and open the inspector (**Cmd+I**) to edit its title, description, start/end dates, and date precision. Drag events directly on the timeline to reposition them. Drag the left or right edge of a span event to resize it.

### Organizing

Use the sidebar to create and manage lanes. Events without a lane appear in an "Unassigned" section at the bottom.

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

`FlexibleDate` is stored as JSON-encoded `Data` inside `TimelineEvent` since SwiftData doesn't natively support custom value types. Day-precision and coarser dates store raw calendar values; time-precision dates store UTC internally and convert to local time for display.

### Document format

`.timeliner` files are document packages:

```
MyTimeline.timeliner/
  default.store     # SwiftData SQLite database
```

### Coordinate system

`TimelineViewport` maps between dates and screen x-positions:

- `centerDate` -- the date at the center of the viewport
- `scale` -- seconds per point (higher values = more zoomed out)
- `xPosition(for:)` / `date(forX:)` -- bidirectional conversion

### Layout

Events within a lane are packed into sub-rows using an interval-collision algorithm. Point events always go in row 0; spans are placed in the first sub-row without overlap. Lanes expand vertically to fit. Point event labels use a tiered stagger layout (up to 4 tiers above, 2 below) with a second pass to offset labels away from crossing connector lines.
