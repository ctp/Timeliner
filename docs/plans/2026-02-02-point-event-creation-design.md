# Point Event Creation via Double-Click

**Date**: 2026-02-02
**Status**: Approved
**Scope**: Double-click-to-create point events on lane rows

---

## Overview

Add the ability to create point events by double-clicking on empty space within a lane row. The event is placed at the clicked date with zoom-appropriate precision and an auto-generated title. No upfront form — fast placement, edit later.

## Interaction Flow

1. User double-clicks on empty space within a lane row.
2. The click's x-coordinate is converted to a `Date` via `viewport.date(forX:)`.
3. The `Date` is snapped to a boundary matching the current zoom precision and converted to a `FlexibleDate`.
4. A `TimelineEvent` is created with:
   - `startDate`: the snapped `FlexibleDate`
   - `endDate`: nil (point event)
   - `title`: auto-generated from the date (e.g., "2024", "Jan 2024", "Jan 15, 2024", "Jan 15, 3:00 PM")
   - `lane`: the lane for the clicked row
   - No tags
5. The event is inserted via `modelContext.insert()` — appears immediately via SwiftData reactivity.
6. The new event is selected (`selectedEventID` is set).

## Precision from Zoom Level

The viewport's `scale` (seconds per point) determines `FlexibleDate` precision:

| Scale range (s/pt) | What's visible | DatePrecision | Title example |
|---------------------|----------------|---------------|---------------|
| < 60 | Minutes | `.time` | "Jan 15, 3:42 PM" |
| 60–3,600 | Hours | `.time` | "Jan 15, 3:00 PM" |
| 3,600–86,400 | Parts of days | `.day` | "Jan 15, 2024" |
| 86,400–2,592,000 | Days to weeks | `.day` | "Jan 15, 2024" |
| 2,592,000–31,536,000 | Months | `.month` | "Jan 2024" |
| > 31,536,000 | Years+ | `.year` | "2024" |

The clicked `Date` is snapped to the appropriate boundary for that precision (start of minute, hour, day, month, or year).

For time precision (< 3,600 s/pt), the `FlexibleDate` is created via `fromLocalTime(...)` per the existing UTC storage convention. For day and coarser, raw calendar components are used directly.

## Title Generation

The auto-generated title matches the precision:

| Precision | Format | Example |
|-----------|--------|---------|
| `.year` | "yyyy" | "2024" |
| `.month` | "MMM yyyy" | "Jan 2024" |
| `.day` | "MMM d, yyyy" | "Jan 15, 2024" |
| `.time` | "MMM d, h:mm a" | "Jan 15, 3:00 PM" |

## Files Changed

### `TimelineViewport.swift`

Add two helper methods:

- `currentPrecision() -> DatePrecision` — returns precision based on current `scale` per the table above.
- `snappedDate(from date: Date, precision: DatePrecision) -> Date` — rounds a `Date` to the boundary for the given precision (e.g., start of day, start of month).

### `LaneRowView.swift`

Add a double-click gesture on the lane's geometry. On trigger, call a closure `onCreateEvent(xPosition: CGFloat)` passing the click's x-coordinate.

### `TimelineCanvasView.swift`

Define the `onCreateEvent` handler wired to each `LaneRowView`:

1. Call `viewport.currentPrecision()` to get precision.
2. Convert x to `Date` via `viewport.date(forX:)`.
3. Snap to boundary via `viewport.snappedDate(from:precision:)`.
4. Build `FlexibleDate` from snapped date (using `fromLocalTime` for `.time` precision).
5. Generate title string.
6. Create `TimelineEvent`, insert into `modelContext`.
7. Set `selectedEventID`.

## Design Decisions

- **Double-click (not single-click)**: Avoids accidental creation, leaves single-click available for deselecting or future use. Familiar pattern from calendar apps.
- **No upfront form**: Minimizes friction. Title auto-generates from date. User edits details later (event editing UI is a separate future task).
- **Precision from zoom**: Makes placement feel intentional — you can't accidentally place a minute-precision event when zoomed out to see years.
- **Snap to boundary**: Prevents arbitrary sub-precision placement (e.g., no 2:37 PM event when at hour zoom level).
