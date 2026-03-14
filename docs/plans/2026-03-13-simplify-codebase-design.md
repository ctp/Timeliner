# Simplify Timeliner Codebase — Design Spec

**Date:** 2026-03-13
**Goal:** Reduce duplication and remove unused code while preserving all functionality.

## Section 1: Extract Label Padding Computation

The same 10-line block computing label tier padding appears in 5 locations:
- `LaneRowView.body`
- `TimelineCanvasView.unassignedLaneView`
- `TimelineExporter.laneRowHeight`
- `TimelineExporter.ExportLaneRowView.body`
- `TimelineExporter.ExportUnassignedRowView.body`

(The last two are deleted by Section 2, but the extraction must land first.)

**Change:** Add to `TimelineLayoutEngine.swift`:

```swift
struct LabelPadding {
    let top: CGFloat
    let bottom: CGFloat
}

func computeLabelPadding(positions: [UUID: LabelPosition]) -> LabelPadding
```

All call sites collapse to `let padding = computeLabelPadding(positions: labelPositions)`.

## Section 2: Consolidate Export Lane Views

`ExportLaneRowView` (~80 lines) and `ExportUnassignedRowView` (~72 lines) in `TimelineExporter.swift` are near-copies of `LaneRowView` and `TimelineCanvasView.unassignedLaneView` with interaction callbacks removed.

**Changes:**

1. **Make `LaneRowView` callbacks optional** — `onSelectEvent` becomes optional with a `nil` default (`onDragEnd` is already optional). When `nil`, the `EventView` receives an empty `onSelect: {}` closure — `EventView.onSelect` stays non-optional. `selectedEventID` defaults to `nil`. Extra modifiers (`.contentShape`, `.accessibilityElement`) are inert in export rendering and are retained. Export code passes no callbacks.

2. **Extract `UnassignedLaneRowView`** — Pull `TimelineCanvasView.unassignedLaneView` (inline method, ~70 lines) into a standalone `UnassignedLaneRowView` struct in its own file under `Views/`. It accepts the same optional callbacks pattern as `LaneRowView`, plus an explicit `events: [TimelineEvent]` parameter (since unassigned events have no lane). The `sidebarSelection = nil` side effect currently in `unassignedLaneView` gets folded into the `onSelectEvent` closure at the call site in `TimelineCanvasView`.

3. **Delete from `TimelineExporter.swift`:**
   - `ExportLaneRowView` struct
   - `ExportUnassignedRowView` struct
   - `laneRowHeight` helper (becomes a small helper in `TimelineLayoutEngine` or inlined — it's 4 lines after `computeLabelPadding` extraction)

4. **Update `TimelineExportView`** to use `LaneRowView` and `UnassignedLaneRowView` directly (no callbacks).

5. **Xcode project file** — add `UnassignedLaneRowView.swift` to the build target.

**Net effect:** ~150 lines removed, single source of truth for lane rendering.

## Section 3: Remove Unused Code

| Item | Location | Reason |
|------|----------|--------|
| `defaultBaseRowHeight` | `TimelineLayoutEngine.swift:55` | Defined but never referenced |
| `titleForDate(_:precision:)` | `TimelineViewport.swift:100-114` | Never called in production code |
| `titleForDate` tests only | `TimelineViewportTests.swift` (4 tests, not the whole file) | Tests for dead code |
| `TimelinerTests.swift` | `TimelinerTests/` | Xcode placeholder with empty `example()` test |
| `TimelinerUITests/` directory | `TimelinerUITests/` | Two files of Xcode boilerplate with no real assertions |
| `TimelinerUITests` target | Xcode project `.pbxproj` | Remove target and file references for deleted UI tests |

## Out of Scope

- Splitting `EventView` into `PointEventView`/`SpanEventView` (not requested)
- Decomposing `ContentView` or `TimelineCanvasView` (not requested)
- Adding test coverage (separate effort)
- Any changes to the AppleScript scripting layer
