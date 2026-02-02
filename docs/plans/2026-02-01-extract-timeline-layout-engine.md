# Extract Timeline Layout Engine

**Goal:** Eliminate duplicated layout computation code between `TimelineCanvasView.swift` and `LaneRowView.swift` by extracting shared types and functions into a dedicated `TimelineLayoutEngine.swift` utility file.

**Motivation:** Seven items are duplicated nearly verbatim between the two view files: `layoutEvents()`, three structs (`LineSegment`, `ForkMerge`, `ConnectionLines`), `eventXRange(for:viewport:)`, `computeLabelPositions()`, and `computeConnectionLines()`. This duplication creates a maintenance burden — any layout bug fix or enhancement must be applied in two places. Extracting these into a single source of truth makes the codebase more maintainable and testable.

---

## What Moves to the New File

### New file: `Timeliner/Views/TimelineLayoutEngine.swift`

All extracted items become internal (not private) free functions and top-level structs so both views can call them. The `LabelPosition` enum already lives at file scope in `TimelineCanvasView.swift` and is accessible to `LaneRowView`; it moves to the new file as the canonical location.

#### Types to extract

| Type | Current locations | Notes |
|------|------------------|-------|
| `LabelPosition` (enum) | `TimelineCanvasView.swift` lines 9-34 (file-scope) | Move as-is. Already non-private. |
| `LineSegment` (struct) | Both files (private struct) | Make internal. |
| `ForkMerge` (struct) | Both files (private struct) | Make internal. |
| `ConnectionLines` (struct) | Both files (private struct) | Make internal. |

#### Functions to extract

All become internal free functions. Every function takes `viewport: TimelineViewport` as an explicit parameter (reconciling LaneRowView's pattern of capturing `self.viewport`).

| Function | Signature in new file | Notes |
|----------|----------------------|-------|
| `layoutEvents` | `func layoutEvents(_ events: [TimelineEvent], viewport: TimelineViewport) -> (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int)` | Identical logic from both files. |
| `eventXRange` | `func eventXRange(for event: TimelineEvent, viewport: TimelineViewport) -> (startX: CGFloat, endX: CGFloat)` | TimelineCanvasView already takes viewport param; LaneRowView version adapted to match. |
| `computeLabelPositions` | `func computeLabelPositions(layout: (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int), viewport: TimelineViewport) -> (positions: [UUID: LabelPosition], offsets: [UUID: CGFloat])` | TimelineCanvasView already takes both params; LaneRowView version adapted to add viewport param. |
| `computeConnectionLines` | `func computeConnectionLines(layout: [(event: TimelineEvent, subRow: Int)], viewport: TimelineViewport, baseRowHeight: CGFloat, yOffset: CGFloat = 0) -> ConnectionLines` | TimelineCanvasView already takes all params; LaneRowView version adapted to add viewport and baseRowHeight params. Inlines the `yCenter` math. |

#### Constants to extract

| Constant | Value | Notes |
|----------|-------|-------|
| `let defaultBaseRowHeight: CGFloat = 40` | Currently `baseRowHeight` in both views | Both views define `baseRowHeight: CGFloat = 40`. Extract as a module-level constant. |

### What Stays in Each View

**TimelineCanvasView.swift:**
- All `@Query`, `@State`, `@Binding` properties
- `body`, `unassignedLaneView(width:)` — view code
- `viewportWithWidth(_:)`, `eventsWithoutLane`, `eventDateBounds`, `clampViewport()`, `fitViewportToContent(width:)`, `panGesture(width:)`, `magnificationGesture`
- Calls to extracted functions replace the private implementations

**LaneRowView.swift:**
- All stored properties (`lane`, `viewport`, `showPointLabels`, etc.)
- `body` — view code
- `laneStrokeColor`, `laneBackgroundColor` — lane-specific color helpers
- `eventLayout` computed property rewired to call the extracted `layoutEvents()`
- Calls to extracted functions replace the private implementations

### Connection Line Path Drawing

The `Path { ... }` block that draws tracks and S-curve connectors is duplicated in both views (TimelineCanvasView lines 160-199, LaneRowView lines 45-88). Extract a reusable `ConnectionLinesShape`:

```swift
struct ConnectionLinesShape: Shape {
    let lines: ConnectionLines

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for segment in lines.tracks {
            path.move(to: segment.from)
            path.addLine(to: segment.to)
        }
        for fm in lines.forkMerges {
            let dy = abs(fm.subRowY - fm.row0Y)
            let spread = min(40, dy)
            if fm.isFork {
                path.move(to: CGPoint(x: fm.x - spread, y: fm.row0Y))
                path.addCurve(
                    to: CGPoint(x: fm.x, y: fm.subRowY),
                    control1: CGPoint(x: fm.x, y: fm.row0Y),
                    control2: CGPoint(x: fm.x - spread, y: fm.subRowY)
                )
            } else {
                path.move(to: CGPoint(x: fm.x, y: fm.subRowY))
                path.addCurve(
                    to: CGPoint(x: fm.x + spread, y: fm.row0Y),
                    control1: CGPoint(x: fm.x + spread, y: fm.subRowY),
                    control2: CGPoint(x: fm.x, y: fm.row0Y)
                )
            }
        }
        return path
    }
}
```

Both views then replace their inline `Path { ... }` blocks with:

```swift
ConnectionLinesShape(lines: lines)
    .stroke(strokeColor, lineWidth: 3)
    .mask(
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.15),
                .init(color: .black, location: 0.85),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    )
```

---

## Step-by-Step Implementation

### Step 1: Create `TimelineLayoutEngine.swift` with types

Create `Timeliner/Views/TimelineLayoutEngine.swift` containing:
- `import SwiftUI`
- `LabelPosition` enum (from `TimelineCanvasView.swift` lines 9-34)
- `struct LineSegment`, `struct ForkMerge`, `struct ConnectionLines` (internal)
- `let defaultBaseRowHeight: CGFloat = 40`
- `ConnectionLinesShape: Shape`

**Verify:** Build succeeds. No behavior change.

### Step 2: Extract `eventXRange(for:viewport:)`

Move to engine as free function. Delete private versions from both views.

**Verify:** Build succeeds.

### Step 3: Extract `layoutEvents(_:viewport:)`

Move to engine. Delete private versions from both views. Inner helpers (`eventXInterval`, `collides`) remain as nested functions within the extracted function.

**Verify:** Build succeeds.

### Step 4: Extract `computeLabelPositions(layout:viewport:)`

Move to engine. Use TimelineCanvasView version (already takes viewport param). Delete from both views. Update LaneRowView call to pass `viewport:`.

**Verify:** Build succeeds. Point labels render correctly.

### Step 5: Extract `computeConnectionLines(layout:viewport:baseRowHeight:yOffset:)`

Move to engine. Delete from both views. Delete `yCenter` helper from LaneRowView. Update LaneRowView call to pass `viewport:` and `baseRowHeight:`.

**Verify:** Build succeeds. Connection lines render correctly.

### Step 6: Remove `LabelPosition` from `TimelineCanvasView.swift`

Delete lines 9-34. Now lives in engine file.

**Verify:** Build succeeds.

### Step 7: Delete private structs from both views

Remove `LineSegment`, `ForkMerge`, `ConnectionLines` from both files.

**Verify:** Build succeeds.

### Step 8: Replace inline `Path` blocks with `ConnectionLinesShape`

In both views, replace the `Path { path in ... }` connection-line blocks with `ConnectionLinesShape(lines: lines)` plus `.stroke()` and `.mask()`.

**Verify:** Build succeeds. Connection lines render identically.

### Step 9: Final verification

1. `xcodebuild build -scheme Timeliner -destination 'platform=macOS'` — clean build.
2. `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests` — all tests pass.
3. Manual visual check: lanes, unassigned lane, labels, connection lines, pan/zoom, fit-to-content all work.

---

## Summary of File Changes

| File | Action |
|------|--------|
| `Timeliner/Views/TimelineLayoutEngine.swift` | **Create** — shared types, functions, `ConnectionLinesShape` |
| `Timeliner/Views/TimelineCanvasView.swift` | **Modify** — remove `LabelPosition`, 4 functions, 3 structs, inline Path; call extracted versions |
| `Timeliner/Views/LaneRowView.swift` | **Modify** — remove 4 functions, 3 structs, `yCenter` helper, inline Path; update calls to pass explicit params |

**Net effect:** ~350 lines removed from view files. ~180 lines in new engine file. ~170 net lines saved.
