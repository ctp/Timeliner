# Event Dragging Design

**Goal:** Allow users to drag timeline events to move them in time, and drag span event edges to resize them.

## Interaction Model

Three drag operations, all on EventView:

1. **Move (point or span)**: Drag the event body to slide it along the timeline. For spans, both start and end dates shift by the same delta, preserving duration. Dates snap to the current zoom precision.

2. **Resize start (span only)**: Drag near the left edge of a span to change its start date. The end date stays fixed. Minimum duration is one precision unit (1 hour at time precision, 1 day at day, 1 month at month, 1 year at year).

3. **Resize end (span only)**: Drag near the right edge of a span to change its end date. The start date stays fixed. Same minimum duration constraint.

**Edge detection**: A ~6pt hit zone on each end of a span distinguishes resize from move. If the drag starts within 6pt of the left/right edge, it's a resize; otherwise it's a move. Point events are always move-only.

**Visual feedback**: During a drag, the event renders at its new position in real-time.

**Selection on drag**: Dragging an event also selects it (set on drag start), so the inspector shows the event being dragged.

## Data Flow & Architecture

**Drag state**: EventView holds `@State` for `dragMode` (enum: none/move/resizeStart/resizeEnd) and `dragOffset` (in points). On drag start, it determines the mode based on touch position relative to span edges. During the drag, the event renders at its offset position. On drag end, it computes the new date(s) and calls a callback.

**Callback**: EventView gets a new closure parameter:

```swift
var onDragEnd: (TimelineEvent, FlexibleDate, FlexibleDate?) -> Void
```

This passes the event, new start date, and new end date (nil for points). The parent (LaneRowView) forwards this to TimelineCanvasView, which writes to the model context and saves.

**Snapping**: During drag, the preview position snaps visually. The offset is converted to a date via `viewport.date(forX:)`, snapped via `viewport.snappedDate(from:precision:)`, then converted back to an x position for rendering.

**Minimum duration enforcement**: When resizing, the dragged edge is clamped so that end date >= start date + one precision unit. Uses `Calendar.date(byAdding:)`.

**Precision preservation**: The new FlexibleDate is created at the event's existing precision (`event.startDate.precision`), not the viewport's current precision. This avoids changing a year-precision event to day-precision just because you're zoomed in.

## Gesture Implementation

Use `DragGesture(minimumDistance: 4)` for move/resize alongside the existing `.onTapGesture` for selection. SwiftUI resolves these naturally -- taps fire the tap gesture, drags exceeding 4pt fire the drag gesture.

On `DragGesture.onChanged` (first call, when dragMode is .none), determine the mode by checking if the initial position is within 6pt of either span edge. Set `dragMode` for the rest of the gesture. On `.onEnded`, compute final snapped dates and call `onDragEnd`.
