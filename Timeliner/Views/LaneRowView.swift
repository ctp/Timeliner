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
        let lines = computeConnectionLines(layout: layout.layout)

        ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(laneBackgroundColor)

            // Connection lines (behind events)
            Path { path in
                // Horizontal track lines per sub-row
                for segment in lines.tracks {
                    path.move(to: segment.from)
                    path.addLine(to: segment.to)
                }

                // S-curve fork/merge connectors
                for fm in lines.forkMerges {
                    let dy = abs(fm.subRowY - fm.row0Y)
                    let spread = min(40, dy)

                    if fm.isFork {
                        // S-curve from main track down to sub-row
                        path.move(to: CGPoint(x: fm.x - spread, y: fm.row0Y))
                        path.addCurve(
                            to: CGPoint(x: fm.x, y: fm.subRowY),
                            control1: CGPoint(x: fm.x, y: fm.row0Y),
                            control2: CGPoint(x: fm.x - spread, y: fm.subRowY)
                        )
                    } else {
                        // S-curve from sub-row back up to main track
                        path.move(to: CGPoint(x: fm.x, y: fm.subRowY))
                        path.addCurve(
                            to: CGPoint(x: fm.x + spread, y: fm.row0Y),
                            control1: CGPoint(x: fm.x + spread, y: fm.subRowY),
                            control2: CGPoint(x: fm.x, y: fm.row0Y)
                        )
                    }
                }
            }
            .stroke(laneStrokeColor, lineWidth: 3)
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

    private struct LineSegment {
        let from: CGPoint
        let to: CGPoint
    }

    private struct ForkMerge {
        let x: CGFloat
        let row0Y: CGFloat
        let subRowY: CGFloat
        let isFork: Bool // true = fork (going down), false = merge (coming back up)
    }

    private struct ConnectionLines {
        let tracks: [LineSegment]
        let forkMerges: [ForkMerge]
    }

    private func yCenter(forSubRow subRow: Int) -> CGFloat {
        baseRowHeight * CGFloat(subRow) + baseRowHeight / 2
    }

    private func eventXRange(for event: TimelineEvent) -> (startX: CGFloat, endX: CGFloat) {
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

    private func computeConnectionLines(layout: [(event: TimelineEvent, subRow: Int)]) -> ConnectionLines {
        guard !layout.isEmpty else { return ConnectionLines(tracks: [], forkMerges: []) }

        // Sort chronologically by start date
        let sorted = layout.sorted { $0.event.startDate.asDate < $1.event.startDate.asDate }

        // Compute horizontal track extents per sub-row
        var subRowRanges: [Int: (minX: CGFloat, maxX: CGFloat)] = [:]
        for item in sorted {
            let range = eventXRange(for: item.event)
            if let existing = subRowRanges[item.subRow] {
                subRowRanges[item.subRow] = (
                    minX: min(existing.minX, range.startX),
                    maxX: max(existing.maxX, range.endX)
                )
            } else {
                subRowRanges[item.subRow] = (minX: range.startX, maxX: range.endX)
            }
        }

        // Build horizontal track segments
        // Sub-row 0 spans the full viewport; others span their event extents
        var tracks: [LineSegment] = []
        for (subRow, range) in subRowRanges {
            let y = yCenter(forSubRow: subRow)
            if subRow == 0 {
                tracks.append(LineSegment(from: CGPoint(x: 0, y: y),
                                          to: CGPoint(x: viewport.viewportWidth, y: y)))
            } else {
                tracks.append(LineSegment(from: CGPoint(x: range.minX, y: y),
                                          to: CGPoint(x: range.maxX, y: y)))
            }
        }

        // Build fork/merge connectors for each non-zero sub-row back to row 0
        let row0Y = yCenter(forSubRow: 0)
        var forkMerges: [ForkMerge] = []
        for (subRow, range) in subRowRanges where subRow != 0 {
            let subRowY = yCenter(forSubRow: subRow)
            forkMerges.append(ForkMerge(x: range.minX, row0Y: row0Y, subRowY: subRowY, isFork: true))
            forkMerges.append(ForkMerge(x: range.maxX, row0Y: row0Y, subRowY: subRowY, isFork: false))
        }

        return ConnectionLines(tracks: tracks, forkMerges: forkMerges)
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
        selectedEventID: nil,
        onSelectEvent: { _ in }
    )
    .frame(width: 600)
}
