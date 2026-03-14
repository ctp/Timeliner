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
    @Query(sort: \Era.sortOrder) private var eras: [Era]

    @Environment(\.modelContext) private var modelContext

    @Binding var fitToContent: Bool
    @Binding var showPointLabels: Bool
    @Binding var showInspector: Bool
    @Binding var canvasWidth: CGFloat
    @Binding var viewport: TimelineViewport
    @Binding var editingLane: Lane?
    @Binding var editingEra: Era?
    @Binding var sidebarSelection: SidebarSelection?
    @State private var selectedEventID: UUID?
    @State private var isDragging = false
    @State private var dragStartCenter: Date?
    @State private var hasAutoFitted = false
    @State private var zoomStartScale: Double?

    init(fitToContent: Binding<Bool>, showPointLabels: Binding<Bool>, showInspector: Binding<Bool>, canvasWidth: Binding<CGFloat>, viewport: Binding<TimelineViewport>, editingLane: Binding<Lane?>, editingEra: Binding<Era?>, sidebarSelection: Binding<SidebarSelection?>) {
        _fitToContent = fitToContent
        _showPointLabels = showPointLabels
        _showInspector = showInspector
        _canvasWidth = canvasWidth
        _viewport = viewport
        _editingLane = editingLane
        _editingEra = editingEra
        _sidebarSelection = sidebarSelection
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Time axis (pan gesture lives here)
                TimeAxisView(viewport: viewportWithWidth(geometry.size.width))
                    .gesture(panGesture(width: geometry.size.width))
                    .contentShape(Rectangle())

                Divider()

                // Lanes
                ScrollView(.vertical, showsIndicators: true) {

                    ZStack(alignment: .topLeading) {
                        // Era background bands (decorative background; accessible via sidebar)
                        GeometryReader { scrollGeo in
                            ForEach(eras, id: \.id) { era in
                                EraBandView(
                                    era: era,
                                    viewport: viewportWithWidth(geometry.size.width),
                                    totalHeight: scrollGeo.size.height
                                )
                                .accessibilityHidden(true)
                            }
                        }

                        VStack(spacing: 1) {
                            ForEach(lanes, id: \.id) { lane in
                                LaneRowView(
                                    lane: lane,
                                    viewport: viewportWithWidth(geometry.size.width),
                                    showPointLabels: showPointLabels,
                                    selectedEventID: selectedEventID,
                                    onSelectEvent: { event in
                                        selectedEventID = event.id
                                        sidebarSelection = nil
                                    },
                                    onDragEnd: { event, newStart, newEnd in
                                        applyDrag(event: event, newStart: newStart, newEnd: newEnd)
                                    }
                                )
                            }

                            // Unassigned events lane
                            if !eventsWithoutLane.isEmpty {
                                UnassignedLaneRowView(
                                    events: eventsWithoutLane,
                                    viewport: viewportWithWidth(geometry.size.width),
                                    showPointLabels: showPointLabels,
                                    selectedEventID: selectedEventID,
                                    onSelectEvent: { event in
                                        selectedEventID = event.id
                                        sidebarSelection = nil
                                    },
                                    onDragEnd: { event, newStart, newEnd in
                                        applyDrag(event: event, newStart: newStart, newEnd: newEnd)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .gesture(magnificationGesture)
            .onHorizontalScroll { deltaX in
                let deltaSeconds = TimeInterval(-deltaX) * viewport.scale
                viewport.centerDate = viewport.centerDate.addingTimeInterval(deltaSeconds)
                clampViewport()
            }
            .onAppear {
                viewport.viewportWidth = geometry.size.width
                canvasWidth = geometry.size.width
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                canvasWidth = newWidth
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
        .inspector(isPresented: $showInspector) {
            InspectorView(event: selectedEvent, editingLane: $editingLane, editingEra: $editingEra)
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
                // Anchor the zoom to the scale at gesture start so each frame
                // applies relative to the original value, not the previous frame.
                let startScale = zoomStartScale ?? viewport.scale
                if zoomStartScale == nil { zoomStartScale = viewport.scale }
                // MagnificationGesture value > 1 means pinch-out (zoom in → smaller scale).
                viewport.scale = max(1, startScale / value)
                clampViewport()
            }
            .onEnded { _ in
                zoomStartScale = nil
            }
    }

    private func applyDrag(event: TimelineEvent, newStart: FlexibleDate, newEnd: FlexibleDate?) {
        event.startDate = newStart
        event.endDate = newEnd
        try? modelContext.save()
    }
}

#Preview {
    TimelineCanvasView(fitToContent: .constant(false), showPointLabels: .constant(false), showInspector: .constant(false), canvasWidth: .constant(800), viewport: .constant(TimelineViewport()), editingLane: .constant(nil), editingEra: .constant(nil), sidebarSelection: .constant(nil))
        .modelContainer(for: [TimelineEvent.self, Lane.self, Era.self], inMemory: true)
        .frame(width: 800, height: 400)
}
