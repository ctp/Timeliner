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

    private let rowHeight: CGFloat = 40

    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(laneBackgroundColor)

            // Lane label
            Text(lane.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Events
            ForEach(lane.events, id: \.id) { event in
                EventView(
                    event: event,
                    viewport: viewport,
                    isSelected: event.id == selectedEventID,
                    onSelect: { onSelectEvent(event) }
                )
            }
        }
        .frame(height: rowHeight)
        .clipped()
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
