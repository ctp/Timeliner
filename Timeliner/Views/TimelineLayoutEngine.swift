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

    // Assign each label to the first free slot in an interleaved above/below sequence:
    // above(0), below(0), above(1), below(1), … growing both directions as needed.
    //
    // For each candidate slot we first try the label centred over its event (offset = 0).
    // If a higher-tier connector would pierce the label text, we try sliding the label
    // horizontally just enough to clear all piercing connectors — left or right, whichever
    // is smaller — then check that the shifted extent doesn't collide with other labels
    // already in that tier. If a valid shift exists we accept the slot with that offset;
    // only if no shift works do we reject the slot and try the next tier/side.
    //
    // The connector line is always drawn vertically at eventX regardless of offset, so
    // the label stays connected to its dot at all offsets.

    struct TierEntry {
        let labelStart: CGFloat   // after applying offset
        let labelEnd: CGFloat
        let eventX: CGFloat
        let offset: CGFloat
    }

    var aboveTiers: [[TierEntry]] = []
    var belowTiers: [[TierEntry]] = []

    func labelCollides(_ entries: [TierEntry], labelStart: CGFloat, labelEnd: CGFloat) -> Bool {
        entries.contains { labelStart < $0.labelEnd && labelEnd > $0.labelStart }
    }

    // Collect all higher-tier connector x-positions that fall inside [labelStart, labelEnd].
    func piercingConnectors(_ higherTiers: [[TierEntry]], labelStart: CGFloat, labelEnd: CGFloat) -> [CGFloat] {
        var xs: [CGFloat] = []
        for tier in higherTiers {
            for entry in tier where entry.eventX > labelStart && entry.eventX < labelEnd {
                xs.append(entry.eventX)
            }
        }
        return xs
    }

    // Given a label's unshifted [labelStart, labelEnd] and the set of piercing connector
    // x-positions, compute the smallest horizontal offset (left or right) that clears all
    // piercers, then verify it doesn't collide with existing same-tier labels.
    // Returns the offset if a valid placement exists, nil if the slot should be rejected.
    func bestOffset(
        labelStart: CGFloat, labelEnd: CGFloat, labelWidth: CGFloat,
        piercers: [CGFloat], sameTier: [TierEntry]
    ) -> CGFloat? {
        if piercers.isEmpty {
            // No connector-piercing issue; just check label-label collision at center.
            return labelCollides(sameTier, labelStart: labelStart, labelEnd: labelEnd) ? nil : 0
        }

        // Minimum gap to keep between a connector line and the label edge.
        let gap: CGFloat = 2

        // Shift right: move label so its left edge is past the rightmost piercer.
        let rightmostPiercer = piercers.max()!
        let rightShift = (rightmostPiercer + gap) - labelStart
        let rStart = labelStart + rightShift
        let rEnd   = labelEnd   + rightShift
        let rightOk = !labelCollides(sameTier, labelStart: rStart, labelEnd: rEnd)

        // Shift left: move label so its right edge is before the leftmost piercer.
        let leftmostPiercer = piercers.min()!
        let leftShift = labelEnd - (leftmostPiercer - gap)
        let lStart = labelStart - leftShift
        let lEnd   = labelEnd   - leftShift
        let leftOk = !labelCollides(sameTier, labelStart: lStart, labelEnd: lEnd)

        switch (rightOk, leftOk) {
        case (true, true):   return rightShift <= leftShift ? rightShift : -leftShift
        case (true, false):  return rightShift
        case (false, true):  return -leftShift
        case (false, false): return nil
        }
    }

    var offsets: [UUID: CGFloat] = [:]

    for item in points {
        let x = viewport.xPosition(for: item.event.startDate.asDate)
        let titleWidth = CGFloat(item.event.title.count) * charWidth
        let labelWidth = titleWidth + labelPadding
        let halfWidth  = labelWidth / 2
        let labelStart = x - halfWidth
        let labelEnd   = x + halfWidth

        var tier = 0
        while true {
            // ── Try above(tier) ──
            if tier == aboveTiers.count { aboveTiers.append([]) }
            let aboveHigher = Array(aboveTiers.dropFirst(tier + 1))
            let abovePiercers = piercingConnectors(aboveHigher, labelStart: labelStart, labelEnd: labelEnd)
            let sameTierAbove = aboveTiers[tier]
            if let offset = bestOffset(
                labelStart: labelStart, labelEnd: labelEnd, labelWidth: labelWidth,
                piercers: abovePiercers, sameTier: sameTierAbove
            ) {
                positions[item.event.id] = .above(tier: tier)
                offsets[item.event.id] = offset
                aboveTiers[tier].append(TierEntry(
                    labelStart: labelStart + offset, labelEnd: labelEnd + offset,
                    eventX: x, offset: offset
                ))
                break
            }

            // ── Try below(tier) ──
            if tier == belowTiers.count { belowTiers.append([]) }
            let belowHigher = Array(belowTiers.dropFirst(tier + 1))
            let belowPiercers = piercingConnectors(belowHigher, labelStart: labelStart, labelEnd: labelEnd)
            let sameTierBelow = belowTiers[tier]
            if let offset = bestOffset(
                labelStart: labelStart, labelEnd: labelEnd, labelWidth: labelWidth,
                piercers: belowPiercers, sameTier: sameTierBelow
            ) {
                positions[item.event.id] = .below(tier: tier)
                offsets[item.event.id] = offset
                belowTiers[tier].append(TierEntry(
                    labelStart: labelStart + offset, labelEnd: labelEnd + offset,
                    eventX: x, offset: offset
                ))
                break
            }

            tier += 1
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
