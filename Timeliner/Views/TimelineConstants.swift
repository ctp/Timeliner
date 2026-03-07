import CoreGraphics

/// Shared layout constants for the timeline canvas.
/// Centralising these here makes visual tweaks straightforward and avoids
/// duplicating magic numbers across multiple view files.
enum TimelineConstants {
    // MARK: - Row / Lane

    /// Height of one sub-row inside a lane (points).
    static let baseRowHeight: CGFloat = 40

    // MARK: - Events

    /// Height of a span-event bar (points).
    static let eventHeight: CGFloat = 24

    /// Corner radius applied to span-event rounded rectangles.
    static let spanCornerRadius: CGFloat = 4

    /// Minimum rendered width for a span event (points).
    static let minEventWidth: CGFloat = 20

    /// Width added to a point event's startX to give it a collision footprint
    /// in the layout algorithm (so spans don't overlap the dot).
    static let pointEventCollisionWidth: CGFloat = 16

    /// Diameter of the point-event dot circle.
    static let pointEventDotSize: CGFloat = 12

    /// Width of the transparent hit zone at each edge of a span event
    /// used to detect resize-drag intent.
    static let edgeHitZone: CGFloat = 6

    // MARK: - Connection Lines

    /// Stroke width for railroad-track connection lines.
    static let connectionLineWidth: CGFloat = 3

    // MARK: - Lane Color Circles

    /// Diameter of the small lane-color indicator circles shown in the
    /// sidebar and inspector (points).
    static let laneColorCircleSize: CGFloat = 12
}
