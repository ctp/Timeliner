# Point Event Creation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable double-click on lane rows to create point events with zoom-appropriate precision.

**Architecture:** Add `currentPrecision()` and `snappedDate()` helpers to `TimelineViewport`, a double-click gesture to `LaneRowView`, and event creation logic in `TimelineCanvasView`. Pure additions — no existing behavior changes.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing

**Design doc:** `docs/plans/2026-02-02-point-event-creation-design.md`

---

### Task 1: Add `currentPrecision()` to TimelineViewport

**Files:**
- Modify: `Timeliner/Views/TimelineViewport.swift:50` (append after end of struct, before closing brace)
- Test: `TimelinerTests/TimelineViewportTests.swift`

**Step 1: Write the failing tests**

Add to `TimelinerTests/TimelineViewportTests.swift`:

```swift
@Test func currentPrecisionAtMinuteZoom() {
    let vp = TimelineViewport(centerDate: Date(), scale: 30, viewportWidth: 1000)
    #expect(vp.currentPrecision() == .time)
}

@Test func currentPrecisionAtHourZoom() {
    let vp = TimelineViewport(centerDate: Date(), scale: 600, viewportWidth: 1000)
    #expect(vp.currentPrecision() == .time)
}

@Test func currentPrecisionAtDayZoom() {
    let vp = TimelineViewport(centerDate: Date(), scale: 43200, viewportWidth: 1000)
    #expect(vp.currentPrecision() == .day)
}

@Test func currentPrecisionAtMonthZoom() {
    let vp = TimelineViewport(centerDate: Date(), scale: 5_000_000, viewportWidth: 1000)
    #expect(vp.currentPrecision() == .month)
}

@Test func currentPrecisionAtYearZoom() {
    let vp = TimelineViewport(centerDate: Date(), scale: 50_000_000, viewportWidth: 1000)
    #expect(vp.currentPrecision() == .year)
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineViewportTests 2>&1 | tail -20`
Expected: FAIL — `currentPrecision()` not found

**Step 3: Write minimal implementation**

Add to `Timeliner/Views/TimelineViewport.swift` inside the struct, before the closing `}`:

```swift
/// Returns the appropriate FlexibleDate precision for the current zoom level.
func currentPrecision() -> DatePrecision {
    switch scale {
    case ..<3_600:       return .time   // Can see hours or finer
    case ..<86_400:      return .day    // Can see parts of days
    case ..<2_592_000:   return .day    // Days to weeks
    case ..<31_536_000:  return .month  // Months
    default:             return .year   // Years+
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineViewportTests 2>&1 | tail -20`
Expected: All PASS

**Step 5: Commit**

```bash
git add Timeliner/Views/TimelineViewport.swift TimelinerTests/TimelineViewportTests.swift
git commit -m "feat: add currentPrecision() to TimelineViewport"
```

---

### Task 2: Add `snappedDate()` to TimelineViewport

**Files:**
- Modify: `Timeliner/Views/TimelineViewport.swift` (append inside struct)
- Test: `TimelinerTests/TimelineViewportTests.swift`

**Step 1: Write the failing tests**

Add to `TimelinerTests/TimelineViewportTests.swift`:

```swift
@Test func snappedDateYearPrecision() {
    let vp = TimelineViewport()
    // July 15, 2024 14:30 → Jan 1, 2024
    var comps = DateComponents()
    comps.year = 2024; comps.month = 7; comps.day = 15; comps.hour = 14; comps.minute = 30
    let input = Calendar.current.date(from: comps)!
    let snapped = vp.snappedDate(from: input, precision: .year)
    let result = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: snapped)
    #expect(result.year == 2024)
    #expect(result.month == 1)
    #expect(result.day == 1)
    #expect(result.hour == 0)
    #expect(result.minute == 0)
}

@Test func snappedDateMonthPrecision() {
    let vp = TimelineViewport()
    var comps = DateComponents()
    comps.year = 2024; comps.month = 7; comps.day = 15; comps.hour = 14; comps.minute = 30
    let input = Calendar.current.date(from: comps)!
    let snapped = vp.snappedDate(from: input, precision: .month)
    let result = Calendar.current.dateComponents([.year, .month, .day], from: snapped)
    #expect(result.year == 2024)
    #expect(result.month == 7)
    #expect(result.day == 1)
}

@Test func snappedDateDayPrecision() {
    let vp = TimelineViewport()
    var comps = DateComponents()
    comps.year = 2024; comps.month = 7; comps.day = 15; comps.hour = 14; comps.minute = 30
    let input = Calendar.current.date(from: comps)!
    let snapped = vp.snappedDate(from: input, precision: .day)
    let result = Calendar.current.dateComponents([.year, .month, .day, .hour], from: snapped)
    #expect(result.year == 2024)
    #expect(result.month == 7)
    #expect(result.day == 15)
    #expect(result.hour == 0)
}

@Test func snappedDateTimePrecision() {
    let vp = TimelineViewport()
    var comps = DateComponents()
    comps.year = 2024; comps.month = 7; comps.day = 15; comps.hour = 14; comps.minute = 37
    let input = Calendar.current.date(from: comps)!
    let snapped = vp.snappedDate(from: input, precision: .time)
    let result = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: snapped)
    #expect(result.year == 2024)
    #expect(result.month == 7)
    #expect(result.day == 15)
    #expect(result.hour == 14)
    #expect(result.minute == 37)
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineViewportTests 2>&1 | tail -20`
Expected: FAIL — `snappedDate(from:precision:)` not found

**Step 3: Write minimal implementation**

Add to `Timeliner/Views/TimelineViewport.swift` inside the struct:

```swift
/// Snap a date to the boundary for the given precision.
/// Returns the start of the year, month, day, or the exact minute.
func snappedDate(from date: Date, precision: DatePrecision) -> Date {
    let cal = Calendar.current
    switch precision {
    case .year:
        return cal.dateInterval(of: .year, for: date)!.start
    case .month:
        return cal.dateInterval(of: .month, for: date)!.start
    case .day:
        return cal.startOfDay(for: date)
    case .time:
        // Snap to the current minute
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return cal.date(from: comps)!
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineViewportTests 2>&1 | tail -20`
Expected: All PASS

**Step 5: Commit**

```bash
git add Timeliner/Views/TimelineViewport.swift TimelinerTests/TimelineViewportTests.swift
git commit -m "feat: add snappedDate() to TimelineViewport"
```

---

### Task 3: Add `flexibleDate(from:precision:)` and `titleForDate(_:precision:)` helpers

These are free functions (or static methods) that convert a snapped `Date` into a `FlexibleDate` and generate the auto-title. They go in `TimelineViewport.swift` to keep the viewport as the single source of date-conversion logic.

**Files:**
- Modify: `Timeliner/Views/TimelineViewport.swift` (add outside the struct, at file level)
- Test: `TimelinerTests/TimelineViewportTests.swift`

**Step 1: Write the failing tests**

Add a new test struct in `TimelinerTests/TimelineViewportTests.swift` (or append to existing):

```swift
struct EventCreationHelperTests {

    @Test func flexibleDateYearPrecision() {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 1; comps.day = 1
        let date = Calendar.current.date(from: comps)!
        let fd = flexibleDate(from: date, precision: .year)
        #expect(fd.year == 2024)
        #expect(fd.month == nil)
        #expect(fd.day == nil)
        #expect(fd.hour == nil)
        #expect(fd.precision == .year)
    }

    @Test func flexibleDateMonthPrecision() {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 7; comps.day = 1
        let date = Calendar.current.date(from: comps)!
        let fd = flexibleDate(from: date, precision: .month)
        #expect(fd.year == 2024)
        #expect(fd.month == 7)
        #expect(fd.day == nil)
        #expect(fd.precision == .month)
    }

    @Test func flexibleDateDayPrecision() {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 7; comps.day = 15
        let date = Calendar.current.date(from: comps)!
        let fd = flexibleDate(from: date, precision: .day)
        #expect(fd.year == 2024)
        #expect(fd.month == 7)
        #expect(fd.day == 15)
        #expect(fd.hour == nil)
        #expect(fd.precision == .day)
    }

    @Test func flexibleDateTimePrecision() {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 7; comps.day = 15; comps.hour = 14; comps.minute = 30
        let date = Calendar.current.date(from: comps)!
        let fd = flexibleDate(from: date, precision: .time)
        // Should round-trip through localDisplayComponents back to local time
        let display = fd.localDisplayComponents
        #expect(display.year == 2024)
        #expect(display.month == 7)
        #expect(display.day == 15)
        #expect(display.hour == 14)
        #expect(display.minute == 30)
    }

    @Test func titleForDateYear() {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 1; comps.day = 1
        let date = Calendar.current.date(from: comps)!
        let title = titleForDate(date, precision: .year)
        #expect(title == "2024")
    }

    @Test func titleForDateMonth() {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 7; comps.day = 1
        let date = Calendar.current.date(from: comps)!
        let title = titleForDate(date, precision: .month)
        #expect(title == "Jul 2024")
    }

    @Test func titleForDateDay() {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 7; comps.day = 15
        let date = Calendar.current.date(from: comps)!
        let title = titleForDate(date, precision: .day)
        #expect(title == "Jul 15, 2024")
    }

    @Test func titleForDateTime() {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 7; comps.day = 15; comps.hour = 14; comps.minute = 30
        let date = Calendar.current.date(from: comps)!
        let title = titleForDate(date, precision: .time)
        #expect(title == "Jul 15, 2:30 PM")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineViewportTests 2>&1 | tail -20`
Expected: FAIL — functions not found

**Step 3: Write minimal implementation**

Add at the bottom of `Timeliner/Views/TimelineViewport.swift`, outside the struct:

```swift
/// Convert a Foundation Date to a FlexibleDate at the given precision.
/// For `.time` precision, uses `FlexibleDate.fromLocalTime(...)` for correct UTC storage.
func flexibleDate(from date: Date, precision: DatePrecision) -> FlexibleDate {
    let cal = Calendar.current
    let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    switch precision {
    case .year:
        return FlexibleDate(year: comps.year!)
    case .month:
        return FlexibleDate(year: comps.year!, month: comps.month!)
    case .day:
        return FlexibleDate(year: comps.year!, month: comps.month!, day: comps.day!)
    case .time:
        return FlexibleDate.fromLocalTime(
            year: comps.year!, month: comps.month!, day: comps.day!,
            hour: comps.hour!, minute: comps.minute!
        )
    }
}

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

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineViewportTests 2>&1 | tail -20`
Expected: All PASS

**Step 5: Commit**

```bash
git add Timeliner/Views/TimelineViewport.swift TimelinerTests/TimelineViewportTests.swift
git commit -m "feat: add flexibleDate() and titleForDate() helpers"
```

---

### Task 4: Add double-click gesture to LaneRowView

**Files:**
- Modify: `Timeliner/Views/LaneRowView.swift:9-14` (add `onCreateEvent` closure parameter)
- Modify: `Timeliner/Views/LaneRowView.swift:82-84` (add gesture to ZStack)
- Modify: `Timeliner/Views/LaneRowView.swift:102-112` (update preview)

This is a UI gesture — no unit test. Verified by build + manual testing.

**Step 1: Add the `onCreateEvent` parameter**

In `Timeliner/Views/LaneRowView.swift`, add a new parameter to the struct after `onSelectEvent`:

```swift
let onCreateEvent: (_ xPosition: CGFloat) -> Void
```

**Step 2: Wrap the ZStack in a GeometryReader and add the double-click gesture**

Replace the current `ZStack(alignment: .leading) { ... }.frame(height: totalHeight).clipped()` block. The ZStack needs access to its local coordinate space for the click position. Add an `onTapGesture(count: 2)` on the ZStack background:

In `body`, change lines 39-84 to wrap with a coordinate space and add the gesture. Specifically, add the following after `.clipped()` (line 84):

```swift
.contentShape(Rectangle())
.onTapGesture(count: 2) { location in
    onCreateEvent(location.x)
}
```

Note: `onTapGesture(count:perform:)` with a location parameter requires the `(CGPoint) -> Void` variant available via the `SpatialTapGesture`. Use instead:

```swift
.gesture(
    SpatialTapGesture(count: 2)
        .onEnded { value in
            onCreateEvent(value.location.x)
        }
)
```

Add this after `.clipped()` on line 84.

**Step 3: Update the preview**

Update the `#Preview` to pass the new parameter:

```swift
#Preview {
    let lane = Lane(name: "Career", color: "#3498DB")
    return LaneRowView(
        lane: lane,
        viewport: TimelineViewport(),
        showPointLabels: false,
        selectedEventID: nil,
        onSelectEvent: { _ in },
        onCreateEvent: { _ in }
    )
    .frame(width: 600)
}
```

**Step 4: Build to verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -10`
Expected: Build will fail because `TimelineCanvasView` doesn't pass the new parameter yet. That's expected — we fix it in Task 5.

**Step 5: Commit (even with build error — Task 5 fixes it immediately)**

```bash
git add Timeliner/Views/LaneRowView.swift
git commit -m "feat: add double-click gesture to LaneRowView"
```

---

### Task 5: Wire up event creation in TimelineCanvasView

**Files:**
- Modify: `Timeliner/Views/TimelineCanvasView.swift:9` (add `@Environment` for modelContext)
- Modify: `Timeliner/Views/TimelineCanvasView.swift:47-56` (add `onCreateEvent` to LaneRowView)

**Step 1: Add modelContext environment**

Add after line 13 (`@Query private var allEvents: [TimelineEvent]`):

```swift
@Environment(\.modelContext) private var modelContext
```

**Step 2: Add `onCreateEvent` closure to each LaneRowView in the ForEach**

Change the `LaneRowView(...)` call at lines 48-56 to include the new parameter:

```swift
LaneRowView(
    lane: lane,
    viewport: viewportWithWidth(geometry.size.width),
    showPointLabels: showPointLabels,
    selectedEventID: selectedEventID,
    onSelectEvent: { event in
        selectedEventID = event.id
    },
    onCreateEvent: { xPosition in
        createPointEvent(at: xPosition, in: lane, viewportWidth: geometry.size.width)
    }
)
```

**Step 3: Add the `createPointEvent` method**

Add a new private method to `TimelineCanvasView`:

```swift
private func createPointEvent(at xPosition: CGFloat, in lane: Lane, viewportWidth: CGFloat) {
    let vp = viewportWithWidth(viewportWidth)
    let precision = vp.currentPrecision()
    let rawDate = vp.date(forX: xPosition)
    let snapped = vp.snappedDate(from: rawDate, precision: precision)
    let fd = flexibleDate(from: snapped, precision: precision)
    let title = titleForDate(snapped, precision: precision)

    let event = TimelineEvent(title: title, startDate: fd, lane: lane)
    modelContext.insert(event)
    selectedEventID = event.id
}
```

**Step 4: Build and run**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 5: Run all tests**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests 2>&1 | tail -20`
Expected: All PASS

**Step 6: Commit**

```bash
git add Timeliner/Views/TimelineCanvasView.swift
git commit -m "feat: wire up double-click point event creation"
```

---

### Task 6: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update the "Current State" section**

Add under "Implemented":
```
- ✅ Point event creation: double-click on lane row to create a point event with zoom-appropriate precision and auto-generated title
```

Remove "Event Editing UI" from the "Future Work" list or update it to note that creation is done but editing is still pending.

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with point event creation"
```
