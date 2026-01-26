# Timeline Core Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the core data model, document persistence, and timeline UI display layer for Timeliner v1.

**Architecture:** SwiftData models (`TimelineEvent`, `Lane`, `Tag`) with `FlexibleDate` as a `Codable` struct stored as transformable. Document packages use `.timeliner` extension. UI is a horizontal scrollable timeline with stacked lane rows.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing

---

## Task 1: FlexibleDate Type

**Files:**
- Create: `Timeliner/Models/FlexibleDate.swift`
- Create: `TimelinerTests/FlexibleDateTests.swift`

**Step 1: Create the Models directory**

```bash
mkdir -p Timeliner/Models
```

Then add the folder to Xcode project (or it will compile automatically if using folder references).

**Step 2: Write the failing test for FlexibleDate initialization**

Create `TimelinerTests/FlexibleDateTests.swift`:

```swift
//
//  FlexibleDateTests.swift
//  TimelinerTests
//

import Testing
@testable import Timeliner

struct FlexibleDateTests {

    @Test func yearOnlyPrecision() {
        let date = FlexibleDate(year: 1776)
        #expect(date.year == 1776)
        #expect(date.month == nil)
        #expect(date.day == nil)
        #expect(date.hour == nil)
        #expect(date.minute == nil)
        #expect(date.precision == .year)
    }

    @Test func monthPrecision() {
        let date = FlexibleDate(year: 1776, month: 7)
        #expect(date.precision == .month)
    }

    @Test func dayPrecision() {
        let date = FlexibleDate(year: 1776, month: 7, day: 4)
        #expect(date.precision == .day)
    }

    @Test func timePrecision() {
        let date = FlexibleDate(year: 1776, month: 7, day: 4, hour: 14, minute: 30)
        #expect(date.precision == .time)
    }
}
```

**Step 3: Run test to verify it fails**

```bash
cd /Users/ctp/Desktop/Local\ Sources/Timeliner
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/FlexibleDateTests 2>&1 | tail -20
```

Expected: Build failure — `FlexibleDate` not found.

**Step 4: Implement FlexibleDate**

Create `Timeliner/Models/FlexibleDate.swift`:

```swift
//
//  FlexibleDate.swift
//  Timeliner
//

import Foundation

enum DatePrecision: Int, Codable, Comparable {
    case year = 0
    case month = 1
    case day = 2
    case time = 3

    static func < (lhs: DatePrecision, rhs: DatePrecision) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct FlexibleDate: Codable, Hashable, Sendable {
    let year: Int
    let month: Int?
    let day: Int?
    let hour: Int?
    let minute: Int?

    init(year: Int, month: Int? = nil, day: Int? = nil, hour: Int? = nil, minute: Int? = nil) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }

    var precision: DatePrecision {
        if hour != nil || minute != nil {
            return .time
        } else if day != nil {
            return .day
        } else if month != nil {
            return .month
        } else {
            return .year
        }
    }
}
```

**Step 5: Run test to verify it passes**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/FlexibleDateTests 2>&1 | tail -20
```

Expected: All tests pass.

**Step 6: Add asDate computed property test**

Add to `FlexibleDateTests.swift`:

```swift
@Test func asDateYearOnly() {
    let flexDate = FlexibleDate(year: 2000)
    let date = flexDate.asDate
    let calendar = Calendar(identifier: .gregorian)
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    #expect(components.year == 2000)
    #expect(components.month == 1)
    #expect(components.day == 1)
}

@Test func asDateFullPrecision() {
    let flexDate = FlexibleDate(year: 2000, month: 6, day: 15, hour: 10, minute: 30)
    let date = flexDate.asDate
    let calendar = Calendar(identifier: .gregorian)
    var expectedComponents = DateComponents()
    expectedComponents.year = 2000
    expectedComponents.month = 6
    expectedComponents.day = 15
    expectedComponents.hour = 10
    expectedComponents.minute = 30
    expectedComponents.timeZone = TimeZone(identifier: "UTC")
    let expectedDate = calendar.date(from: expectedComponents)!
    #expect(date == expectedDate)
}
```

**Step 7: Run test to verify it fails**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/FlexibleDateTests 2>&1 | tail -20
```

Expected: Fail — `asDate` not found.

**Step 8: Implement asDate**

Add to `FlexibleDate` struct in `FlexibleDate.swift`:

```swift
var asDate: Date {
    var components = DateComponents()
    components.year = year
    components.month = month ?? 1
    components.day = day ?? 1
    components.hour = hour ?? 0
    components.minute = minute ?? 0
    components.second = 0
    components.timeZone = TimeZone(identifier: "UTC")
    let calendar = Calendar(identifier: .gregorian)
    return calendar.date(from: components) ?? Date.distantPast
}
```

**Step 9: Run test to verify it passes**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/FlexibleDateTests 2>&1 | tail -20
```

Expected: All tests pass.

**Step 10: Add Comparable conformance test**

Add to `FlexibleDateTests.swift`:

```swift
@Test func comparableDifferentYears() {
    let earlier = FlexibleDate(year: 1900)
    let later = FlexibleDate(year: 2000)
    #expect(earlier < later)
}

@Test func comparableSameYearDifferentMonth() {
    let earlier = FlexibleDate(year: 2000, month: 3)
    let later = FlexibleDate(year: 2000, month: 7)
    #expect(earlier < later)
}
```

**Step 11: Implement Comparable**

Add conformance to `FlexibleDate`:

```swift
extension FlexibleDate: Comparable {
    static func < (lhs: FlexibleDate, rhs: FlexibleDate) -> Bool {
        lhs.asDate < rhs.asDate
    }
}
```

**Step 12: Run all FlexibleDate tests**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/FlexibleDateTests 2>&1 | tail -20
```

Expected: All tests pass.

**Step 13: Commit**

```bash
git add Timeliner/Models/FlexibleDate.swift TimelinerTests/FlexibleDateTests.swift
git commit -m "feat: add FlexibleDate type with variable precision support"
```

---

## Task 2: Tag Model

**Files:**
- Create: `Timeliner/Models/Tag.swift`
- Create: `TimelinerTests/TagTests.swift`

**Step 1: Write the failing test**

Create `TimelinerTests/TagTests.swift`:

```swift
//
//  TagTests.swift
//  TimelinerTests
//

import Testing
import SwiftData
@testable import Timeliner

struct TagTests {

    @Test func tagInitialization() {
        let tag = Tag(name: "Work")
        #expect(tag.name == "Work")
        #expect(tag.color == nil)
        #expect(tag.id != UUID())
    }

    @Test func tagWithColor() {
        let tag = Tag(name: "Personal", color: "#FF5733")
        #expect(tag.name == "Personal")
        #expect(tag.color == "#FF5733")
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TagTests 2>&1 | tail -20
```

Expected: Build failure — `Tag` not found.

**Step 3: Implement Tag model**

Create `Timeliner/Models/Tag.swift`:

```swift
//
//  Tag.swift
//  Timeliner
//

import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String?

    @Relationship(inverse: \TimelineEvent.tags)
    var events: [TimelineEvent] = []

    init(name: String, color: String? = nil) {
        self.id = UUID()
        self.name = name
        self.color = color
    }
}
```

Note: This will fail to compile until `TimelineEvent` exists. We'll create a minimal stub.

**Step 4: Create TimelineEvent stub**

Create `Timeliner/Models/TimelineEvent.swift` (minimal for now):

```swift
//
//  TimelineEvent.swift
//  Timeliner
//

import Foundation
import SwiftData

@Model
final class TimelineEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var tags: [Tag] = []

    init(title: String) {
        self.id = UUID()
        self.title = title
    }
}
```

**Step 5: Run test to verify it passes**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TagTests 2>&1 | tail -20
```

Expected: All tests pass.

**Step 6: Commit**

```bash
git add Timeliner/Models/Tag.swift Timeliner/Models/TimelineEvent.swift TimelinerTests/TagTests.swift
git commit -m "feat: add Tag model with SwiftData persistence"
```

---

## Task 3: Lane Model

**Files:**
- Create: `Timeliner/Models/Lane.swift`
- Create: `TimelinerTests/LaneTests.swift`

**Step 1: Write the failing test**

Create `TimelinerTests/LaneTests.swift`:

```swift
//
//  LaneTests.swift
//  TimelinerTests
//

import Testing
import SwiftData
@testable import Timeliner

struct LaneTests {

    @Test func laneInitialization() {
        let lane = Lane(name: "Career", color: "#3498DB")
        #expect(lane.name == "Career")
        #expect(lane.color == "#3498DB")
        #expect(lane.sortOrder == 0)
        #expect(lane.events.isEmpty)
    }

    @Test func laneWithSortOrder() {
        let lane = Lane(name: "Personal", color: "#E74C3C", sortOrder: 5)
        #expect(lane.sortOrder == 5)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/LaneTests 2>&1 | tail -20
```

Expected: Build failure — `Lane` not found.

**Step 3: Implement Lane model**

Create `Timeliner/Models/Lane.swift`:

```swift
//
//  Lane.swift
//  Timeliner
//

import Foundation
import SwiftData

@Model
final class Lane {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String
    var sortOrder: Int

    @Relationship(inverse: \TimelineEvent.lane)
    var events: [TimelineEvent] = []

    init(name: String, color: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
    }
}
```

**Step 4: Update TimelineEvent with lane relationship**

Update `Timeliner/Models/TimelineEvent.swift` to add the lane property:

```swift
//
//  TimelineEvent.swift
//  Timeliner
//

import Foundation
import SwiftData

@Model
final class TimelineEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var lane: Lane?
    var tags: [Tag] = []

    init(title: String, lane: Lane? = nil) {
        self.id = UUID()
        self.title = title
        self.lane = lane
    }
}
```

**Step 5: Run test to verify it passes**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/LaneTests 2>&1 | tail -20
```

Expected: All tests pass.

**Step 6: Commit**

```bash
git add Timeliner/Models/Lane.swift Timeliner/Models/TimelineEvent.swift TimelinerTests/LaneTests.swift
git commit -m "feat: add Lane model with sortOrder and events relationship"
```

---

## Task 4: Complete TimelineEvent Model

**Files:**
- Modify: `Timeliner/Models/TimelineEvent.swift`
- Create: `TimelinerTests/TimelineEventTests.swift`

**Step 1: Write comprehensive tests**

Create `TimelinerTests/TimelineEventTests.swift`:

```swift
//
//  TimelineEventTests.swift
//  TimelinerTests
//

import Testing
import SwiftData
@testable import Timeliner

struct TimelineEventTests {

    @Test func pointEventInitialization() {
        let startDate = FlexibleDate(year: 1969, month: 7, day: 20)
        let event = TimelineEvent(title: "Moon Landing", startDate: startDate)

        #expect(event.title == "Moon Landing")
        #expect(event.startDate.year == 1969)
        #expect(event.endDate == nil)
        #expect(event.isPointEvent == true)
    }

    @Test func spanEventInitialization() {
        let startDate = FlexibleDate(year: 1939, month: 9, day: 1)
        let endDate = FlexibleDate(year: 1945, month: 9, day: 2)
        let event = TimelineEvent(title: "World War II", startDate: startDate, endDate: endDate)

        #expect(event.isPointEvent == false)
        #expect(event.endDate?.year == 1945)
    }

    @Test func eventWithDescription() {
        let startDate = FlexibleDate(year: 2000)
        let event = TimelineEvent(
            title: "Y2K",
            eventDescription: "The millennium bug scare",
            startDate: startDate
        )

        #expect(event.eventDescription == "The millennium bug scare")
    }

    @Test func eventMetadataTimestamps() {
        let startDate = FlexibleDate(year: 2020)
        let event = TimelineEvent(title: "Test", startDate: startDate)

        #expect(event.createdAt <= Date())
        #expect(event.modifiedAt <= Date())
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineEventTests 2>&1 | tail -20
```

Expected: Fail — missing properties.

**Step 3: Implement complete TimelineEvent**

Replace `Timeliner/Models/TimelineEvent.swift`:

```swift
//
//  TimelineEvent.swift
//  Timeliner
//

import Foundation
import SwiftData

@Model
final class TimelineEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var eventDescription: String?

    // Stored as JSON-encoded data since FlexibleDate is a struct
    private var startDateData: Data
    private var endDateData: Data?

    var lane: Lane?
    var tags: [Tag] = []

    var createdAt: Date
    var modifiedAt: Date

    var startDate: FlexibleDate {
        get {
            (try? JSONDecoder().decode(FlexibleDate.self, from: startDateData))
                ?? FlexibleDate(year: 1970)
        }
        set {
            startDateData = (try? JSONEncoder().encode(newValue)) ?? Data()
            modifiedAt = Date()
        }
    }

    var endDate: FlexibleDate? {
        get {
            guard let data = endDateData else { return nil }
            return try? JSONDecoder().decode(FlexibleDate.self, from: data)
        }
        set {
            endDateData = newValue.flatMap { try? JSONEncoder().encode($0) }
            modifiedAt = Date()
        }
    }

    var isPointEvent: Bool {
        endDate == nil
    }

    init(
        title: String,
        eventDescription: String? = nil,
        startDate: FlexibleDate,
        endDate: FlexibleDate? = nil,
        lane: Lane? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.eventDescription = eventDescription
        self.startDateData = (try? JSONEncoder().encode(startDate)) ?? Data()
        self.endDateData = endDate.flatMap { try? JSONEncoder().encode($0) }
        self.lane = lane
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
```

**Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineEventTests 2>&1 | tail -20
```

Expected: All tests pass.

**Step 5: Commit**

```bash
git add Timeliner/Models/TimelineEvent.swift TimelinerTests/TimelineEventTests.swift
git commit -m "feat: complete TimelineEvent model with FlexibleDate support"
```

---

## Task 5: Update Document Configuration

**Files:**
- Modify: `Timeliner/TimelinerApp.swift`
- Modify: `Timeliner/Info.plist`
- Delete: `Timeliner/Item.swift`

**Step 1: Update TimelinerApp.swift**

Replace `Timeliner/TimelinerApp.swift`:

```swift
//
//  TimelinerApp.swift
//  Timeliner
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct TimelinerApp: App {
    var body: some Scene {
        DocumentGroup(editing: .timelinerDocument, migrationPlan: TimelinerMigrationPlan.self) {
            ContentView()
        }
    }
}

extension UTType {
    static var timelinerDocument: UTType {
        UTType(importedAs: "com.timeliner.document")
    }
}

struct TimelinerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [
        TimelinerVersionedSchema.self,
    ]

    static var stages: [MigrationStage] = []
}

struct TimelinerVersionedSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        TimelineEvent.self,
        Lane.self,
        Tag.self,
    ]
}
```

**Step 2: Update Info.plist**

Replace `Timeliner/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>LSHandlerRank</key>
			<string>Owner</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>com.timeliner.document</string>
			</array>
			<key>NSUbiquitousDocumentUserActivityType</key>
			<string>$(PRODUCT_BUNDLE_IDENTIFIER).timeliner</string>
		</dict>
	</array>
	<key>UTImportedTypeDeclarations</key>
	<array>
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>com.apple.package</string>
			</array>
			<key>UTTypeDescription</key>
			<string>Timeliner Document</string>
			<key>UTTypeIdentifier</key>
			<string>com.timeliner.document</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>timeliner</string>
				</array>
			</dict>
		</dict>
	</array>
</dict>
</plist>
```

**Step 3: Delete Item.swift**

```bash
rm Timeliner/Item.swift
```

**Step 4: Build to verify configuration**

```bash
xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: Build succeeds.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: configure document type for .timeliner extension"
```

---

## Task 6: TimelineViewport State

**Files:**
- Create: `Timeliner/Views/TimelineViewport.swift`
- Create: `TimelinerTests/TimelineViewportTests.swift`

**Step 1: Create Views directory**

```bash
mkdir -p Timeliner/Views
```

**Step 2: Write the failing test**

Create `TimelinerTests/TimelineViewportTests.swift`:

```swift
//
//  TimelineViewportTests.swift
//  TimelinerTests
//

import Testing
import Foundation
@testable import Timeliner

struct TimelineViewportTests {

    @Test func defaultViewport() {
        let viewport = TimelineViewport()
        #expect(viewport.scale > 0)
        #expect(viewport.centerDate <= Date())
    }

    @Test func viewportVisibleRange() {
        let center = Date()
        let viewport = TimelineViewport(centerDate: center, scale: 86400, viewportWidth: 1000)
        let range = viewport.visibleRange

        // With scale of 86400 seconds/point and 1000pt width,
        // visible range should be ~1000 days
        let duration = range.upperBound.timeIntervalSince(range.lowerBound)
        #expect(duration > 86400 * 900) // At least 900 days
        #expect(duration < 86400 * 1100) // At most 1100 days
    }

    @Test func dateToXPosition() {
        let center = Date(timeIntervalSinceReferenceDate: 0)
        let viewport = TimelineViewport(centerDate: center, scale: 1, viewportWidth: 100)

        // Center date should be at center of viewport
        let centerX = viewport.xPosition(for: center)
        #expect(centerX == 50)

        // 10 seconds later should be 10 points to the right
        let laterDate = Date(timeIntervalSinceReferenceDate: 10)
        let laterX = viewport.xPosition(for: laterDate)
        #expect(laterX == 60)
    }

    @Test func xPositionToDate() {
        let center = Date(timeIntervalSinceReferenceDate: 0)
        let viewport = TimelineViewport(centerDate: center, scale: 1, viewportWidth: 100)

        let dateAtCenter = viewport.date(forX: 50)
        #expect(abs(dateAtCenter.timeIntervalSinceReferenceDate) < 0.001)

        let dateAtRight = viewport.date(forX: 60)
        #expect(abs(dateAtRight.timeIntervalSinceReferenceDate - 10) < 0.001)
    }
}
```

**Step 3: Run test to verify it fails**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineViewportTests 2>&1 | tail -20
```

Expected: Build failure — `TimelineViewport` not found.

**Step 4: Implement TimelineViewport**

Create `Timeliner/Views/TimelineViewport.swift`:

```swift
//
//  TimelineViewport.swift
//  Timeliner
//

import Foundation

struct TimelineViewport: Equatable, Sendable {
    /// The date at the center of the viewport
    var centerDate: Date

    /// Seconds per point — higher values show more time in the same space (zoomed out)
    var scale: TimeInterval

    /// Width of the viewport in points
    var viewportWidth: CGFloat

    init(
        centerDate: Date = Date(),
        scale: TimeInterval = 86400, // 1 day per point default
        viewportWidth: CGFloat = 1000
    ) {
        self.centerDate = centerDate
        self.scale = max(scale, 1) // Minimum 1 second per point
        self.viewportWidth = viewportWidth
    }

    /// The range of dates currently visible
    var visibleRange: ClosedRange<Date> {
        let halfWidth = viewportWidth / 2
        let halfDuration = TimeInterval(halfWidth) * scale
        let start = centerDate.addingTimeInterval(-halfDuration)
        let end = centerDate.addingTimeInterval(halfDuration)
        return start...end
    }

    /// Convert a date to an x position in the viewport
    func xPosition(for date: Date) -> CGFloat {
        let secondsFromCenter = date.timeIntervalSince(centerDate)
        let pointsFromCenter = secondsFromCenter / scale
        return (viewportWidth / 2) + CGFloat(pointsFromCenter)
    }

    /// Convert an x position to a date
    func date(forX x: CGFloat) -> Date {
        let pointsFromCenter = x - (viewportWidth / 2)
        let secondsFromCenter = TimeInterval(pointsFromCenter) * scale
        return centerDate.addingTimeInterval(secondsFromCenter)
    }
}
```

**Step 5: Run test to verify it passes**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' -only-testing:TimelinerTests/TimelineViewportTests 2>&1 | tail -20
```

Expected: All tests pass.

**Step 6: Commit**

```bash
git add Timeliner/Views/TimelineViewport.swift TimelinerTests/TimelineViewportTests.swift
git commit -m "feat: add TimelineViewport for coordinate transformation"
```

---

## Task 7: TimeAxisView

**Files:**
- Create: `Timeliner/Views/TimeAxisView.swift`

**Step 1: Implement TimeAxisView**

Create `Timeliner/Views/TimeAxisView.swift`:

```swift
//
//  TimeAxisView.swift
//  Timeliner
//

import SwiftUI

struct TimeAxisView: View {
    let viewport: TimelineViewport

    var body: some View {
        Canvas { context, size in
            let ticks = calculateTicks(for: viewport, width: size.width)

            for tick in ticks {
                let x = viewport.xPosition(for: tick.date)
                guard x >= 0 && x <= size.width else { continue }

                // Draw tick line
                let tickHeight: CGFloat = tick.isMajor ? 12 : 6
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height - tickHeight))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.secondary), lineWidth: 1)

                // Draw label for major ticks
                if tick.isMajor {
                    let text = Text(tick.label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    context.draw(text, at: CGPoint(x: x, y: size.height - tickHeight - 8))
                }
            }
        }
        .frame(height: 30)
    }

    private func calculateTicks(for viewport: TimelineViewport, width: CGFloat) -> [Tick] {
        var ticks: [Tick] = []
        let range = viewport.visibleRange
        let calendar = Calendar.current

        // Determine tick interval based on scale
        let interval = tickInterval(for: viewport.scale)

        // Find first tick at or before range start
        var currentDate = calendar.startOfDay(for: range.lowerBound)
        if let rounded = roundDown(date: currentDate, to: interval, calendar: calendar) {
            currentDate = rounded
        }

        // Generate ticks
        while currentDate <= range.upperBound {
            let isMajor = isMajorTick(date: currentDate, interval: interval, calendar: calendar)
            let label = formatTickLabel(date: currentDate, interval: interval)
            ticks.append(Tick(date: currentDate, label: label, isMajor: isMajor))

            if let next = advanceDate(currentDate, by: interval, calendar: calendar) {
                currentDate = next
            } else {
                break
            }
        }

        return ticks
    }

    private enum TickInterval {
        case hour, day, week, month, year, decade
    }

    private func tickInterval(for scale: TimeInterval) -> TickInterval {
        switch scale {
        case ..<3600: return .hour
        case ..<86400: return .day
        case ..<604800: return .week
        case ..<2592000: return .month
        case ..<31536000: return .year
        default: return .decade
        }
    }

    private func roundDown(date: Date, to interval: TickInterval, calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        var newComponents = DateComponents()
        newComponents.year = components.year

        switch interval {
        case .hour:
            newComponents.month = components.month
            newComponents.day = components.day
            newComponents.hour = components.hour
        case .day, .week:
            newComponents.month = components.month
            newComponents.day = components.day
        case .month:
            newComponents.month = components.month
        case .year, .decade:
            break
        }

        return calendar.date(from: newComponents)
    }

    private func advanceDate(_ date: Date, by interval: TickInterval, calendar: Calendar) -> Date? {
        switch interval {
        case .hour: return calendar.date(byAdding: .hour, value: 1, to: date)
        case .day: return calendar.date(byAdding: .day, value: 1, to: date)
        case .week: return calendar.date(byAdding: .day, value: 7, to: date)
        case .month: return calendar.date(byAdding: .month, value: 1, to: date)
        case .year: return calendar.date(byAdding: .year, value: 1, to: date)
        case .decade: return calendar.date(byAdding: .year, value: 10, to: date)
        }
    }

    private func isMajorTick(date: Date, interval: TickInterval, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.month, .day, .hour, .weekday], from: date)
        switch interval {
        case .hour: return components.hour == 0
        case .day: return components.weekday == 1 // Sunday
        case .week: return components.day == 1
        case .month: return components.month == 1
        case .year: return (calendar.component(.year, from: date) % 10) == 0
        case .decade: return (calendar.component(.year, from: date) % 100) == 0
        }
    }

    private func formatTickLabel(date: Date, interval: TickInterval) -> String {
        let formatter = DateFormatter()
        switch interval {
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .day, .week:
            formatter.dateFormat = "MMM d"
        case .month:
            formatter.dateFormat = "MMM yyyy"
        case .year, .decade:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }
}

private struct Tick {
    let date: Date
    let label: String
    let isMajor: Bool
}

#Preview {
    TimeAxisView(viewport: TimelineViewport(
        centerDate: Date(),
        scale: 86400,
        viewportWidth: 800
    ))
    .frame(width: 800)
    .padding()
}
```

**Step 2: Build to verify**

```bash
xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Timeliner/Views/TimeAxisView.swift
git commit -m "feat: add TimeAxisView with adaptive tick intervals"
```

---

## Task 8: EventView

**Files:**
- Create: `Timeliner/Views/EventView.swift`

**Step 1: Implement EventView**

Create `Timeliner/Views/EventView.swift`:

```swift
//
//  EventView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct EventView: View {
    let event: TimelineEvent
    let viewport: TimelineViewport
    let isSelected: Bool
    let onSelect: () -> Void

    private let eventHeight: CGFloat = 24

    var body: some View {
        Group {
            if event.isPointEvent {
                pointEventView
            } else {
                spanEventView
            }
        }
        .onTapGesture {
            onSelect()
        }
    }

    private var pointEventView: some View {
        let x = viewport.xPosition(for: event.startDate.asDate)

        return ZStack {
            Circle()
                .fill(eventColor)
                .frame(width: 12, height: 12)

            if isSelected {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: 16, height: 16)
            }
        }
        .position(x: x, y: eventHeight / 2)
    }

    private var spanEventView: some View {
        let startX = viewport.xPosition(for: event.startDate.asDate)
        let endX = event.endDate.map { viewport.xPosition(for: $0.asDate) } ?? startX
        let width = max(endX - startX, 20) // Minimum width for visibility

        return RoundedRectangle(cornerRadius: 4)
            .fill(eventColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .overlay(
                Text(event.title)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .foregroundColor(.white),
                alignment: .leading
            )
            .frame(width: width, height: eventHeight)
            .position(x: startX + width / 2, y: eventHeight / 2)
    }

    private var eventColor: Color {
        if let lane = event.lane, let hex = Color(hex: lane.color) {
            return hex
        }
        return .blue
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    let event = TimelineEvent(
        title: "Test Event",
        startDate: FlexibleDate(year: 2024, month: 6, day: 15)
    )
    return EventView(
        event: event,
        viewport: TimelineViewport(centerDate: Date(), scale: 86400, viewportWidth: 400),
        isSelected: false,
        onSelect: {}
    )
    .frame(width: 400, height: 50)
}
```

**Step 2: Build to verify**

```bash
xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Timeliner/Views/EventView.swift
git commit -m "feat: add EventView for point and span events"
```

---

## Task 9: LaneRowView

**Files:**
- Create: `Timeliner/Views/LaneRowView.swift`

**Step 1: Implement LaneRowView**

Create `Timeliner/Views/LaneRowView.swift`:

```swift
//
//  LaneRowView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct LaneRowView: View {
    let lane: Lane
    let viewport: TimelineViewport
    let selectedEventID: UUID?
    let onSelectEvent: (TimelineEvent) -> Void

    private let rowHeight: CGFloat = 40

    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(laneBackgroundColor)

            // Lane label
            Text(lane.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Events
            ForEach(lane.events, id: \.id) { event in
                EventView(
                    event: event,
                    viewport: viewport,
                    isSelected: event.id == selectedEventID,
                    onSelect: { onSelectEvent(event) }
                )
            }
        }
        .frame(height: rowHeight)
        .clipped()
    }

    private var laneBackgroundColor: Color {
        if let hex = Color(hex: lane.color) {
            return hex.opacity(0.1)
        }
        return Color.gray.opacity(0.1)
    }
}

#Preview {
    let lane = Lane(name: "Career", color: "#3498DB")
    return LaneRowView(
        lane: lane,
        viewport: TimelineViewport(),
        selectedEventID: nil,
        onSelectEvent: { _ in }
    )
    .frame(width: 600)
}
```

**Step 2: Build to verify**

```bash
xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Timeliner/Views/LaneRowView.swift
git commit -m "feat: add LaneRowView for displaying lane with events"
```

---

## Task 10: TimelineCanvasView

**Files:**
- Create: `Timeliner/Views/TimelineCanvasView.swift`

**Step 1: Implement TimelineCanvasView**

Create `Timeliner/Views/TimelineCanvasView.swift`:

```swift
//
//  TimelineCanvasView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct TimelineCanvasView: View {
    @Query(sort: \Lane.sortOrder) private var lanes: [Lane]
    @Query private var unassignedEvents: [TimelineEvent]

    @State private var viewport: TimelineViewport
    @State private var selectedEventID: UUID?
    @State private var isDragging = false
    @State private var dragStartCenter: Date?

    init() {
        _viewport = State(initialValue: TimelineViewport(
            centerDate: Date(),
            scale: 86400 * 30, // ~1 month per point initially
            viewportWidth: 800
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Time axis
                TimeAxisView(viewport: viewportWithWidth(geometry.size.width))

                Divider()

                // Lanes
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 1) {
                        ForEach(lanes, id: \.id) { lane in
                            LaneRowView(
                                lane: lane,
                                viewport: viewportWithWidth(geometry.size.width),
                                selectedEventID: selectedEventID,
                                onSelectEvent: { event in
                                    selectedEventID = event.id
                                }
                            )
                        }

                        // Unassigned events lane
                        if !eventsWithoutLane.isEmpty {
                            unassignedLaneView(width: geometry.size.width)
                        }
                    }
                }
            }
            .gesture(panGesture(width: geometry.size.width))
            .gesture(magnificationGesture)
            .onAppear {
                viewport.viewportWidth = geometry.size.width
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                viewport.viewportWidth = newWidth
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func viewportWithWidth(_ width: CGFloat) -> TimelineViewport {
        var v = viewport
        v.viewportWidth = width
        return v
    }

    private var eventsWithoutLane: [TimelineEvent] {
        unassignedEvents.filter { $0.lane == nil }
    }

    private func unassignedLaneView(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.05))

            Text("Unassigned")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)

            ForEach(eventsWithoutLane, id: \.id) { event in
                EventView(
                    event: event,
                    viewport: viewportWithWidth(width),
                    isSelected: event.id == selectedEventID,
                    onSelect: { selectedEventID = event.id }
                )
            }
        }
        .frame(height: 40)
    }

    private func panGesture(width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartCenter = viewport.centerDate
                }

                guard let startCenter = dragStartCenter else { return }
                let deltaX = value.translation.width
                let deltaSeconds = TimeInterval(-deltaX) * viewport.scale
                viewport.centerDate = startCenter.addingTimeInterval(deltaSeconds)
            }
            .onEnded { _ in
                isDragging = false
                dragStartCenter = nil
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // Zoom: smaller scale = zoomed in, larger scale = zoomed out
                let factor = 1.0 / value
                viewport.scale = max(1, min(viewport.scale * factor, 86400 * 365 * 100)) // 1 sec to 100 years per point
            }
    }
}

#Preview {
    TimelineCanvasView()
        .modelContainer(for: [TimelineEvent.self, Lane.self, Tag.self], inMemory: true)
        .frame(width: 800, height: 400)
}
```

**Step 2: Build to verify**

```bash
xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Timeliner/Views/TimelineCanvasView.swift
git commit -m "feat: add TimelineCanvasView with pan and zoom gestures"
```

---

## Task 11: Sidebar Views

**Files:**
- Create: `Timeliner/Views/Sidebar/LaneListView.swift`
- Create: `Timeliner/Views/Sidebar/TagListView.swift`

**Step 1: Create Sidebar directory**

```bash
mkdir -p Timeliner/Views/Sidebar
```

**Step 2: Implement LaneListView**

Create `Timeliner/Views/Sidebar/LaneListView.swift`:

```swift
//
//  LaneListView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct LaneListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Lane.sortOrder) private var lanes: [Lane]

    @State private var isAddingLane = false
    @State private var newLaneName = ""
    @State private var newLaneColor = "#3498DB"

    var body: some View {
        Section("Lanes") {
            ForEach(lanes, id: \.id) { lane in
                HStack {
                    Circle()
                        .fill(Color(hex: lane.color) ?? .gray)
                        .frame(width: 12, height: 12)
                    Text(lane.name)
                }
            }
            .onDelete(perform: deleteLanes)
            .onMove(perform: moveLanes)

            if isAddingLane {
                HStack {
                    TextField("Lane name", text: $newLaneName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addLane()
                    }
                    .disabled(newLaneName.isEmpty)

                    Button("Cancel") {
                        isAddingLane = false
                        newLaneName = ""
                    }
                }
            } else {
                Button {
                    isAddingLane = true
                } label: {
                    Label("Add Lane", systemImage: "plus")
                }
            }
        }
    }

    private func addLane() {
        let maxOrder = lanes.map(\.sortOrder).max() ?? -1
        let lane = Lane(name: newLaneName, color: newLaneColor, sortOrder: maxOrder + 1)
        modelContext.insert(lane)
        newLaneName = ""
        isAddingLane = false
    }

    private func deleteLanes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(lanes[index])
        }
    }

    private func moveLanes(from source: IndexSet, to destination: Int) {
        var reorderedLanes = lanes
        reorderedLanes.move(fromOffsets: source, toOffset: destination)

        for (index, lane) in reorderedLanes.enumerated() {
            lane.sortOrder = index
        }
    }
}

#Preview {
    List {
        LaneListView()
    }
    .modelContainer(for: Lane.self, inMemory: true)
}
```

**Step 3: Implement TagListView**

Create `Timeliner/Views/Sidebar/TagListView.swift`:

```swift
//
//  TagListView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct TagListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]

    @Binding var activeTagFilters: Set<UUID>

    @State private var isAddingTag = false
    @State private var newTagName = ""

    var body: some View {
        Section("Tags") {
            ForEach(tags, id: \.id) { tag in
                HStack {
                    Toggle(isOn: binding(for: tag.id)) {
                        HStack {
                            if let color = tag.color, let c = Color(hex: color) {
                                Circle()
                                    .fill(c)
                                    .frame(width: 10, height: 10)
                            }
                            Text(tag.name)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .onDelete(perform: deleteTags)

            if isAddingTag {
                HStack {
                    TextField("Tag name", text: $newTagName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addTag()
                    }
                    .disabled(newTagName.isEmpty)

                    Button("Cancel") {
                        isAddingTag = false
                        newTagName = ""
                    }
                }
            } else {
                Button {
                    isAddingTag = true
                } label: {
                    Label("Add Tag", systemImage: "plus")
                }
            }
        }
    }

    private func binding(for tagID: UUID) -> Binding<Bool> {
        Binding(
            get: { activeTagFilters.contains(tagID) },
            set: { isActive in
                if isActive {
                    activeTagFilters.insert(tagID)
                } else {
                    activeTagFilters.remove(tagID)
                }
            }
        )
    }

    private func addTag() {
        let tag = Tag(name: newTagName)
        modelContext.insert(tag)
        activeTagFilters.insert(tag.id)
        newTagName = ""
        isAddingTag = false
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            activeTagFilters.remove(tag.id)
            modelContext.delete(tag)
        }
    }
}

#Preview {
    @Previewable @State var filters: Set<UUID> = []
    List {
        TagListView(activeTagFilters: $filters)
    }
    .modelContainer(for: Tag.self, inMemory: true)
}
```

**Step 4: Build to verify**

```bash
xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: Build succeeds.

**Step 5: Commit**

```bash
git add Timeliner/Views/Sidebar/
git commit -m "feat: add LaneListView and TagListView sidebar components"
```

---

## Task 12: Update ContentView

**Files:**
- Modify: `Timeliner/ContentView.swift`

**Step 1: Replace ContentView**

Replace `Timeliner/ContentView.swift`:

```swift
//
//  ContentView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeTagFilters: Set<UUID> = []

    var body: some View {
        NavigationSplitView {
            List {
                LaneListView()
                TagListView(activeTagFilters: $activeTagFilters)
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            #endif
            .toolbar {
                ToolbarItem {
                    Button(action: addSampleData) {
                        Label("Add Sample", systemImage: "wand.and.stars")
                    }
                }
            }
        } detail: {
            TimelineCanvasView()
        }
    }

    private func addSampleData() {
        // Create sample lanes
        let workLane = Lane(name: "Work", color: "#3498DB", sortOrder: 0)
        let personalLane = Lane(name: "Personal", color: "#E74C3C", sortOrder: 1)

        modelContext.insert(workLane)
        modelContext.insert(personalLane)

        // Create sample tags
        let importantTag = Tag(name: "Important", color: "#F39C12")
        modelContext.insert(importantTag)

        // Create sample events
        let today = Date()
        let calendar = Calendar.current

        let event1 = TimelineEvent(
            title: "Project Kickoff",
            eventDescription: "Initial planning meeting",
            startDate: FlexibleDate(
                year: calendar.component(.year, from: today),
                month: calendar.component(.month, from: today),
                day: calendar.component(.day, from: today)
            ),
            lane: workLane
        )
        event1.tags = [importantTag]

        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        let event2 = TimelineEvent(
            title: "Sprint 1",
            startDate: FlexibleDate(
                year: calendar.component(.year, from: today),
                month: calendar.component(.month, from: today),
                day: calendar.component(.day, from: today)
            ),
            endDate: FlexibleDate(
                year: calendar.component(.year, from: nextWeek),
                month: calendar.component(.month, from: nextWeek),
                day: calendar.component(.day, from: nextWeek)
            ),
            lane: workLane
        )

        let birthday = TimelineEvent(
            title: "Birthday Party",
            startDate: FlexibleDate(
                year: calendar.component(.year, from: today),
                month: calendar.component(.month, from: today),
                day: calendar.component(.day, from: today) + 3
            ),
            lane: personalLane
        )

        modelContext.insert(event1)
        modelContext.insert(event2)
        modelContext.insert(birthday)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TimelineEvent.self, Lane.self, Tag.self], inMemory: true)
}
```

**Step 2: Build and test**

```bash
xcodebuild build -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: Build succeeds.

**Step 3: Run all tests**

```bash
xcodebuild test -scheme Timeliner -destination 'platform=macOS' 2>&1 | tail -30
```

Expected: All tests pass.

**Step 4: Commit**

```bash
git add Timeliner/ContentView.swift
git commit -m "feat: wire up ContentView with sidebar and TimelineCanvasView"
```

---

## Task 13: Final Integration Test

**Step 1: Run the app**

```bash
xcodebuild build -scheme Timeliner -destination 'platform=macOS' && open ~/Library/Developer/Xcode/DerivedData/Timeliner-*/Build/Products/Debug/Timeliner.app
```

Or open in Xcode and run (Cmd+R).

**Step 2: Verify functionality**

- [ ] App launches and shows document picker
- [ ] Create new document
- [ ] Sidebar shows Lanes and Tags sections
- [ ] Click "Add Sample" to create sample data
- [ ] Timeline displays lanes with events
- [ ] Pan (drag) moves through time
- [ ] Pinch/scroll zooms in/out
- [ ] Add new lanes and tags via sidebar

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore: complete v1 timeline implementation"
```

---

## Summary

| Task | Description |
|------|-------------|
| 1 | FlexibleDate type with variable precision |
| 2 | Tag model |
| 3 | Lane model |
| 4 | Complete TimelineEvent model |
| 5 | Document configuration (.timeliner) |
| 6 | TimelineViewport coordinate transformation |
| 7 | TimeAxisView with adaptive ticks |
| 8 | EventView for point and span events |
| 9 | LaneRowView |
| 10 | TimelineCanvasView with gestures |
| 11 | Sidebar views (LaneListView, TagListView) |
| 12 | Updated ContentView |
| 13 | Integration testing |
