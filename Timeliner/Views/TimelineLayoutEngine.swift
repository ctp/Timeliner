//
//  TimelineLayoutEngine.swift
//  Timeliner
//

import SwiftUI

// MARK: - Shared Types

enum LabelPosition: Equatable {
    case none
    case above(tier: Int)
    case below(tier: Int)

    var isAbove: Bool {
        if case .above = self { return true }
        return false
    }

    var isBelow: Bool {
        if case .below = self { return true }
        return false
    }

    var tier: Int {
        switch self {
        case .none: return 0
        case .above(let t), .below(let t): return t
        }
    }

    static let tierHeight: CGFloat = 16
    static let connectorBase: CGFloat = 12
    static let maxAboveTiers = 4
}

struct LineSegment {
    let from: CGPoint
    let to: CGPoint
}

struct ForkMerge {
    let x: CGFloat
    let row0Y: CGFloat
    let subRowY: CGFloat
    let isFork: Bool
}

struct ConnectionLines {
    let tracks: [LineSegment]
    let forkMerges: [ForkMerge]
}

// MARK: - Constants

let defaultBaseRowHeight: CGFloat = TimelineConstants.baseRowHeight

// MARK: - Layout Functions

func eventXRange(for event: TimelineEvent, viewport: TimelineViewport) -> (startX: CGFloat, endX: CGFloat) {
    let startX = viewport.xPosition(for: event.startDate.asDate)
    var endX: CGFloat
    if let end = event.endDate {
        endX = viewport.xPosition(for: end.asDate)
    } else {
        endX = startX + TimelineConstants.pointEventCollisionWidth
    }
    endX = max(endX, startX + TimelineConstants.minEventWidth)
    return (startX, endX)
}

func layoutEvents(_ events: [TimelineEvent], viewport: TimelineViewport) -> (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int) {
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
            endX = startX + TimelineConstants.pointEventCollisionWidth
        }
        endX = max(endX, startX + TimelineConstants.minEventWidth)
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

func computeLabelPositions(layout: (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int), viewport: TimelineViewport) -> (positions: [UUID: LabelPosition], offsets: [UUID: CGFloat]) {
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

        let rightEdge = conflicting.map(\.endX).max()!
        let rightOffset = rightEdge - label.labelStart
        let rStart = label.labelStart + rightOffset
        let rEnd = label.labelEnd + rightOffset
        let rightFits = !collidesInTier(sameTierLabels, start: rStart, end: rEnd)

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

func computeConnectionLines(layout: [(event: TimelineEvent, subRow: Int)], viewport: TimelineViewport, baseRowHeight: CGFloat, yOffset: CGFloat = 0) -> ConnectionLines {
    guard !layout.isEmpty else { return ConnectionLines(tracks: [], forkMerges: []) }

    let sorted = layout.sorted { $0.event.startDate.asDate < $1.event.startDate.asDate }

    var subRowRanges: [Int: (minX: CGFloat, maxX: CGFloat)] = [:]
    for item in sorted {
        let range = eventXRange(for: item.event, viewport: viewport)
        if let existing = subRowRanges[item.subRow] {
            subRowRanges[item.subRow] = (
                minX: min(existing.minX, range.startX),
                maxX: max(existing.maxX, range.endX)
            )
        } else {
            subRowRanges[item.subRow] = (minX: range.startX, maxX: range.endX)
        }
    }

    var tracks: [LineSegment] = []
    for (subRow, range) in subRowRanges {
        let y = yOffset + baseRowHeight * CGFloat(subRow) + baseRowHeight / 2
        if subRow == 0 {
            tracks.append(LineSegment(from: CGPoint(x: 0, y: y),
                                      to: CGPoint(x: viewport.viewportWidth, y: y)))
        } else {
            tracks.append(LineSegment(from: CGPoint(x: range.minX, y: y),
                                      to: CGPoint(x: range.maxX, y: y)))
        }
    }

    let row0Y = yOffset + baseRowHeight / 2
    var forkMerges: [ForkMerge] = []
    for (subRow, range) in subRowRanges where subRow != 0 {
        let subRowY = yOffset + baseRowHeight * CGFloat(subRow) + baseRowHeight / 2
        forkMerges.append(ForkMerge(x: range.minX, row0Y: row0Y, subRowY: subRowY, isFork: true))
        forkMerges.append(ForkMerge(x: range.maxX, row0Y: row0Y, subRowY: subRowY, isFork: false))
    }

    return ConnectionLines(tracks: tracks, forkMerges: forkMerges)
}

// MARK: - ConnectionLinesShape

struct ConnectionLinesShape: Shape {
    let lines: ConnectionLines

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for segment in lines.tracks {
            path.move(to: segment.from)
            path.addLine(to: segment.to)
        }
        for fm in lines.forkMerges {
            let dy = abs(fm.subRowY - fm.row0Y)
            let spread = min(40, dy)
            if fm.isFork {
                path.move(to: CGPoint(x: fm.x - spread, y: fm.row0Y))
                path.addCurve(
                    to: CGPoint(x: fm.x, y: fm.subRowY),
                    control1: CGPoint(x: fm.x, y: fm.row0Y),
                    control2: CGPoint(x: fm.x - spread, y: fm.subRowY)
                )
            } else {
                path.move(to: CGPoint(x: fm.x, y: fm.subRowY))
                path.addCurve(
                    to: CGPoint(x: fm.x + spread, y: fm.row0Y),
                    control1: CGPoint(x: fm.x + spread, y: fm.subRowY),
                    control2: CGPoint(x: fm.x, y: fm.row0Y)
                )
            }
        }
        return path
    }
}
