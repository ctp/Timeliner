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

    private let baseRowHeight: CGFloat = 40

    private var eventLayout: (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int) {
        layoutEvents(lane.events, viewport: viewport)
    }

    var body: some View {
        let layout = eventLayout
        let labelResult = showPointLabels ? computeLabelPositions(layout: layout) : (positions: [:], offsets: [:])
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
        let lines = computeConnectionLines(layout: layout.layout, yOffset: topPadding)

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
                    rowHeight: totalHeight,
                    labelPosition: labelPositions[item.event.id] ?? .none,
                    labelXOffset: labelOffsets[item.event.id] ?? 0,
                    yOffset: topPadding
                )
            }
        }
        .frame(height: totalHeight)
        .clipped()
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
        let isFork: Bool // true = fork (going down), false = merge (coming back up)
    }

    private struct ConnectionLines {
        let tracks: [LineSegment]
        let forkMerges: [ForkMerge]
    }

    private func yCenter(forSubRow subRow: Int, yOffset: CGFloat = 0) -> CGFloat {
        yOffset + baseRowHeight * CGFloat(subRow) + baseRowHeight / 2
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

    private func computeLabelPositions(layout: (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int)) -> (positions: [UUID: LabelPosition], offsets: [UUID: CGFloat]) {
        let points = layout.layout.filter { $0.event.isPointEvent }
            .sorted { $0.event.startDate.asDate < $1.event.startDate.asDate }

        guard !points.isEmpty else { return ([:], [:]) }

        var positions: [UUID: LabelPosition] = [:]
        let charWidth: CGFloat = 7
        let labelPadding: CGFloat = 8
        let connectorPadding: CGFloat = 4
        let maxAbove = LabelPosition.maxAboveTiers

        // ── Pass 1: assign tiers using label-to-label collision only ──
        var aboveTiers: [[(startX: CGFloat, endX: CGFloat)]] = Array(repeating: [], count: maxAbove)
        var belowTiers: [[(startX: CGFloat, endX: CGFloat)]] = Array(repeating: [], count: 2)

        func collidesInTier(_ intervals: [(startX: CGFloat, endX: CGFloat)], start: CGFloat, end: CGFloat) -> Bool {
            intervals.contains { start < $0.endX && end > $0.startX }
        }

        for item in points {
            let x = viewport.xPosition(for: item.event.startDate.asDate)
            let titleWidth = CGFloat(item.event.title.count) * charWidth
            let halfWidth = (titleWidth + labelPadding) / 2
            let labelStart = x - halfWidth
            let labelEnd = x + halfWidth

            var placed = false

            for tier in 0..<maxAbove {
                if !collidesInTier(aboveTiers[tier], start: labelStart, end: labelEnd) {
                    positions[item.event.id] = .above(tier: tier)
                    aboveTiers[tier].append((startX: labelStart, endX: labelEnd))
                    placed = true
                    break
                }
            }

            if !placed {
                for tier in 0..<belowTiers.count {
                    if !collidesInTier(belowTiers[tier], start: labelStart, end: labelEnd) {
                        positions[item.event.id] = .below(tier: tier)
                        belowTiers[tier].append((startX: labelStart, endX: labelEnd))
                        placed = true
                        break
                    }
                }
            }

            if !placed {
                positions[item.event.id] = .above(tier: maxAbove - 1)
                aboveTiers[maxAbove - 1].append((startX: labelStart, endX: labelEnd))
            }
        }

        // ── Pass 2: compute offsets to avoid connector lines ──
        // Collect all connector x-positions with their tier reach
        struct PlacedLabel {
            let id: UUID
            let x: CGFloat
            let tier: Int
            let isAbove: Bool
            let labelStart: CGFloat
            let labelEnd: CGFloat
        }

        var placed: [PlacedLabel] = []
        for item in points {
            guard let pos = positions[item.event.id] else { continue }
            let x = viewport.xPosition(for: item.event.startDate.asDate)
            let titleWidth = CGFloat(item.event.title.count) * charWidth
            let halfWidth = (titleWidth + labelPadding) / 2
            placed.append(PlacedLabel(
                id: item.event.id, x: x, tier: pos.tier, isAbove: pos.isAbove,
                labelStart: x - halfWidth, labelEnd: x + halfWidth
            ))
        }

        var offsets: [UUID: CGFloat] = [:]

        for label in placed {
            // Find connectors passing through this label's tier
            // A connector at x from a label at tier T passes through tiers 0..<T
            let conflicting: [(startX: CGFloat, endX: CGFloat)]
            if label.isAbove {
                conflicting = placed.compactMap { other in
                    guard other.id != label.id && other.isAbove && other.tier > label.tier else { return nil }
                    let connStart = other.x - connectorPadding
                    let connEnd = other.x + connectorPadding
                    guard label.labelStart < connEnd && label.labelEnd > connStart else { return nil }
                    return (startX: connStart, endX: connEnd)
                }
            } else {
                conflicting = placed.compactMap { other in
                    guard other.id != label.id && !other.isAbove && other.tier > label.tier else { return nil }
                    let connStart = other.x - connectorPadding
                    let connEnd = other.x + connectorPadding
                    guard label.labelStart < connEnd && label.labelEnd > connStart else { return nil }
                    return (startX: connStart, endX: connEnd)
                }
            }

            guard !conflicting.isEmpty else { continue }

            // Get other labels in the same tier (for collision avoidance after shifting)
            let sameTierLabels: [(startX: CGFloat, endX: CGFloat)]
            if label.isAbove {
                sameTierLabels = placed.compactMap { other in
                    guard other.id != label.id && other.isAbove && other.tier == label.tier else { return nil }
                    let otherOffset = offsets[other.id] ?? 0
                    return (startX: other.labelStart + otherOffset, endX: other.labelEnd + otherOffset)
                }
            } else {
                sameTierLabels = placed.compactMap { other in
                    guard other.id != label.id && !other.isAbove && other.tier == label.tier else { return nil }
                    let otherOffset = offsets[other.id] ?? 0
                    return (startX: other.labelStart + otherOffset, endX: other.labelEnd + otherOffset)
                }
            }

            // Try shifting right
            let rightEdge = conflicting.map(\.endX).max()!
            let rightOffset = rightEdge - label.labelStart
            let rStart = label.labelStart + rightOffset
            let rEnd = label.labelEnd + rightOffset
            let rightFits = !collidesInTier(sameTierLabels, start: rStart, end: rEnd)

            // Try shifting left
            let leftEdge = conflicting.map(\.startX).min()!
            let leftOffset = label.labelEnd - leftEdge
            let lStart = label.labelStart - leftOffset
            let lEnd = label.labelEnd - leftOffset
            let leftFits = !collidesInTier(sameTierLabels, start: lStart, end: lEnd)

            if rightFits && (!leftFits || rightOffset <= leftOffset) {
                offsets[label.id] = rightOffset
            } else if leftFits {
                offsets[label.id] = -leftOffset
            }
        }

        return (positions, offsets)
    }

    private func computeConnectionLines(layout: [(event: TimelineEvent, subRow: Int)], yOffset: CGFloat = 0) -> ConnectionLines {
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
            let y = yCenter(forSubRow: subRow, yOffset: yOffset)
            if subRow == 0 {
                tracks.append(LineSegment(from: CGPoint(x: 0, y: y),
                                          to: CGPoint(x: viewport.viewportWidth, y: y)))
            } else {
                tracks.append(LineSegment(from: CGPoint(x: range.minX, y: y),
                                          to: CGPoint(x: range.maxX, y: y)))
            }
        }

        // Build fork/merge connectors for each non-zero sub-row back to row 0
        let row0Y = yCenter(forSubRow: 0, yOffset: yOffset)
        var forkMerges: [ForkMerge] = []
        for (subRow, range) in subRowRanges where subRow != 0 {
            let subRowY = yCenter(forSubRow: subRow, yOffset: yOffset)
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
        showPointLabels: false,
        selectedEventID: nil,
        onSelectEvent: { _ in }
    )
    .frame(width: 600)
}
