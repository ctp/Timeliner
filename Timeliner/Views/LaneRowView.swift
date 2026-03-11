//
//  LaneRowView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct LaneRowView: View {
    let lane: Lane
    let viewport: TimelineViewport
    let showPointLabels: Bool
    let selectedEventID: UUID?
    let onSelectEvent: (TimelineEvent) -> Void
    var onDragEnd: ((TimelineEvent, FlexibleDate, FlexibleDate?) -> Void)?

    private let baseRowHeight: CGFloat = TimelineConstants.baseRowHeight

    private var eventLayout: (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int) {
        layoutEvents(lane.events, viewport: viewport)
    }

    var body: some View {
        let layout = eventLayout
        let labelResult = showPointLabels ? computeLabelPositions(layout: layout, viewport: viewport) : (positions: [:], offsets: [:])
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
        let lines = computeConnectionLines(layout: layout.layout, viewport: viewport, baseRowHeight: baseRowHeight, yOffset: topPadding)

        ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(laneBackgroundColor)
                .accessibilityHidden(true)

            // Connection lines (behind events) — decorative
            ConnectionLinesShape(lines: lines)
                .stroke(laneStrokeColor, lineWidth: TimelineConstants.connectionLineWidth)
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

            // Lane label — decorative; lane identity is conveyed by the container label
            Text(lane.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 4)
                .accessibilityHidden(true)

            // Events
            ForEach(layout.layout, id: \.event.id) { item in
                EventView(
                    event: item.event,
                    viewport: viewport,
                    isSelected: item.event.id == selectedEventID,
                    onSelect: { onSelectEvent(item.event) },
                    subRow: item.subRow,
                    rowHeight: totalHeight,
                    labelPosition: labelPositions[item.event.id] ?? .none,
                    labelXOffset: labelOffsets[item.event.id] ?? 0,
                    yOffset: topPadding,
                    onDragEnd: onDragEnd
                )
            }
        }
        .frame(height: totalHeight)
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lane: \(lane.name)")
    }

    private var laneStrokeColor: Color {
        if let hex = Color(hex: lane.color) {
            return hex
        }
        return .gray
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
        showPointLabels: false,
        selectedEventID: nil,
        onSelectEvent: { _ in }
    )
    .frame(width: 600)
}
