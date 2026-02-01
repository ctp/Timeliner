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
        let layout = layoutEvents(eventsWithoutLane, viewport: viewportWithWidth(width))
        let baseRowHeight: CGFloat = 40
        let totalHeight = baseRowHeight * CGFloat(max(layout.totalRows, 1))

        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.05))

            Text("Unassigned")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 4)

            ForEach(layout.layout, id: \.event.id) { item in
                EventView(
                    event: item.event,
                    viewport: viewportWithWidth(width),
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
        // Point events first (top rows), then span events below
        let points = events.filter { $0.endDate == nil }.sorted { $0.startDate.asDate < $1.startDate.asDate }
        let spans = events.filter { $0.endDate != nil }.sorted { $0.startDate.asDate < $1.startDate.asDate }

        var assignments: [(event: TimelineEvent, subRow: Int)] = []
        var rowEndPositions: [CGFloat] = []

        for event in points + spans {
            let startX = viewport.xPosition(for: event.startDate.asDate)
            var endX: CGFloat
            if let end = event.endDate {
                endX = viewport.xPosition(for: end.asDate)
            } else {
                endX = startX + 16
            }
            endX = max(endX, startX + 20)

            var assigned = false
            for i in 0..<rowEndPositions.count {
                if startX >= rowEndPositions[i] {
                    assignments.append((event: event, subRow: i))
                    rowEndPositions[i] = endX
                    assigned = true
                    break
                }
            }

            if !assigned {
                assignments.append((event: event, subRow: rowEndPositions.count))
                rowEndPositions.append(endX)
            }
        }

        return (layout: assignments, totalRows: max(rowEndPositions.count, 1))
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
