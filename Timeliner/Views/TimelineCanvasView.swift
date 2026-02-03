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

    @Environment(\.modelContext) private var modelContext

    @Binding var fitToContent: Bool
    @Binding var showPointLabels: Bool
    @Binding var showInspector: Bool
    @Binding var createPointEvent: Bool
    @Binding var createSpanEvent: Bool

    @State private var viewport: TimelineViewport
    @State private var selectedEventID: UUID?
    @State private var isDragging = false
    @State private var dragStartCenter: Date?
    @State private var hasAutoFitted = false

    init(fitToContent: Binding<Bool>, showPointLabels: Binding<Bool>, showInspector: Binding<Bool>, createPointEvent: Binding<Bool>, createSpanEvent: Binding<Bool>) {
        _fitToContent = fitToContent
        _showPointLabels = showPointLabels
        _showInspector = showInspector
        _createPointEvent = createPointEvent
        _createSpanEvent = createSpanEvent
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
                                showPointLabels: showPointLabels,
                                selectedEventID: selectedEventID,
                                onSelectEvent: { event in
                                    selectedEventID = event.id
                                },
                                onCreateEvent: { xPosition in
                                    createPointEvent(at: xPosition, in: lane, viewportWidth: geometry.size.width)
                                },
                                onDragEnd: { event, newStart, newEnd in
                                    applyDrag(event: event, newStart: newStart, newEnd: newEnd)
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
            .onHorizontalScroll { deltaX in
                let deltaSeconds = TimeInterval(-deltaX) * viewport.scale
                viewport.centerDate = viewport.centerDate.addingTimeInterval(deltaSeconds)
                clampViewport()
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
            .onChange(of: createPointEvent) { _, shouldCreate in
                if shouldCreate {
                    createEventFromMenu(span: false, viewportWidth: geometry.size.width)
                    createPointEvent = false
                }
            }
            .onChange(of: createSpanEvent) { _, shouldCreate in
                if shouldCreate {
                    createEventFromMenu(span: true, viewportWidth: geometry.size.width)
                    createSpanEvent = false
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .inspector(isPresented: $showInspector) {
            EventInspectorView(event: selectedEvent)
                .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
        }
    }

    private var selectedEvent: TimelineEvent? {
        guard let id = selectedEventID else { return nil }
        return allEvents.first { $0.id == id }
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
        let labelResult = showPointLabels ? computeLabelPositions(layout: layout, viewport: vp) : (positions: [:], offsets: [:])
        let labelPositions = labelResult.positions
        let labelOffsets = labelResult.offsets
        let maxAboveTier = labelPositions.values.filter(\.isAbove).map(\.tier).max()
        let maxBelowTier = labelPositions.values.filter(\.isBelow).map(\.tier).max()
        let topPadding: CGFloat = maxAboveTier != nil
            ? LabelPosition.connectorBase + LabelPosition.tierHeight * CGFloat(maxAboveTier! + 1)
            : 0
        let bottomPadding: CGFloat = maxBelowTier != nil
            ? LabelPosition.connectorBase + LabelPosition.tierHeight * CGFloat(maxBelowTier! + 1)
            : 0
        let laneContentHeight = baseRowHeight * CGFloat(max(layout.totalRows, 1))
        let totalHeight = topPadding + laneContentHeight + bottomPadding
        let lines = computeConnectionLines(layout: layout.layout, viewport: vp, baseRowHeight: baseRowHeight, yOffset: topPadding)

        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.05))

            // Connection lines
            ConnectionLinesShape(lines: lines)
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
                    rowHeight: totalHeight,
                    labelPosition: labelPositions[item.event.id] ?? .none,
                    labelXOffset: labelOffsets[item.event.id] ?? 0,
                    yOffset: topPadding,
                    onDragEnd: { event, newStart, newEnd in
                        applyDrag(event: event, newStart: newStart, newEnd: newEnd)
                    }
                )
            }
        }
        .frame(height: totalHeight)
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
        guard let bounds = eventDateBounds else { return }

        let rangeSeconds = bounds.latest.timeIntervalSince(bounds.earliest)
        // For point-only timelines (range == 0), show ±1 day around the point
        let effectiveRange = rangeSeconds > 0 ? rangeSeconds * 1.4 : 86400 * 2
        let newScale = max(1, effectiveRange / Double(width))

        viewport.scale = newScale
        viewport.centerDate = bounds.earliest.addingTimeInterval(rangeSeconds / 2)
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

    private func createPointEvent(at xPosition: CGFloat, in lane: Lane, viewportWidth: CGFloat) {
        let vp = viewportWithWidth(viewportWidth)
        let precision = vp.currentPrecision()
        let rawDate = vp.date(forX: xPosition)
        let snapped = vp.snappedDate(from: rawDate, precision: precision)
        let fd = flexibleDate(from: snapped, precision: precision)
        let title = titleForDate(snapped, precision: precision)

        let event = TimelineEvent(title: title, startDate: fd, lane: lane)
        modelContext.insert(event)
        try? modelContext.save()
        selectedEventID = event.id
        showInspector = true
    }

    private func createEventFromMenu(span: Bool, viewportWidth: CGFloat) {
        let lane: Lane? = if let selectedEvent {
            selectedEvent.lane
        } else {
            lanes.first
        }

        let vp = viewportWithWidth(viewportWidth)
        let precision = vp.currentPrecision()
        let snapped = vp.snappedDate(from: vp.centerDate, precision: precision)
        let startFD = flexibleDate(from: snapped, precision: precision)
        let title = titleForDate(snapped, precision: precision)

        var endFD: FlexibleDate? = nil
        if span {
            let cal = Calendar.current
            let endDate: Date
            switch precision {
            case .time:
                endDate = cal.date(byAdding: .hour, value: 4, to: snapped)!
            case .day:
                endDate = cal.date(byAdding: .day, value: 7, to: snapped)!
            case .month:
                endDate = cal.date(byAdding: .month, value: 3, to: snapped)!
            case .year:
                endDate = cal.date(byAdding: .year, value: 5, to: snapped)!
            }
            endFD = flexibleDate(from: endDate, precision: precision)
        }

        let event = TimelineEvent(title: title, startDate: startFD, endDate: endFD, lane: lane)
        modelContext.insert(event)
        try? modelContext.save()
        selectedEventID = event.id
        showInspector = true
    }

    private func applyDrag(event: TimelineEvent, newStart: FlexibleDate, newEnd: FlexibleDate?) {
        event.startDate = newStart
        event.endDate = newEnd
        try? modelContext.save()
    }
}

#Preview {
    TimelineCanvasView(fitToContent: .constant(false), showPointLabels: .constant(false), showInspector: .constant(false), createPointEvent: .constant(false), createSpanEvent: .constant(false))
        .modelContainer(for: [TimelineEvent.self, Lane.self], inMemory: true)
        .frame(width: 800, height: 400)
}
