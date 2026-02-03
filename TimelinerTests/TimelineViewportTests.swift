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
