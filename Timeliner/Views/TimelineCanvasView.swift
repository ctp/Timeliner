//
//  TimelineCanvasView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct TimelineCanvasView: View {
    @Query(sort: \Lane.sortOrder) private var lanes: [Lane]
    @Query private var unassignedEvents: [TimelineEvent]
    @Query private var allEvents: [TimelineEvent]

    @Binding var fitToContent: Bool

    @State private var viewport: TimelineViewport
    @State private var selectedEventID: UUID?
    @State private var isDragging = false
    @State private var dragStartCenter: Date?
    @State private var hasAutoFitted = false

    init(fitToContent: Binding<Bool>) {
        _fitToContent = fitToContent
        _viewport = State(initialValue: TimelineViewport(
            centerDate: Date(),
            scale: 86400 * 30, // ~1 month per point initially
            viewportWidth: 800
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Time axis (pan and zoom gestures live here)
                TimeAxisView(viewport: viewportWithWidth(geometry.size.width))
                    .gesture(panGesture(width: geometry.size.width))
                    .gesture(magnificationGesture)
                    .contentShape(Rectangle())

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
            .onAppear {
                viewport.viewportWidth = geometry.size.width
            }
            .task {
                // Wait for SwiftData to finish loading events before auto-fitting
                while allEvents.isEmpty {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                if !hasAutoFitted {
                    // Allow a final settle for any remaining batch loads
                    try? await Task.sleep(for: .milliseconds(100))
                    fitToContent = true
                    hasAutoFitted = true
                }
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                viewport.viewportWidth = newWidth
            }
            .onChange(of: fitToContent) { _, shouldFit in
                if shouldFit {
                    fitViewportToContent(width: geometry.size.width)
                    fitToContent = false
                }
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
        let vp = viewportWithWidth(width)
        let layout = layoutEvents(eventsWithoutLane, viewport: vp)
        let baseRowHeight: CGFloat = 40
        let totalHeight = baseRowHeight * CGFloat(max(layout.totalRows, 1))
        let lines = computeConnectionLines(layout: layout.layout, viewport: vp, baseRowHeight: baseRowHeight)

        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.05))

            // Connection lines
            Path { path in
                for segment in lines.tracks {
                    path.move(to: segment.from)
                    path.addLine(to: segment.to)
                }

                for fm in lines.forkMerges {
                    let dy = abs(fm.subRowY - fm.row0Y)
                    let spread = min(40, dy)

                    if fm.isFork {
                        path.move(to: CGPoint(x: fm.x - spread, y: fm.row0Y))
                        path.addCurve(
                            to: CGPoint(x: fm.x, y: fm.subRowY),
                            control1: CGPoint(x: fm.x, y: fm.row0Y),
                            control2: CGPoint(x: fm.x - spread, y: fm.subRowY)
                        )
                    } else {
                        path.move(to: CGPoint(x: fm.x, y: fm.subRowY))
                        path.addCurve(
                            to: CGPoint(x: fm.x + spread, y: fm.row0Y),
                            control1: CGPoint(x: fm.x + spread, y: fm.subRowY),
                            control2: CGPoint(x: fm.x, y: fm.row0Y)
                        )
                    }
                }
            }
            .stroke(Color.gray, lineWidth: 3)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.15),
                        .init(color: .black, location: 0.85),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            Text("Unassigned")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 4)

            ForEach(layout.layout, id: \.event.id) { item in
                EventView(
                    event: item.event,
                    viewport: vp,
                    isSelected: item.event.id == selectedEventID,
                    onSelect: { selectedEventID = item.event.id },
                    subRow: item.subRow,
                    rowHeight: totalHeight
                )
            }
        }
        .frame(height: totalHeight)
    }

    private func layoutEvents(_ events: [TimelineEvent], viewport: TimelineViewport) -> (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int) {
        let points = events.filter { $0.endDate == nil }.sorted { $0.startDate.asDate < $1.startDate.asDate }
        let spans = events.filter { $0.endDate != nil }.sorted { $0.startDate.asDate < $1.startDate.asDate }

        var assignments: [(event: TimelineEvent, subRow: Int)] = []
        var rowIntervals: [[(startX: CGFloat, endX: CGFloat)]] = [[]] // row 0 always exists

        func eventXInterval(_ event: TimelineEvent) -> (startX: CGFloat, endX: CGFloat) {
            let startX = viewport.xPosition(for: event.startDate.asDate)
            var endX: CGFloat
            if let end = event.endDate {
                endX = viewport.xPosition(for: end.asDate)
            } else {
                endX = startX + 16
            }
            endX = max(endX, startX + 20)
            return (startX, endX)
        }

        func collides(_ interval: (startX: CGFloat, endX: CGFloat), inRow row: Int) -> Bool {
            for existing in rowIntervals[row] {
                if interval.startX < existing.endX && interval.endX > existing.startX {
                    return true
                }
            }
            return false
        }

        // Point events always go in row 0
        for event in points {
            let interval = eventXInterval(event)
            assignments.append((event: event, subRow: 0))
            rowIntervals[0].append(interval)
        }

        // Spans use first-fit packing, checking actual collisions per row
        for event in spans {
            let interval = eventXInterval(event)
            var assigned = false
            for i in 0..<rowIntervals.count {
                if !collides(interval, inRow: i) {
                    assignments.append((event: event, subRow: i))
                    rowIntervals[i].append(interval)
                    assigned = true
                    break
                }
            }
            if !assigned {
                assignments.append((event: event, subRow: rowIntervals.count))
                rowIntervals.append([interval])
            }
        }

        return (layout: assignments, totalRows: max(rowIntervals.count, 1))
    }

    private struct LineSegment {
        let from: CGPoint
        let to: CGPoint
    }

    private struct ForkMerge {
        let x: CGFloat
        let row0Y: CGFloat
        let subRowY: CGFloat
        let isFork: Bool
    }

    private struct ConnectionLines {
        let tracks: [LineSegment]
        let forkMerges: [ForkMerge]
    }

    private func eventXRange(for event: TimelineEvent, viewport vp: TimelineViewport) -> (startX: CGFloat, endX: CGFloat) {
        let startX = vp.xPosition(for: event.startDate.asDate)
        var endX: CGFloat
        if let end = event.endDate {
            endX = vp.xPosition(for: end.asDate)
        } else {
            endX = startX + 16
        }
        endX = max(endX, startX + 20)
        return (startX, endX)
    }

    private func computeConnectionLines(layout: [(event: TimelineEvent, subRow: Int)], viewport vp: TimelineViewport, baseRowHeight: CGFloat) -> ConnectionLines {
        guard !layout.isEmpty else { return ConnectionLines(tracks: [], forkMerges: []) }

        let sorted = layout.sorted { $0.event.startDate.asDate < $1.event.startDate.asDate }

        var subRowRanges: [Int: (minX: CGFloat, maxX: CGFloat)] = [:]
        for item in sorted {
            let range = eventXRange(for: item.event, viewport: vp)
            if let existing = subRowRanges[item.subRow] {
                subRowRanges[item.subRow] = (
                    minX: min(existing.minX, range.startX),
                    maxX: max(existing.maxX, range.endX)
                )
            } else {
                subRowRanges[item.subRow] = (minX: range.startX, maxX: range.endX)
            }
        }

        var tracks: [LineSegment] = []
        for (subRow, range) in subRowRanges {
            let y = baseRowHeight * CGFloat(subRow) + baseRowHeight / 2
            if subRow == 0 {
                tracks.append(LineSegment(from: CGPoint(x: 0, y: y),
                                          to: CGPoint(x: vp.viewportWidth, y: y)))
            } else {
                tracks.append(LineSegment(from: CGPoint(x: range.minX, y: y),
                                          to: CGPoint(x: range.maxX, y: y)))
            }
        }

        let row0Y = baseRowHeight / 2
        var forkMerges: [ForkMerge] = []
        for (subRow, range) in subRowRanges where subRow != 0 {
            let subRowY = baseRowHeight * CGFloat(subRow) + baseRowHeight / 2
            forkMerges.append(ForkMerge(x: range.minX, row0Y: row0Y, subRowY: subRowY, isFork: true))
            forkMerges.append(ForkMerge(x: range.maxX, row0Y: row0Y, subRowY: subRowY, isFork: false))
        }

        return ConnectionLines(tracks: tracks, forkMerges: forkMerges)
    }

    /// Returns the earliest start and latest end across all events, or nil if empty.
    private var eventDateBounds: (earliest: Date, latest: Date)? {
        guard !allEvents.isEmpty else { return nil }
        var earliest = Date.distantFuture
        var latest = Date.distantPast
        for event in allEvents {
            let start = event.startDate.asDate
            if start < earliest { earliest = start }
            if start > latest { latest = start }
            if let end = event.endDate {
                let endDate = end.asDate
                if endDate > latest { latest = endDate }
            }
        }
        return (earliest, latest)
    }

    private static let boundsPadding: TimeInterval = 86400 * 365 // 1 year

    /// Clamp the viewport so the visible range doesn't extend more than 1 year
    /// beyond the first/last event.
    private func clampViewport() {
        guard let bounds = eventDateBounds else { return }
        let padding = Self.boundsPadding
        let minDate = bounds.earliest.addingTimeInterval(-padding)
        let maxDate = bounds.latest.addingTimeInterval(padding)
        let allowedSeconds = maxDate.timeIntervalSince(minDate)

        // Clamp scale so the full viewport fits within the allowed range
        let maxScale = allowedSeconds / Double(viewport.viewportWidth)
        viewport.scale = min(viewport.scale, max(maxScale, 1))

        // Clamp center so viewport edges stay within bounds
        let halfDuration = TimeInterval(viewport.viewportWidth / 2) * viewport.scale
        let minCenter = minDate.addingTimeInterval(halfDuration)
        let maxCenter = maxDate.addingTimeInterval(-halfDuration)

        if minCenter < maxCenter {
            if viewport.centerDate < minCenter { viewport.centerDate = minCenter }
            if viewport.centerDate > maxCenter { viewport.centerDate = maxCenter }
        } else {
            // Viewport is wider than allowed range — center on midpoint
            viewport.centerDate = minDate.addingTimeInterval(allowedSeconds / 2)
        }
    }

    private func fitViewportToContent(width: CGFloat) {
        guard !allEvents.isEmpty else { return }

        var earliest = Date.distantFuture
        var latest = Date.distantPast

        for event in allEvents {
            let start = event.startDate.asDate
            if start < earliest { earliest = start }
            if start > latest { latest = start }

            if let end = event.endDate {
                let endDate = end.asDate
                if endDate > latest { latest = endDate }
            }
        }

        let rangeSeconds = latest.timeIntervalSince(earliest)
        // For point-only timelines (range == 0), show ±1 day around the point
        let effectiveRange = rangeSeconds > 0 ? rangeSeconds * 1.4 : 86400 * 2
        let newScale = max(1, effectiveRange / Double(width))

        viewport.scale = newScale
        viewport.centerDate = earliest.addingTimeInterval(rangeSeconds / 2)
        viewport.viewportWidth = width
        clampViewport()
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
                clampViewport()
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
                viewport.scale = max(1, viewport.scale * factor)
                clampViewport()
            }
    }
}

#Preview {
    TimelineCanvasView(fitToContent: .constant(false))
        .modelContainer(for: [TimelineEvent.self, Lane.self, Tag.self], inMemory: true)
        .frame(width: 800, height: 400)
}
