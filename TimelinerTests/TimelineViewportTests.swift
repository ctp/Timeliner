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
