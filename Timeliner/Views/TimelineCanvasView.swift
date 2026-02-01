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
    TimelineCanvasView(fitToContent: .constant(false))
        .modelContainer(for: [TimelineEvent.self, Lane.self, Tag.self], inMemory: true)
        .frame(width: 800, height: 400)
}
