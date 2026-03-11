# AI-Driven UI Model Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert Timeliner from a direct-manipulation editor to a visualization-first app where Claude Code drives edits via AppleScript.

**Architecture:** Surgical removal of editing surfaces. Inspector becomes read-only with copy-to-clipboard. Event creation UI removed. Event dragging preserved. Sidebar unchanged.

**Tech Stack:** SwiftUI, SwiftData, Swift 6

---

### Task 1: Convert Inspector to Read-Only Display

**Files:**
- Modify: `Timeliner/Views/EventInspectorView.swift` (full rewrite of lines 25-139)

**Step 1: Replace EventDetailForm with read-only EventDetailView**

Replace the entire `EventDetailForm` struct with a new `EventDetailView` that displays event data as read-only text:

```swift
private struct EventDetailView: View {
    let event: TimelineEvent

    var body: some View {
        Form {
            Section("Title") {
                Text(event.title)
                    .textSelection(.enabled)
            }

            Section("Description") {
                if let desc = event.eventDescription, !desc.isEmpty {
                    Text(desc)
                        .textSelection(.enabled)
                } else {
                    Text("No description")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Lane") {
                if let lane = event.lane {
                    HStack {
                        Circle()
                            .fill(Color(hex: lane.color) ?? .gray)
                            .frame(width: TimelineConstants.laneColorCircleSize, height: TimelineConstants.laneColorCircleSize)
                        Text(lane.name)
                    }
                } else {
                    Text("Unassigned")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Dates") {
                LabeledContent("Start") {
                    Text(event.startDate.isoString)
                }
                if let endDate = event.endDate {
                    LabeledContent("End") {
                        Text(endDate.isoString)
                    }
                } else {
                    LabeledContent("Type") {
                        Text("Point event")
                    }
                }
            }

            Section {
                Button("Copy to Clipboard") {
                    copyEventToClipboard()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
    }

    private func copyEventToClipboard() {
        var text = "Title: \(event.title)\n"
        if let lane = event.lane {
            text += "Lane: \(lane.name)\n"
        } else {
            text += "Lane: Unassigned\n"
        }
        text += "Start: \(event.startDate.isoString)\n"
        if let endDate = event.endDate {
            text += "End: \(endDate.isoString)\n"
        } else {
            text += "Type: Point event\n"
        }
        if let desc = event.eventDescription, !desc.isEmpty {
            text += "Description: \(desc)\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
```

**Step 2: Update EventInspectorView to use the new view**

Update the `EventInspectorView` struct:
- Change `EventDetailForm(event: event, onDelete: onDelete)` → `EventDetailView(event: event)`
- Remove the `onDelete` property from `EventInspectorView` (no longer needed)
- Update the "No Selection" text from `"Select an event to edit"` to `"Select an event to view details"`

```swift
struct EventInspectorView: View {
    let event: TimelineEvent?

    var body: some View {
        Group {
            if let event {
                EventDetailView(event: event)
                    .id(event.id)
            } else {
                ContentUnavailableView("No Selection", systemImage: "calendar", description: Text("Select an event to view details"))
            }
        }
    }
}
```

**Step 3: Build and verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (may have warnings about unused `onDelete` callers — we fix those in Task 3)

**Step 4: Commit**

```bash
git add Timeliner/Views/EventInspectorView.swift
git commit -m "feat: convert event inspector to read-only display with copy-to-clipboard"
```

---

### Task 2: Remove Double-Click Creation from LaneRowView

**Files:**
- Modify: `Timeliner/Views/LaneRowView.swift:9-16,94-103,121-132`

**Step 1: Remove onCreateEvent from LaneRowView**

In `LaneRowView`:
- Remove the `onCreateEvent` property (line 15)
- Remove the `SpatialTapGesture(count: 2)` gesture (lines 94-99)
- Remove the accessibility "Create Event" action (lines 100-103)

The struct properties become:
```swift
struct LaneRowView: View {
    let lane: Lane
    let viewport: TimelineViewport
    let showPointLabels: Bool
    let selectedEventID: UUID?
    let onSelectEvent: (TimelineEvent) -> Void
    var onDragEnd: ((TimelineEvent, FlexibleDate, FlexibleDate?) -> Void)?
    // onCreateEvent removed
```

Remove from after `.accessibilityLabel("Lane: \(lane.name)")`:
```swift
        // DELETE these lines:
        .gesture(
            SpatialTapGesture(count: 2)
                .onEnded { value in
                    onCreateEvent(value.location.x)
                }
        )
        .accessibilityAction(named: "Create Event") {
            onCreateEvent(0)
        }
```

**Step 2: Update Preview**

Remove `onCreateEvent` from the Preview:
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

**Step 3: Build (expect errors in TimelineCanvasView — fixed in Task 3)**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | grep -E 'error:|BUILD'`
Expected: Errors about `onCreateEvent` argument at call sites in TimelineCanvasView. This is expected — we fix in the next task.

**Step 4: Commit**

```bash
git add Timeliner/Views/LaneRowView.swift
git commit -m "feat: remove double-click event creation from lane rows"
```

---

### Task 3: Remove Creation Plumbing from TimelineCanvasView and ContentView

**Files:**
- Modify: `Timeliner/Views/TimelineCanvasView.swift:20-21,30-36,73-83,131-142,325-375,384-388`
- Modify: `Timeliner/ContentView.swift:21-28,53-60,85-86,124,131-142,143-148`

**Step 1: Clean up TimelineCanvasView**

Remove from `TimelineCanvasView`:
- `@Binding var createPointEvent: Bool` (line 20)
- `@Binding var createSpanEvent: Bool` (line 21)
- Remove corresponding `init` parameters and `_createPointEvent`/`_createSpanEvent` assignments (lines 34-35)
- Remove `onCreateEvent` closure from `LaneRowView` call site (lines 81-83)
- Remove `.onChange(of: createPointEvent)` block (lines 131-136)
- Remove `.onChange(of: createSpanEvent)` block (lines 137-142)
- Remove `createPointEvent(at:in:viewportWidth:)` method (lines 325-338)
- Remove `createEventFromMenu(span:viewportWidth:)` method (lines 340-375)

Also update the `EventInspectorView` call to remove `onDelete`:
```swift
// Change from:
EventInspectorView(event: selectedEvent, onDelete: { selectedEventID = nil })
// To:
EventInspectorView(event: selectedEvent)
```

Update Preview:
```swift
#Preview {
    TimelineCanvasView(fitToContent: .constant(false), showPointLabels: .constant(false), showInspector: .constant(false), canvasWidth: .constant(800))
        .modelContainer(for: [TimelineEvent.self, Lane.self, Era.self], inMemory: true)
        .frame(width: 800, height: 400)
}
```

**Step 2: Clean up ContentView**

Remove from `ContentView`:
- `CreatePointEventKey` and `CreateSpanEventKey` structs (lines 21-28)
- `createPointEvent` and `createSpanEvent` from `FocusedValues` extension (lines 53-60)
- `@State private var createPointEvent` and `createSpanEvent` (lines 85-86)
- Remove `createPointEvent` and `createSpanEvent` params from `TimelineCanvasView(...)` call (line 124)
- Remove `.focusedSceneValue(\.createPointEvent, ...)` and `.focusedSceneValue(\.createSpanEvent, ...)` (lines 147-148)

**Step 3: Build and verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (may have errors in TimelinerApp — fixed in Task 4)

**Step 4: Commit**

```bash
git add Timeliner/Views/TimelineCanvasView.swift Timeliner/ContentView.swift
git commit -m "feat: remove event creation plumbing from canvas and content views"
```

---

### Task 4: Remove Menu Event Creation Commands

**Files:**
- Modify: `Timeliner/TimelinerApp.swift:22-61`

**Step 1: Remove creation menu items and focused bindings**

In `TimelineCommands`:
- Remove `@FocusedBinding(\.createPointEvent)` (line 26)
- Remove `@FocusedBinding(\.createSpanEvent)` (line 27)
- Remove the entire `CommandGroup(after: .newItem)` block (lines 48-61)

The remaining `TimelineCommands` should be:
```swift
struct TimelineCommands: Commands {
    @FocusedBinding(\.fitToContent) private var fitToContent
    @FocusedBinding(\.showPointLabels) private var showPointLabels
    @FocusedBinding(\.showInspector) private var showInspector
    @FocusedBinding(\.exportPDF) private var exportPDF
    @FocusedBinding(\.exportPNG) private var exportPNG

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Menu("Export") {
                Button("Export as PDF\u{2026}") {
                    exportPDF = true
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(exportPDF == nil)

                Button("Export as PNG\u{2026}") {
                    exportPNG = true
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(exportPNG == nil)
            }
        }

        CommandGroup(after: .toolbar) {
            Button("Fit to Content") {
                fitToContent = true
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(fitToContent == nil)

            Toggle("Show Point Labels", isOn: Binding(
                get: { showPointLabels ?? false },
                set: { showPointLabels = $0 }
            ))
            .keyboardShortcut("l", modifiers: .command)
            .disabled(showPointLabels == nil)

            Toggle("Show Inspector", isOn: Binding(
                get: { showInspector ?? false },
                set: { showInspector = $0 }
            ))
            .keyboardShortcut("i", modifiers: .command)
            .disabled(showInspector == nil)
        }
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Run tests**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests 2>&1 | tail -10`
Expected: All tests pass

**Step 4: Commit**

```bash
git add Timeliner/TimelinerApp.swift
git commit -m "feat: remove event creation menu commands (⌘E, ⇧⌘E)"
```

---

### Task 5: Final Verification and CLAUDE.md Update

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Full build**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 2: Full test suite**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests 2>&1 | tail -10`
Expected: All tests pass

**Step 3: Manual smoke test**

Run: Open the built app and verify:
- Inspector shows read-only event details when an event is selected
- Copy button works (copies structured text to clipboard)
- Double-clicking a lane does NOT create an event
- Dragging events still works (move and resize)
- File menu no longer has New Point Event / New Span Event
- Sidebar lane/era editing still works
- View menu items (Fit to Content, Show Point Labels, Show Inspector) still work
- Export PDF/PNG still works

**Step 4: Update CLAUDE.md**

Update the "Current State" section to reflect the new UI model:
- Add note about AI-driven editing model
- Remove mentions of double-click creation, menu creation, inspector editing
- Add note about read-only inspector with copy-to-clipboard
- Note that AppleScript is now the primary editing interface

**Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md to reflect AI-driven UI model"
```
