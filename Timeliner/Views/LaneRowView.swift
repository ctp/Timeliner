//
//  LaneRowView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct LaneRowView: View {
    let lane: Lane
    let viewport: TimelineViewport
    let selectedEventID: UUID?
    let onSelectEvent: (TimelineEvent) -> Void

    private let baseRowHeight: CGFloat = 40

    private var eventLayout: (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int) {
        layoutEvents(lane.events, viewport: viewport)
    }

    var body: some View {
        let layout = eventLayout
        let totalHeight = baseRowHeight * CGFloat(max(layout.totalRows, 1))

        ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(laneBackgroundColor)

            // Lane label
            Text(lane.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 4)

            // Events
            ForEach(layout.layout, id: \.event.id) { item in
                EventView(
                    event: item.event,
                    viewport: viewport,
                    isSelected: item.event.id == selectedEventID,
                    onSelect: { onSelectEvent(item.event) },
                    subRow: item.subRow,
                    rowHeight: totalHeight
                )
            }
        }
        .frame(height: totalHeight)
        .clipped()
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
            endX = max(endX, startX + 20) // match minimum visible width

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

    private var laneBackgroundColor: Color {
        if let hex = Color(hex: lane.color) {
            return hex.opacity(0.1)
        }
        return Color.gray.opacity(0.1)
    }
}

#Preview {
    let lane = Lane(name: "Career", color: "#3498DB")
    return LaneRowView(
        lane: lane,
        viewport: TimelineViewport(),
        selectedEventID: nil,
        onSelectEvent: { _ in }
    )
    .frame(width: 600)
}
