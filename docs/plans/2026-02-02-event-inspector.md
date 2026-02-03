# Event Inspector Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a trailing inspector panel for editing selected timeline events using SwiftUI's `.inspector()` modifier.

**Architecture:** Inspector visibility controlled by `showInspector` state in ContentView, toggled via toolbar button (⌘I) and View menu. The inspector receives the selected `TimelineEvent` directly and edits it live. A reusable `FlexibleDateEditor` handles progressive date fields.

**Tech Stack:** SwiftUI `.inspector()`, SwiftData live bindings

---

### Task 1: Add showInspector state and toolbar/menu plumbing

**Files:**
- Modify: `Timeliner/ContentView.swift`
- Modify: `Timeliner/TimelinerApp.swift`
- Modify: `Timeliner/Views/TimelineCanvasView.swift`

**Step 1: Add FocusedValueKey for showInspector**

In `ContentView.swift`, add a new FocusedValueKey (following the existing pattern for FitToContentKey and ShowPointLabelsKey):

```swift
struct ShowInspectorKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

// In the FocusedValues extension, add:
var showInspector: Binding<Bool>? {
    get { self[ShowInspectorKey.self] }
    set { self[ShowInspectorKey.self] = newValue }
}
```

**Step 2: Add showInspector state to ContentView**

In ContentView, add `@State private var showInspector = false` alongside the other state vars.

Pass it as a binding to TimelineCanvasView:
```swift
TimelineCanvasView(fitToContent: $fitToContent, showPointLabels: $showPointLabels, showInspector: $showInspector)
```

Add a toolbar button:
```swift
ToolbarItem(placement: .automatic) {
    Button(action: { showInspector.toggle() }) {
        Label("Inspector", systemImage: showInspector ? "info.circle.fill" : "info.circle")
    }
}
```

Add focused scene value:
```swift
.focusedSceneValue(\.showInspector, $showInspector)
```

**Step 3: Add View menu item in TimelinerApp.swift**

In `TimelineCommands`, add `@FocusedBinding(\.showInspector) private var showInspector` and a menu toggle:

```swift
Toggle("Show Inspector", isOn: Binding(
    get: { showInspector ?? false },
    set: { showInspector = $0 }
))
.keyboardShortcut("i", modifiers: .command)
.disabled(showInspector == nil)
```

**Step 4: Update TimelineCanvasView to accept showInspector binding**

Add `@Binding var showInspector: Bool` to TimelineCanvasView. Update the init to accept it. Add a placeholder `.inspector()` modifier:

```swift
.inspector(isPresented: $showInspector) {
    Text("Inspector placeholder")
        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
}
```

Update the Preview to pass the new binding.

**Step 5: Build and verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS'`
Expected: Build succeeds. Toolbar button toggles inspector panel.

**Step 6: Run existing tests**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests`
Expected: All existing tests pass (no regressions).

**Step 7: Commit**

```bash
git add Timeliner/ContentView.swift Timeliner/TimelinerApp.swift Timeliner/Views/TimelineCanvasView.swift
git commit -m "feat: add inspector panel toggle with toolbar button and ⌘I shortcut"
```

---

### Task 2: Create FlexibleDateEditor sub-view

**Files:**
- Create: `Timeliner/Views/FlexibleDateEditor.swift`

This is the reusable component for editing a FlexibleDate with progressive fields. It will be used twice in the inspector (start date, end date).

**Step 1: Create FlexibleDateEditor**

The view takes a `FlexibleDate` binding and uses local `@State` to decompose it into editable fields. On any change, it rebuilds the FlexibleDate and writes it back.

```swift
struct FlexibleDateEditor: View {
    let label: String
    @Binding var flexibleDate: FlexibleDate

    @State private var year: Int
    @State private var hasMonth: Bool
    @State private var month: Int
    @State private var hasDay: Bool
    @State private var day: Int
    @State private var hasTime: Bool
    @State private var hour: Int
    @State private var minute: Int

    init(label: String, flexibleDate: Binding<FlexibleDate>) {
        self.label = label
        self._flexibleDate = flexibleDate
        let fd = flexibleDate.wrappedValue
        let display = fd.localDisplayComponents
        _year = State(initialValue: display.year)
        _hasMonth = State(initialValue: fd.month != nil)
        _month = State(initialValue: display.month)
        _hasDay = State(initialValue: fd.day != nil)
        _day = State(initialValue: display.day)
        _hasTime = State(initialValue: fd.hour != nil)
        _hour = State(initialValue: display.hour)
        _minute = State(initialValue: display.minute)
    }

    var body: some View {
        Section(label) {
            // Year — always shown
            Stepper("Year: \(year)", value: $year, in: 1...9999)
                .onChange(of: year) { _, _ in writeBack() }

            // Month toggle + picker
            Toggle("Month", isOn: $hasMonth)
                .onChange(of: hasMonth) { _, on in
                    if !on { hasDay = false; hasTime = false }
                    writeBack()
                }
            if hasMonth {
                Picker("Month", selection: $month) {
                    ForEach(1...12, id: \.self) { m in
                        Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                    }
                }
                .onChange(of: month) { _, _ in clampDay(); writeBack() }
            }

            // Day toggle + picker (only when month is on)
            if hasMonth {
                Toggle("Day", isOn: $hasDay)
                    .onChange(of: hasDay) { _, on in
                        if !on { hasTime = false }
                        writeBack()
                    }
                if hasDay {
                    Picker("Day", selection: $day) {
                        ForEach(1...daysInMonth(), id: \.self) { d in
                            Text("\(d)").tag(d)
                        }
                    }
                    .onChange(of: day) { _, _ in writeBack() }
                }
            }

            // Time toggle + pickers (only when day is on)
            if hasDay {
                Toggle("Time", isOn: $hasTime)
                    .onChange(of: hasTime) { _, _ in writeBack() }
                if hasTime {
                    Picker("Hour", selection: $hour) {
                        ForEach(0...23, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .onChange(of: hour) { _, _ in writeBack() }
                    Picker("Minute", selection: $minute) {
                        ForEach(0...59, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .onChange(of: minute) { _, _ in writeBack() }
                }
            }
        }
    }

    private func daysInMonth() -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let cal = Calendar.current
        if let date = cal.date(from: comps),
           let range = cal.range(of: .day, in: .month, for: date) {
            return range.count
        }
        return 31
    }

    private func clampDay() {
        let maxDay = daysInMonth()
        if day > maxDay { day = maxDay }
    }

    private func writeBack() {
        if hasTime {
            flexibleDate = FlexibleDate.fromLocalTime(year: year, month: month, day: day, hour: hour, minute: minute)
        } else if hasDay {
            flexibleDate = FlexibleDate(year: year, month: month, day: day)
        } else if hasMonth {
            flexibleDate = FlexibleDate(year: year, month: month)
        } else {
            flexibleDate = FlexibleDate(year: year)
        }
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS'`
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Timeliner/Views/FlexibleDateEditor.swift
git commit -m "feat: add FlexibleDateEditor sub-view for progressive date editing"
```

---

### Task 3: Create EventInspectorView

**Files:**
- Create: `Timeliner/Views/EventInspectorView.swift`

**Step 1: Create EventInspectorView**

The view receives an optional `TimelineEvent` and shows either an empty state or the editing form.

```swift
struct EventInspectorView: View {
    let event: TimelineEvent?

    var body: some View {
        Group {
            if let event {
                EventDetailForm(event: event)
            } else {
                ContentUnavailableView("No Selection", systemImage: "calendar", description: Text("Select an event to edit"))
            }
        }
    }
}

struct EventDetailForm: View {
    @Bindable var event: TimelineEvent

    @State private var startDate: FlexibleDate
    @State private var hasEndDate: Bool
    @State private var endDate: FlexibleDate

    init(event: TimelineEvent) {
        self.event = event
        _startDate = State(initialValue: event.startDate)
        _hasEndDate = State(initialValue: event.endDate != nil)
        _endDate = State(initialValue: event.endDate ?? FlexibleDate(year: event.startDate.year, month: event.startDate.month, day: event.startDate.day))
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $event.title)
            }

            Section("Description") {
                TextEditor(text: Binding(
                    get: { event.eventDescription ?? "" },
                    set: { event.eventDescription = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 60)
            }

            FlexibleDateEditor(label: "Start Date", flexibleDate: $startDate)
                .onChange(of: startDate) { _, newValue in
                    event.startDate = newValue
                }

            Section("End Date") {
                Toggle("Has end date", isOn: $hasEndDate)
                    .onChange(of: hasEndDate) { _, on in
                        if on {
                            event.endDate = endDate
                        } else {
                            event.endDate = nil
                        }
                    }
            }

            if hasEndDate {
                FlexibleDateEditor(label: "End Date", flexibleDate: $endDate)
                    .onChange(of: endDate) { _, newValue in
                        event.endDate = newValue
                    }
            }
        }
        .formStyle(.grouped)
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS'`
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Timeliner/Views/EventInspectorView.swift
git commit -m "feat: add EventInspectorView with title, description, and date editing"
```

---

### Task 4: Wire inspector into TimelineCanvasView

**Files:**
- Modify: `Timeliner/Views/TimelineCanvasView.swift`

**Step 1: Replace placeholder inspector with EventInspectorView**

Replace the placeholder `.inspector()` content with:

```swift
.inspector(isPresented: $showInspector) {
    EventInspectorView(event: selectedEvent)
        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
}
```

Add a computed property to look up the selected event:

```swift
private var selectedEvent: TimelineEvent? {
    guard let id = selectedEventID else { return nil }
    return allEvents.first { $0.id == id }
}
```

**Step 2: Auto-open inspector on event creation**

In the existing `createPointEvent` method, after setting `selectedEventID`, also open the inspector:
```swift
showInspector = true
```

**Step 3: Build and verify**

Run: `xcodebuild build -scheme Timeliner -destination 'platform=macOS'`
Expected: Build succeeds.

**Step 4: Run all tests**

Run: `xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Timeliner/Views/TimelineCanvasView.swift
git commit -m "feat: wire EventInspectorView into timeline canvas"
```

---

### Task 5: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

Update the "Current State" section to document the inspector feature:
- Add line: "Event inspector panel (.inspector()) for editing title, description, start/end dates with progressive FlexibleDate fields; toggled via toolbar button or ⌘I"
- Update "Future Work" item 1 to reflect current editing capabilities

Update "File Locations" to include EventInspectorView.swift and FlexibleDateEditor.swift.

Add design doc reference.

**Commit:**
```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with event inspector feature"
```
