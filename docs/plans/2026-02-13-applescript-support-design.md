# AppleScript Support for Timeliner

## Goal

Make Timeliner fully scriptable via AppleScript so that external tools — particularly Claude instances running in Claude Desktop — can create documents, set up lanes, populate events, modify timelines, and query their contents entirely through `osascript` commands. The scripting dictionary should feel native to AppleScript and follow Cocoa Scripting conventions.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Scope | Data CRUD only (no UI/viewport control) | Keeps the scripting surface stable across UI changes; Claude doesn't need to zoom/pan |
| Document creation | Supported via `make new document` | Gives Claude full autonomy to build timelines from scratch |
| Date format | ISO-ish strings with precision inference | `"2026"`, `"2026-02"`, `"2026-02-13"`, `"2026-02-13T14:30"` — natural for LLMs, maps cleanly to FlexibleDate |
| Complementary interfaces | AppleScript only | `osascript` covers both one-shot and multi-step workflows; avoids maintaining multiple interfaces |
| Architecture | Cocoa Scripting object model (noun-based) | Supports `get`, `set`, `make`, `delete`, `count`, `every ... whose ...` — the full AppleScript idiom |

---

## AppleScript Usage Examples

These examples show what a Claude instance (or any scripter) would be able to do.

### Create a document and populate it

```applescript
tell application "Timeliner"
    set newDoc to make new document

    tell newDoc
        -- Create lanes
        set workLane to make new lane with properties {name:"Work", color:"#3498DB", sort order:0}
        set personalLane to make new lane with properties {name:"Personal", color:"#E74C3C", sort order:1}

        -- Create a point event (no end date)
        make new timeline event with properties ¬
            {title:"Project Kickoff", start date:"2026-03-01", lane:workLane}

        -- Create a span event
        make new timeline event with properties ¬
            {title:"Sprint 1", start date:"2026-03-01", end date:"2026-03-14", lane:workLane}

        -- Year-precision event
        make new timeline event with properties ¬
            {title:"Company Founded", start date:"2020", lane:workLane}

        -- Time-precision event
        make new timeline event with properties ¬
            {title:"Standup Meeting", start date:"2026-03-01T09:00", lane:workLane}
    end tell

    save newDoc in POSIX file "/Users/me/Desktop/Project.timeliner"
end tell
```

### Query and modify events

```applescript
tell application "Timeliner"
    tell document "Project"
        -- Get all events
        get title of every timeline event

        -- Filter events
        get every timeline event whose title contains "Sprint"

        -- Count events in a lane
        count timeline events of lane "Work"

        -- Modify an event
        set title of timeline event "Project Kickoff" to "Official Kickoff"
        set event description of timeline event "Official Kickoff" to "All hands meeting in Building 3"

        -- Move event to a different lane
        set lane of timeline event "Standup Meeting" to lane "Personal"

        -- Change dates
        set start date of timeline event "Sprint 1" to "2026-03-02"
        set end date of timeline event "Sprint 1" to "2026-03-15"

        -- Convert point event to span
        set end date of timeline event "Official Kickoff" to "2026-03-02"

        -- Delete an event
        delete timeline event "Standup Meeting"
    end tell
end tell
```

### Introspect a document

```applescript
tell application "Timeliner"
    tell document 1
        -- List all lanes
        get name of every lane

        -- Get full event details
        get properties of timeline event 1

        -- Get events in date order
        get title of every timeline event whose start date > "2026-03"

        -- Lane details
        get {name, color, sort order} of every lane
    end tell
end tell
```

### Build a timeline from structured data (typical Claude workflow)

```applescript
tell application "Timeliner"
    set doc to make new document

    tell doc
        set historyLane to make new lane with properties {name:"Key Events", color:"#2ECC71", sort order:0}
        set erasLane to make new lane with properties {name:"Eras", color:"#9B59B6", sort order:1}

        -- Claude would generate many of these from research
        make new timeline event with properties ¬
            {title:"Apollo 11 Landing", start date:"1969-07", event description:"First crewed Moon landing", lane:historyLane}
        make new timeline event with properties ¬
            {title:"Space Shuttle Program", start date:"1981", end date:"2011", lane:erasLane}
        make new timeline event with properties ¬
            {title:"ISS Construction", start date:"1998-11", end date:"2011-07", lane:erasLane}
        make new timeline event with properties ¬
            {title:"Mars Rover Curiosity", start date:"2012-08-06", lane:historyLane}
    end tell

    save doc in POSIX file "/Users/me/Desktop/Space History.timeliner"
end tell
```

---

## Architecture

### The Bridging Problem

SwiftUI's `DocumentGroup` manages documents internally via AppKit's `NSDocument`. We cannot subclass the NSDocument that SwiftUI creates, and SwiftData's `ModelContext` is injected through the SwiftUI environment — it isn't accessible from outside the view hierarchy.

Cocoa Scripting expects a KVC-compliant object graph rooted at `NSApplication`, with `orderedDocuments` returning scriptable document objects.

### Solution: Document Registry + Scriptable Wrappers

```
AppleScript
    │ (Apple Events)
    ▼
NSApplication ──KVC──▶ scriptableDocuments
    │                        │
    │                        ▼
    │                 ScriptableDocument[]
    │                   │         │
    │              KVC: lanes   events
    │                   │         │
    │                   ▼         ▼
    │           ScriptableLane[] ScriptableEvent[]
    │                   │         │
    │              wraps │    wraps │
    │                   ▼         ▼
    │               Lane      TimelineEvent
    │              (SwiftData)  (SwiftData)
    │                   │         │
    │                   └────┬────┘
    │                        │
    ▼                        ▼
DocumentRegistry ◄────── ModelContext
    ▲                        │
    │                   registered by
    │                        │
    └─────────────────── ContentView.onAppear
```

**Components:**

1. **DocumentRegistry** (`@MainActor` singleton) — Maps open documents to their SwiftData `ModelContext`. ContentView registers on appear, unregisters on disappear. The registry also holds a reference to each document's `NSDocument` instance (obtained by matching file URLs via `NSDocumentController`).

2. **Scriptable Wrappers** (`NSObject` subclasses) — KVC-compliant objects that bridge between Cocoa Scripting and SwiftData models:
   - `ScriptableDocument` — wraps a ModelContext + NSDocument reference
   - `ScriptableLane` — wraps a `Lane`
   - `ScriptableEvent` — wraps a `TimelineEvent`

3. **SDEF** (Scripting Definition File) — Declares the AppleScript dictionary: classes, properties, containment, and commands.

4. **NSApplication Extension** — Provides the `scriptableDocuments` KVC entry point that Cocoa Scripting uses to resolve `document` references.

5. **Custom Commands** — `NSScriptCommand` subclasses for operations that don't map cleanly to standard KVC patterns (e.g., `make new document`).

### Document-to-ModelContext Matching

When ContentView appears, it registers its `ModelContext` with the `DocumentRegistry`. The registry matches it to the corresponding `NSDocument` by comparing the SwiftData store URL (from `ModelContainer.configurations`) against `NSDocument.fileURL`:

- **Saved documents:** The `.timeliner` package URL from `NSDocument.fileURL` is a parent of the SwiftData store path inside the package.
- **Untitled documents:** Store URLs point to temp directories. Match by elimination against the list of `NSDocumentController.shared.documents` that don't have file URLs.

### Document Creation Flow

When AppleScript sends `make new document`:

1. Custom `CreateDocumentCommand` calls `NSDocumentController.shared.openUntitledDocument(andDisplay: true)`
2. AppKit creates a new `NSDocument` and window synchronously
3. SwiftUI instantiates `ContentView`, which calls `.onAppear` during the layout pass
4. `.onAppear` registers the new ModelContext with `DocumentRegistry`
5. The command handler retrieves the newly registered `ScriptableDocument` and returns it

> **Note:** If `.onAppear` timing is unreliable (deferred to next run loop), the command handler should spin the run loop briefly or use a registration callback with a short timeout.

---

## SDEF Structure

The Scripting Definition File (`Timeliner.sdef`) defines two suites:

### Standard Suite

Inherits standard commands (`open`, `close`, `save`, `make`, `delete`, `count`, `exists`, `get`, `set`) and defines:

- **`application`** — root object, contains `document` elements via `scriptableDocuments` KVC key
- **`document`** — name (r/o), file (r/o), modified (r/o)

### Timeliner Suite

Extends `document` and adds domain classes:

- **`document`** (class extension) — contains `lane` and `timeline event` elements
- **`lane`** (`Lane`) — id (r/o), name (r/w), color (r/w), sort order (r/w); contains `timeline event` elements
- **`timeline event`** (`TEvt`) — id (r/o), title (r/w), event description (r/w), start date (r/w text), end date (r/w text), is point event (r/o boolean), lane (r/w reference)

### Property Type Notes

| AppleScript Property | SDEF Type | KVC Key | Notes |
|---------------------|-----------|---------|-------|
| `start date` | `text` | `startDateString` | ISO-ish string, not AppleScript `date` |
| `end date` | `text` | `endDateString` | Empty/missing = point event |
| `color` | `text` | `color` | Hex string like `"#3498DB"` |
| `lane` | `lane` (reference) | `lane` | Object specifier to a lane |
| `event description` | `text` | `eventDescription` | Avoids `description` reserved word |

### Four-Character Codes

| Class/Property | Code | Notes |
|---------------|------|-------|
| lane | `Lane` | |
| timeline event | `TEvt` | |
| start date | `stdt` | |
| end date | `endt` | |
| event description | `edsc` | |
| sort order | `sord` | |
| color | `colr` | |
| is point event | `isPt` | |
| lane (property) | `evln` | Lane reference on an event |

---

## ISO-ish Date String Parsing

Add a `FlexibleDate` extension for bidirectional string conversion:

### Parsing Rules (String → FlexibleDate)

| Input Format | Precision | Example |
|-------------|-----------|---------|
| `YYYY` | `.year` | `"2026"` |
| `YYYY-MM` | `.month` | `"2026-02"` |
| `YYYY-MM-DD` | `.day` | `"2026-02-13"` |
| `YYYY-MM-DDThh:mm` | `.time` | `"2026-02-13T14:30"` |

- Parser uses a simple regex or component split — no need for `ISO8601DateFormatter` since we're not parsing full ISO 8601.
- Time-precision strings are interpreted as **local time** (matching user expectation in scripts). Internally converted to UTC via `FlexibleDate.fromLocalTime(...)`.
- Invalid strings should return `nil` and the scripting command should report an error.

### Formatting Rules (FlexibleDate → String)

Output matches the input format for the date's precision:
- Year: `"2026"`
- Month: `"2026-02"`
- Day: `"2026-02-13"`
- Time: `"2026-02-13T14:30"` (converted to local time via `localDisplayComponents`)

---

## Implementation Components

### New Files

```
Timeliner/
├── Scripting/
│   ├── Timeliner.sdef              # AppleScript dictionary definition
│   ├── DocumentRegistry.swift      # Singleton mapping documents to ModelContexts
│   ├── ScriptableDocument.swift    # NSObject wrapper for document scripting
│   ├── ScriptableLane.swift        # NSObject wrapper for Lane scripting
│   ├── ScriptableEvent.swift       # NSObject wrapper for TimelineEvent scripting
│   ├── CreateDocumentCommand.swift # NSScriptCommand for `make new document`
│   └── NSApplication+Scripting.swift  # KVC entry point for scriptableDocuments
```

### Modified Files

| File | Changes |
|------|---------|
| `Info.plist` | Add `NSAppleScriptEnabled = YES` and `OSAScriptingDefinition = Timeliner.sdef` |
| `ContentView.swift` | Register/unregister ModelContext with DocumentRegistry in `.onAppear`/`.onDisappear` |
| `Models/FlexibleDate.swift` | Add `init?(isoString:)` parser and `var isoString: String` formatter |
| `TimelinerApp.swift` | No changes needed if using NSApplication extension (no delegate adaptor required) |

### Xcode Project

- Add `Timeliner.sdef` to the target (Xcode recognizes `.sdef` files and processes them automatically)
- Add all new `.swift` files to the Timeliner target

---

## Scriptable Wrapper Design

### ScriptableDocument

```swift
@MainActor
class ScriptableDocument: NSObject {
    let modelContext: ModelContext
    weak var nsDocument: NSDocument?

    // KVC properties
    @objc var name: String          // → nsDocument.displayName
    @objc var fileURL: URL?         // → nsDocument.fileURL
    @objc var isDocumentEdited: Bool // → nsDocument.isDocumentEdited

    // Element accessors (called by Cocoa Scripting for `lanes`, `events`)
    @objc var lanes: [ScriptableLane]         // fetch Lane, wrap
    @objc var events: [ScriptableEvent]       // fetch TimelineEvent, wrap

    // Insertion/removal (called by `make new lane`, `delete lane`)
    @objc func insertInLanes(_ lane: ScriptableLane, at index: Int)
    @objc func removeFromLanes(at index: Int)
    @objc func insertInEvents(_ event: ScriptableEvent, at index: Int)
    @objc func removeFromEvents(at index: Int)

    // Object specifier (e.g., "document 1" or "document \"Project\"")
    override var objectSpecifier: NSScriptObjectSpecifier?
}
```

### ScriptableLane

```swift
@MainActor
class ScriptableLane: NSObject {
    let lane: Lane
    let modelContext: ModelContext
    weak var document: ScriptableDocument?

    // KVC properties
    @objc var uniqueID: String      // → lane.id.uuidString
    @objc var name: String          // → lane.name (get/set)
    @objc var color: String         // → lane.color (get/set)
    @objc var sortOrder: Int        // → lane.sortOrder (get/set)

    // Element accessor
    @objc var events: [ScriptableEvent]  // → lane.events, wrapped

    // Insertion/removal for events within this lane
    @objc func insertInEvents(_ event: ScriptableEvent, at index: Int)
    @objc func removeFromEvents(at index: Int)

    // Object specifier (e.g., "lane \"Work\" of document 1")
    override var objectSpecifier: NSScriptObjectSpecifier?
}
```

### ScriptableEvent

```swift
@MainActor
class ScriptableEvent: NSObject {
    let event: TimelineEvent
    let modelContext: ModelContext
    weak var document: ScriptableDocument?

    // KVC properties
    @objc var uniqueID: String           // → event.id.uuidString
    @objc var title: String              // → event.title (get/set)
    @objc var eventDescription: String?  // → event.eventDescription (get/set)
    @objc var startDateString: String    // → event.startDate.isoString (get/set via parsing)
    @objc var endDateString: String?     // → event.endDate?.isoString (get/set via parsing)
    @objc var isPointEvent: Bool         // → event.isPointEvent
    @objc var lane: ScriptableLane?      // → wrap event.lane (get/set)

    // Object specifier (e.g., "timeline event \"Sprint 1\" of document 1")
    override var objectSpecifier: NSScriptObjectSpecifier?
}
```

### Object Specifier Strategy

Each wrapper returns an `NSScriptObjectSpecifier` describing its position in the containment hierarchy:

- **Documents:** `NSNameSpecifier` by display name, container = `NSApp`
- **Lanes:** `NSNameSpecifier` by lane name, container = parent document
- **Events:** `NSUniqueIDSpecifier` by UUID string, container = parent document (or parent lane if accessed through a lane)

Using `NSNameSpecifier` for lanes means lane names should be unique within a document (they are in practice). Events use UUID since titles may not be unique — but `NSNameSpecifier` is also supported as a secondary lookup for convenience (`timeline event "Sprint 1"`).

---

## Implementation Order

### Phase 1: Foundation (no scripting yet)

1. **FlexibleDate ISO string parsing** — Add `init?(isoString:)` and `isoString` computed property. Add unit tests.

### Phase 2: Scripting Infrastructure

2. **DocumentRegistry** — Singleton with register/unregister/lookup.
3. **ContentView registration** — Hook `.onAppear`/`.onDisappear` to register ModelContext.
4. **Info.plist changes** — Enable AppleScript, declare SDEF.

### Phase 3: SDEF + Wrappers

5. **Timeliner.sdef** — Full scripting dictionary.
6. **NSApplication+Scripting** — `scriptableDocuments` KVC accessor.
7. **ScriptableDocument** — With lanes/events element access, object specifier.
8. **ScriptableLane** — Full KVC properties, element access, object specifier.
9. **ScriptableEvent** — Full KVC properties, object specifier.

### Phase 4: Commands

10. **CreateDocumentCommand** — `make new document` support.
11. **Make/delete for lanes and events** — Insert/remove KVC methods on containers.

### Phase 5: Testing

12. **AppleScript integration tests** — Shell scripts using `osascript` that exercise the full API.
13. **Edge cases** — Empty documents, untitled documents, date precision boundaries, invalid input error handling.

---

## Swift 6 Concurrency Considerations

- All scriptable wrappers are `@MainActor` since they access SwiftData's `ModelContext` (which is main-actor-isolated).
- Apple Events are delivered on the main thread, so Cocoa Scripting command handlers run on `@MainActor` naturally.
- `DocumentRegistry` is `@MainActor` isolated.
- The `@objc dynamic` properties required for KVC are compatible with `@MainActor` classes.
- `NSScriptCommand` subclasses should perform work synchronously on the main thread (no async/await needed).

---

## Error Handling

AppleScript errors should be reported via `NSScriptCommand.scriptErrorNumber` and `scriptErrorString`:

| Scenario | Error Number | Message |
|----------|-------------|---------|
| Invalid date string | 1001 | `"Invalid date format. Use YYYY, YYYY-MM, YYYY-MM-DD, or YYYY-MM-DDThh:mm"` |
| Document not found | 1002 | `"No document with that name is open"` |
| Lane not found | 1003 | `"No lane with that name exists in the document"` |
| Event not found | 1004 | `"No event with that identifier exists"` |
| End date before start | 1005 | `"End date must be after start date"` |

---

## Testing Strategy

### Unit Tests (Swift Testing)

- `FlexibleDate.init?(isoString:)` — all precision levels, edge cases, invalid input
- `FlexibleDate.isoString` — round-trip for all precision levels
- `DocumentRegistry` — register, unregister, lookup

### Integration Tests (osascript)

Shell scripts that launch the app, run AppleScript commands, and verify results:

```bash
# Test: create document, add lane, add event, query
osascript -e '
tell application "Timeliner"
    set d to make new document
    tell d
        make new lane with properties {name:"Test", color:"#FF0000"}
        make new timeline event with properties {title:"E1", start date:"2026-01-01", lane:lane "Test"}
        return title of every timeline event
    end tell
end tell
'
# Expected: {"E1"}
```

### Manual Testing Checklist

- [ ] Create document from script, verify it appears in app
- [ ] Add lanes and events, verify they render on the timeline
- [ ] Modify event properties via script, verify changes reflect in UI
- [ ] Delete events/lanes via script, verify removal
- [ ] Open existing .timeliner file, verify scripting can access its contents
- [ ] Multiple documents open simultaneously, verify correct targeting
- [ ] Year/month/day/time precision events created correctly
- [ ] Invalid date strings produce clear errors
- [ ] `every event whose title contains "..."` filtering works
- [ ] `count` and `exists` commands work
- [ ] Save via script writes to disk correctly

---

## Known Challenges & Mitigations

### 1. SwiftUI DocumentGroup ↔ Cocoa Scripting Impedance Mismatch

SwiftUI's DocumentGroup hides NSDocument from us. The registry pattern works around this but requires careful matching between NSDocument instances and registered ModelContexts.

**Mitigation:** Match by file URL for saved documents. For untitled documents, maintain a registration order and match against NSDocumentController's untitled document list.

### 2. Registration Timing for New Documents

When `make new document` creates a document, the ContentView's `.onAppear` may fire asynchronously. The scripting command needs the ModelContext to be registered before it can return the new document.

**Mitigation:** Use a `DispatchSemaphore` or `RunLoop` spin in the command handler with a short timeout (e.g., 1 second). DocumentRegistry posts a notification on registration that the command handler waits for.

### 3. Wrapper Object Lifecycle

Scriptable wrappers are created on-the-fly when KVC accessors are called. If AppleScript holds a reference to a wrapper and the underlying SwiftData model is deleted, the wrapper becomes stale.

**Mitigation:** Check model validity in KVC accessors. Return errors for stale references. Consider caching wrappers per document session keyed by model UUID to ensure identity stability.

### 4. Lane Name Uniqueness

`NSNameSpecifier` for lanes assumes unique names within a document. The current data model doesn't enforce this.

**Mitigation:** When resolving by name, return the first match. Document this behavior. Optionally add a uniqueness constraint to Lane.name in a future schema migration.

### 5. `whose` Clause Filtering on Dates

AppleScript `whose` clauses like `every event whose start date > "2026-03"` rely on string comparison, which happens to work correctly for ISO-format date strings (lexicographic order matches chronological order). However, mixed-precision comparisons (e.g., `"2026" > "2026-03"`) may produce unexpected results.

**Mitigation:** Document that date comparisons in `whose` clauses use string ordering. For precise date filtering, recommend comparing at the same precision level.

### 6. App Sandbox

The app runs in a sandbox with User Selected Files (read/write). AppleScript `save ... in` commands need the target path to be accessible. Since AppleScript operations run within the app's sandbox, file access may be restricted.

**Mitigation:** The `save` command goes through NSDocument's standard save infrastructure, which presents save panels when needed. For scripted `save in`, the app may need a temporary security-scoped bookmark or the user may need to have previously granted access to the target directory. Test this carefully.
