# Event Inspector Design

## Goal

Add a trailing inspector panel for editing selected timeline events, using the native SwiftUI `.inspector()` modifier.

## Decisions

- **Panel type:** SwiftUI `.inspector()` — native trailing panel, independent of the existing NavigationSplitView sidebar
- **Toggle:** Toolbar "i" button (info.circle/info.circle.fill), keyboard shortcut ⌘I, View menu item
- **Editable fields:** Title, description, start date, end date (no lane or tags in v1)
- **Date editing:** Progressive fields — year always shown, month/day/time toggled on individually; precision is implicit from which fields are filled in
- **Save behavior:** Live editing — changes apply immediately to the SwiftData model, no save/cancel buttons
- **Delete:** Not in inspector — handled separately (keyboard/context menu, future work)

## Architecture & State Flow

`showInspector: Bool` state lives in `ContentView` (alongside `fitToContent` and `showPointLabels`) and is passed as a binding to `TimelineCanvasView`, which applies `.inspector(isPresented:)`.

`selectedEventID: UUID?` already exists in `TimelineCanvasView`. When non-nil and the inspector is open, the inspector looks up the `TimelineEvent` by ID from the `allEvents` query. The inspector receives the `TimelineEvent` directly — SwiftData `@Model` objects are reference types, so mutations flow back automatically.

When no event is selected, the inspector shows an empty state ("Select an event to edit"). When the inspector is closed, selection still works visually on the timeline.

## Inspector View Layout

`EventInspectorView` receives a `TimelineEvent?` and edits it live. Top to bottom:

1. **Title** — `TextField` bound to `event.title`
2. **Description** — `TextEditor` bound to `event.eventDescription` (empty string maps to nil)
3. **Start Date** — Progressive fields via a reusable `FlexibleDateEditor` sub-view:
   - Year: always shown (numeric TextField or stepper)
   - Month: toggle to enable, picker (Jan-Dec). Toggling off clears month/day/time.
   - Day: only available when month is on. Toggle to enable, picker (1-28/29/30/31 based on month/year). Toggling off clears day/time.
   - Time: only available when day is on. Toggle to enable, hour/minute pickers. Toggling off clears time.
4. **End Date** — Top-level "Has end date" toggle. When on, shows same `FlexibleDateEditor`. When off, `event.endDate` is nil (point event). End date precision is independent of start date precision.

`FlexibleDateEditor` decomposes a `FlexibleDate` into local `@State` fields on appear, then rebuilds and writes back a new `FlexibleDate` on each change (necessary because FlexibleDate is a value type stored as encoded Data).

## Files Changed

**New:**
- `Timeliner/Views/EventInspectorView.swift` — Inspector panel with title, description, and `FlexibleDateEditor` sub-view

**Modified:**
- `Timeliner/Views/TimelineCanvasView.swift` — Add `.inspector(isPresented:)`, `showInspector` binding, event lookup, pass event to inspector
- `Timeliner/ContentView.swift` — Add `showInspector` state, toolbar button, ⌘I shortcut, View menu item, pass binding to canvas

**Not changed:**
- No model changes (TimelineEvent and FlexibleDate already have all fields)
- No changes to LaneRowView, EventView, or other views
