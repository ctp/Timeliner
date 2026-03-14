//
//  UnassignedLaneRowView.swift
//  Timeliner
//

import SwiftUI

struct UnassignedLaneRowView: View {
    let events: [TimelineEvent]
    let viewport: TimelineViewport
    let showPointLabels: Bool
    var selectedEventID: UUID? = nil
    var onSelectEvent: ((TimelineEvent) -> Void)? = nil
    var onDragEnd: ((TimelineEvent, FlexibleDate, FlexibleDate?) -> Void)? = nil

    var body: some View {
        let layout = layoutEvents(events, viewport: viewport)
        let labelResult = showPointLabels
            ? computeLabelPositions(layout: layout, viewport: viewport)
            : (positions: [:], offsets: [:])
        let labelPositions = labelResult.positions
        let labelOffsets = labelResult.offsets
        let padding = computeLabelPadding(positions: labelPositions)
        let laneContentHeight = TimelineConstants.baseRowHeight * CGFloat(max(layout.totalRows, 1))
        let totalHeight = padding.top + laneContentHeight + padding.bottom
        let lines = computeConnectionLines(
            layout: layout.layout,
            viewport: viewport,
            baseRowHeight: TimelineConstants.baseRowHeight,
            yOffset: padding.top
        )

        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .accessibilityHidden(true)

            ConnectionLinesShape(lines: lines)
                .stroke(Color.gray, lineWidth: TimelineConstants.connectionLineWidth)
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
                .accessibilityHidden(true)

            Text("Unassigned")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 4)
                .accessibilityHidden(true)

            ForEach(layout.layout, id: \.event.id) { item in
                EventView(
                    event: item.event,
                    viewport: viewport,
                    isSelected: item.event.id == selectedEventID,
                    onSelect: { onSelectEvent?(item.event) },
                    subRow: item.subRow,
                    rowHeight: totalHeight,
                    labelPosition: labelPositions[item.event.id] ?? .none,
                    labelXOffset: labelOffsets[item.event.id] ?? 0,
                    yOffset: padding.top,
                    onDragEnd: onDragEnd
                )
            }
        }
        .frame(height: totalHeight)
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lane: Unassigned")
    }
}
