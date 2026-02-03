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
}

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
