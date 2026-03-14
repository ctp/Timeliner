# Simplify Timeliner Codebase — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce duplication and remove unused code (~200+ lines) while preserving all functionality.

**Architecture:** Three independent tasks: (1) extract duplicated label padding computation into a shared helper, (2) consolidate export lane views with live lane views via optional callbacks, (3) delete dead code and boilerplate test files.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing

**Spec:** `docs/plans/2026-03-13-simplify-codebase-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `Timeliner/Views/TimelineLayoutEngine.swift` | Modify | Add `LabelPadding` struct and `computeLabelPadding()`, add `computeLaneRowHeight()`, delete `defaultBaseRowHeight` |
| `Timeliner/Views/LaneRowView.swift` | Modify | Make `onSelectEvent` optional, use `computeLabelPadding()` |
| `Timeliner/Views/UnassignedLaneRowView.swift` | Create | Standalone view extracted from `TimelineCanvasView.unassignedLaneView` |
| `Timeliner/Views/TimelineCanvasView.swift` | Modify | Delete `unassignedLaneView` method, use `UnassignedLaneRowView` |
| `Timeliner/Views/TimelineExporter.swift` | Modify | Delete `ExportLaneRowView`, `ExportUnassignedRowView`, `laneRowHeight`; use shared views |
| `Timeliner/Views/TimelineViewport.swift` | Modify | Delete `titleForDate()` |
| `TimelinerTests/TimelineViewportTests.swift` | Modify | Delete 4 `titleForDate` tests |
| `TimelinerTests/TimelinerTests.swift` | Delete | Empty placeholder |
| `TimelinerUITests/` | Delete | Boilerplate with no assertions |
| `Timeliner.xcodeproj/project.pbxproj` | Modify | Add new file, remove deleted files and UI test target |

---

### Task 1: Extract `computeLabelPadding` and `computeLaneRowHeight`

**Files:**
- Modify: `Timeliner/Views/TimelineLayoutEngine.swift`

- [ ] **Step 1: Add `LabelPadding` struct and `computeLabelPadding` function**

Add after the `ConnectionLines` struct (after line 51), replacing the `defaultBaseRowHeight` constant:

```swift
// MARK: - Label Padding

struct LabelPadding {
    let top: CGFloat
    let bottom: CGFloat
}

func computeLabelPadding(positions: [UUID: LabelPosition]) -> LabelPadding {
    let maxAboveTier = positions.values.filter(\.isAbove).map(\.tier).max()
    let maxBelowTier = positions.values.filter(\.isBelow).map(\.tier).max()
    let top: CGFloat = maxAboveTier != nil
        ? LabelPosition.connectorBase + LabelPosition.tierHeight * CGFloat(maxAboveTier! + 1)
        : 0
    let bottom: CGFloat = maxBelowTier != nil
        ? LabelPosition.connectorBase + LabelPosition.tierHeight * CGFloat(maxBelowTier! + 1)
        : 0
    return LabelPadding(top: top, bottom: bottom)
}
```

- [ ] **Step 2: Add `computeLaneRowHeight` helper**

Add directly after `computeLabelPadding`. This replaces `TimelineExporter.laneRowHeight`:

```swift
func computeLaneRowHeight(
    events: [TimelineEvent],
    viewport: TimelineViewport,
    showPointLabels: Bool
) -> CGFloat {
    let layout = layoutEvents(events, viewport: viewport)
    let positions = showPointLabels
        ? computeLabelPositions(layout: layout, viewport: viewport).positions
        : [:]
    let padding = computeLabelPadding(positions: positions)
    let contentHeight = TimelineConstants.baseRowHeight * CGFloat(max(layout.totalRows, 1))
    return padding.top + contentHeight + padding.bottom
}
```

- [ ] **Step 3: Delete `defaultBaseRowHeight`**

Delete line 55:
```swift
let defaultBaseRowHeight: CGFloat = TimelineConstants.baseRowHeight
```

And delete the `// MARK: - Constants` comment on line 53-54.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (unused constant removal is safe since it has no references)

- [ ] **Step 5: Commit**

```bash
git add Timeliner/Views/TimelineLayoutEngine.swift
git commit -m "Extract computeLabelPadding and computeLaneRowHeight helpers"
```

---

### Task 2: Make `LaneRowView` reusable for export

**Files:**
- Modify: `Timeliner/Views/LaneRowView.swift`

- [ ] **Step 1: Make callbacks optional and use `computeLabelPadding`**

Change the property declarations from:

```swift
    let selectedEventID: UUID?
    let onSelectEvent: (TimelineEvent) -> Void
    var onDragEnd: ((TimelineEvent, FlexibleDate, FlexibleDate?) -> Void)?
```

To:

```swift
    var selectedEventID: UUID? = nil
    var onSelectEvent: ((TimelineEvent) -> Void)? = nil
    var onDragEnd: ((TimelineEvent, FlexibleDate, FlexibleDate?) -> Void)? = nil
```

- [ ] **Step 2: Replace padding block with `computeLabelPadding`**

In `body`, replace lines 28-35:

```swift
        let maxAboveTier = labelPositions.values.filter(\.isAbove).map(\.tier).max()
        let maxBelowTier = labelPositions.values.filter(\.isBelow).map(\.tier).max()
        let topPadding: CGFloat = maxAboveTier != nil
            ? LabelPosition.connectorBase + LabelPosition.tierHeight * CGFloat(maxAboveTier! + 1)
            : 0
        let bottomPadding: CGFloat = maxBelowTier != nil
            ? LabelPosition.connectorBase + LabelPosition.tierHeight * CGFloat(maxBelowTier! + 1)
            : 0
```

With:

```swift
        let padding = computeLabelPadding(positions: labelPositions)
```

Then update all subsequent references in `body`:
- Line 37: `topPadding + laneContentHeight + bottomPadding` → `padding.top + laneContentHeight + padding.bottom`
- Line 38: `yOffset: topPadding` → `yOffset: padding.top` (in `computeConnectionLines`)
- Line 83: `yOffset: topPadding` → `yOffset: padding.top` (in `EventView`)

- [ ] **Step 3: Update EventView onSelect to handle optional callback**

Change line 78 from:

```swift
                    onSelect: { onSelectEvent(item.event) },
```

To:

```swift
                    onSelect: { onSelectEvent?(item.event) },
```

- [ ] **Step 4: Update the Preview to match new optional API**

Change the Preview from:

```swift
#Preview {
    let lane = Lane(name: "Career", color: "#3498DB")
    return LaneRowView(
        lane: lane,
        viewport: TimelineViewport(),
        showPointLabels: false,
        selectedEventID: nil,
        onSelectEvent: { _ in }
    )
    .frame(width: 600)
}
```

To:

```swift
#Preview {
    let lane = Lane(name: "Career", color: "#3498DB")
    return LaneRowView(
        lane: lane,
        viewport: TimelineViewport(),
        showPointLabels: false
    )
    .frame(width: 600)
}
```

- [ ] **Step 5: Build to verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (existing call site in `TimelineCanvasView` already provides all arguments explicitly, so it still compiles)

- [ ] **Step 6: Commit**

```bash
git add Timeliner/Views/LaneRowView.swift
git commit -m "Make LaneRowView callbacks optional for export reuse"
```

---

### Task 3: Extract `UnassignedLaneRowView`

**Files:**
- Create: `Timeliner/Views/UnassignedLaneRowView.swift`
- Modify: `Timeliner/Views/TimelineCanvasView.swift`

- [ ] **Step 1: Create `UnassignedLaneRowView.swift`**

Create `Timeliner/Views/UnassignedLaneRowView.swift`. This is extracted from `TimelineCanvasView.unassignedLaneView` with two additions for consistency with `LaneRowView`: `.clipped()` and `.contentShape(Rectangle())` (the original inline method lacked these, but they are correct for hit-testing and visual clipping):

```swift
//
//  UnassignedLaneRowView.swift
//  Timeliner
//

import SwiftUI

struct UnassignedLaneRowView: View {
    let events: [TimelineEvent]
    let viewport: TimelineViewport
    let showPointLabels: Bool
    var selectedEventID: UUID? = nil
    var onSelectEvent: ((TimelineEvent) -> Void)? = nil
    var onDragEnd: ((TimelineEvent, FlexibleDate, FlexibleDate?) -> Void)? = nil

    var body: some View {
        let layout = layoutEvents(events, viewport: viewport)
        let labelResult = showPointLabels
            ? computeLabelPositions(layout: layout, viewport: viewport)
            : (positions: [:], offsets: [:])
        let labelPositions = labelResult.positions
        let labelOffsets = labelResult.offsets
        let padding = computeLabelPadding(positions: labelPositions)
        let laneContentHeight = TimelineConstants.baseRowHeight * CGFloat(max(layout.totalRows, 1))
        let totalHeight = padding.top + laneContentHeight + padding.bottom
        let lines = computeConnectionLines(
            layout: layout.layout,
            viewport: viewport,
            baseRowHeight: TimelineConstants.baseRowHeight,
            yOffset: padding.top
        )

        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .accessibilityHidden(true)

            ConnectionLinesShape(lines: lines)
                .stroke(Color.gray, lineWidth: TimelineConstants.connectionLineWidth)
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
                .accessibilityHidden(true)

            Text("Unassigned")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 4)
                .accessibilityHidden(true)

            ForEach(layout.layout, id: \.event.id) { item in
                EventView(
                    event: item.event,
                    viewport: viewport,
                    isSelected: item.event.id == selectedEventID,
                    onSelect: { onSelectEvent?(item.event) },
                    subRow: item.subRow,
                    rowHeight: totalHeight,
                    labelPosition: labelPositions[item.event.id] ?? .none,
                    labelXOffset: labelOffsets[item.event.id] ?? 0,
                    yOffset: padding.top,
                    onDragEnd: onDragEnd
                )
            }
        }
        .frame(height: totalHeight)
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lane: Unassigned")
    }
}
```

- [ ] **Step 2: Replace `unassignedLaneView` in `TimelineCanvasView`**

In `TimelineCanvasView.swift`, replace the call site at line 87:

```swift
                            unassignedLaneView(width: geometry.size.width)
```

With:

```swift
                            UnassignedLaneRowView(
                                events: eventsWithoutLane,
                                viewport: viewportWithWidth(geometry.size.width),
                                showPointLabels: showPointLabels,
                                selectedEventID: selectedEventID,
                                onSelectEvent: { event in
                                    selectedEventID = event.id
                                    sidebarSelection = nil
                                },
                                onDragEnd: { event, newStart, newEnd in
                                    applyDrag(event: event, newStart: newStart, newEnd: newEnd)
                                }
                            )
```

- [ ] **Step 3: Delete `unassignedLaneView` method from `TimelineCanvasView`**

Delete the entire `unassignedLaneView(width:)` method (lines 150-220).

- [ ] **Step 4: Add file to Xcode project, build to verify**

Add `UnassignedLaneRowView.swift` to the Timeliner target in Xcode, then:

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Timeliner/Views/UnassignedLaneRowView.swift Timeliner/Views/TimelineCanvasView.swift Timeliner.xcodeproj/project.pbxproj
git commit -m "Extract UnassignedLaneRowView from TimelineCanvasView"
```

---

### Task 4: Consolidate `TimelineExporter`

**Files:**
- Modify: `Timeliner/Views/TimelineExporter.swift`

- [ ] **Step 1: Replace `laneRowHeight` with `computeLaneRowHeight`**

In `computeExportGeometry`, replace the two calls to `laneRowHeight(events:viewport:showPointLabels:)` (lines 199-203 and 206-210) with calls to `computeLaneRowHeight(events:viewport:showPointLabels:)` from `TimelineLayoutEngine`.

For the per-lane call (line 198-203), change:

```swift
            let laneEventsForLane = laneEvents.filter { $0.lane?.id == lane.id }
            lanesHeight += laneRowHeight(
                events: laneEventsForLane,
                viewport: exportViewport,
                showPointLabels: showPointLabels
            )
```

To:

```swift
            let laneEventsForLane = laneEvents.filter { $0.lane?.id == lane.id }
            lanesHeight += computeLaneRowHeight(
                events: laneEventsForLane,
                viewport: exportViewport,
                showPointLabels: showPointLabels
            )
```

For the unassigned call (lines 206-210), change `laneRowHeight(` to `computeLaneRowHeight(`.

- [ ] **Step 2: Update `TimelineExportView` to use shared views**

Replace the `ExportLaneRowView` and `ExportUnassignedRowView` usage in `TimelineExportView.body` (lines 283-299):

```swift
                // Lane rows
                VStack(spacing: 1) {
                    ForEach(lanes, id: \.id) { lane in
                        ExportLaneRowView(
                            lane: lane,
                            viewport: viewport,
                            showPointLabels: showPointLabels
                        )
                    }

                    // Unassigned events
                    let unassigned = events.filter { $0.lane == nil }
                    if !unassigned.isEmpty {
                        ExportUnassignedRowView(
                            events: unassigned,
                            viewport: viewport,
                            showPointLabels: showPointLabels
                        )
                    }
                }
```

With:

```swift
                // Lane rows
                VStack(spacing: 1) {
                    ForEach(lanes, id: \.id) { lane in
                        LaneRowView(
                            lane: lane,
                            viewport: viewport,
                            showPointLabels: showPointLabels
                        )
                    }

                    // Unassigned events
                    let unassigned = events.filter { $0.lane == nil }
                    if !unassigned.isEmpty {
                        UnassignedLaneRowView(
                            events: unassigned,
                            viewport: viewport,
                            showPointLabels: showPointLabels
                        )
                    }
                }
```

- [ ] **Step 3: Delete `ExportLaneRowView`, `ExportUnassignedRowView`, and `laneRowHeight`**

Delete these three items from `TimelineExporter.swift`:
- `laneRowHeight` method (lines 222-242)
- `ExportLaneRowView` struct (lines 311-402)
- `ExportUnassignedRowView` struct (lines 404-478)

Also remove the now-unused `// MARK: - Export Lane Row` and `// MARK: - Export Unassigned Row` comments.

- [ ] **Step 4: Remove `private` from `TimelineExportView`**

`TimelineExportView` was `private` because it lived alongside the private export lane views. Since it now references `LaneRowView` and `UnassignedLaneRowView` (which are internal), it should remain accessible. Check that the `private` keyword on `TimelineExportView` still compiles — it should, since `LaneRowView` is internal and visible within the module. Keep `private` if it compiles.

- [ ] **Step 5: Build to verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Timeliner/Views/TimelineExporter.swift
git commit -m "Remove duplicate export lane views, use shared LaneRowView"
```

---

### Task 5: Remove unused code

**Files:**
- Modify: `Timeliner/Views/TimelineViewport.swift`
- Modify: `TimelinerTests/TimelineViewportTests.swift`
- Delete: `TimelinerTests/TimelinerTests.swift`
- Delete: `TimelinerUITests/TimelinerUITests.swift`
- Delete: `TimelinerUITests/TimelinerUITestsLaunchTests.swift`
- Modify: `Timeliner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Delete `titleForDate` from `TimelineViewport.swift`**

Delete lines 100-114 (the function and its doc comment):

```swift
/// Generate an auto-title for an event at the given date and precision.
func titleForDate(_ date: Date, precision: DatePrecision) -> String {
    let formatter = DateFormatter()
    switch precision {
    case .year:
        formatter.dateFormat = "yyyy"
    case .month:
        formatter.dateFormat = "MMM yyyy"
    case .day:
        formatter.dateFormat = "MMM d, yyyy"
    case .time:
        formatter.dateFormat = "MMM d, h:mm a"
    }
    return formatter.string(from: date)
}
```

- [ ] **Step 2: Delete `titleForDate` tests from `TimelineViewportTests.swift`**

Delete the 4 test methods (lines 186-216):
- `titleForDateYear()`
- `titleForDateMonth()`
- `titleForDateDay()`
- `titleForDateTime()`

Keep the rest of `TimelineViewportTests` intact (closing brace on what was line 217 stays).

- [ ] **Step 3: Delete `TimelinerTests.swift`**

```bash
rm TimelinerTests/TimelinerTests.swift
```

- [ ] **Step 4: Delete `TimelinerUITests/` directory**

```bash
rm -rf TimelinerUITests/
```

- [ ] **Step 5: Remove deleted files and UI test target from Xcode project**

Remove the file references for `TimelinerTests.swift`, `TimelinerUITests.swift`, and `TimelinerUITestsLaunchTests.swift` from the Xcode project. Remove the `TimelinerUITests` target entirely from the project.

- [ ] **Step 6: Build and run tests to verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests 2>&1 | tail -10`
Expected: All tests pass (FlexibleDateTests, TimelineViewportTests minus deleted tests, LaneTests)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Remove unused code: titleForDate, placeholder tests, UI test boilerplate"
```

---

### Task 6: Final verification

- [ ] **Step 1: Full build**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Full test suite**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 3: Verify line count reduction**

Run: `find Timeliner TimelinerTests -name '*.swift' | xargs wc -l | tail -1`
Compare against baseline of ~4,834 lines. Expected reduction: ~200+ lines.
