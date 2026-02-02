//
//  TimelineViewport.swift
//  Timeliner
//

import Foundation

struct TimelineViewport: Equatable, Hashable, Sendable {
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
