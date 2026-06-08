//
//  EraTrackView.swift
//  Timeliner
//

import SwiftUI
import AppKit

/// A compact header strip showing eras as labeled bracket-style markers,
/// placed between the time axis and the lane scroll area.
///
/// Overlapping eras are stacked into separate rows via greedy first-fit layout,
/// matching Apple Calendar's multi-day event area style.
struct EraTrackView: View {
    let eras: [Era]
    let viewport: TimelineViewport
    let selectedEraID: UUID?
    let onSelectEra: (Era) -> Void

    var body: some View {
        let layout = layoutEras(eras)
        let numRows = (layout.map(\.row).max() ?? -1) + 1
        let trackHeight = eraTrackHeight(numRows: numRows)

        // Measure actual rendered text widths for each era using AppKit, so the
        // gap in the line is sized to the real text, not a per-character estimate.
        let captionFont = NSFont.preferredFont(forTextStyle: .caption2)
        let fontAttrs: [NSAttributedString.Key: Any] = [.font: captionFont]
        let measuredWidths: [UUID: CGFloat] = Dictionary(uniqueKeysWithValues: eras.map {
            ($0.id, ceil(($0.name as NSString).size(withAttributes: fontAttrs).width))
        })

        ZStack(alignment: .topLeading) {
            // Lines and caps — drawn via Canvas for crisp, lightweight rendering.
            // When the label fits inside the era, the line is split into two segments
            // with a gap sized to the actual measured text width.
            Canvas { context, _ in
                for entry in layout {
                    let startX = viewport.xPosition(for: entry.era.startDate.asDate)
                    let endX = viewport.xPosition(for: entry.era.endDate.asDate)
                    guard endX > startX else { continue }
                    let width = endX - startX

                    let rowTop = TimelineConstants.eraTrackPadding
                        + CGFloat(entry.row) * TimelineConstants.eraTrackRowHeight
                    let lineY = rowTop + TimelineConstants.eraTrackRowHeight / 2
                    let capHalf = TimelineConstants.eraCapHeight / 2
                    let isSelected = entry.era.id == selectedEraID
                    let color = Color.accentColor.opacity(isSelected ? 1.0 : 0.65)

                    let textWidth = measuredWidths[entry.era.id] ?? 0
                    let labelFitsInside = textWidth + 8 <= width  // 4pt margin each side

                    if labelFitsInside {
                        let labelCenter = startX + width / 2
                        let gapHalf = textWidth / 2 + 2  // 2pt clearance each side
                        let gapStart = labelCenter - gapHalf
                        let gapEnd   = labelCenter + gapHalf
                        if gapStart > startX {
                            var seg = Path()
                            seg.move(to: CGPoint(x: startX, y: lineY))
                            seg.addLine(to: CGPoint(x: gapStart, y: lineY))
                            context.stroke(seg, with: .color(color),
                                           lineWidth: TimelineConstants.eraLineThickness)
                        }
                        if gapEnd < endX {
                            var seg = Path()
                            seg.move(to: CGPoint(x: gapEnd, y: lineY))
                            seg.addLine(to: CGPoint(x: endX, y: lineY))
                            context.stroke(seg, with: .color(color),
                                           lineWidth: TimelineConstants.eraLineThickness)
                        }
                    } else {
                        var line = Path()
                        line.move(to: CGPoint(x: startX, y: lineY))
                        line.addLine(to: CGPoint(x: endX, y: lineY))
                        context.stroke(line, with: .color(color),
                                       lineWidth: TimelineConstants.eraLineThickness)
                    }

                    var startCap = Path()
                    startCap.move(to: CGPoint(x: startX, y: lineY - capHalf))
                    startCap.addLine(to: CGPoint(x: startX, y: lineY + capHalf))
                    context.stroke(startCap, with: .color(color),
                                   lineWidth: TimelineConstants.eraLineThickness)

                    var endCap = Path()
                    endCap.move(to: CGPoint(x: endX, y: lineY - capHalf))
                    endCap.addLine(to: CGPoint(x: endX, y: lineY + capHalf))
                    context.stroke(endCap, with: .color(color),
                                   lineWidth: TimelineConstants.eraLineThickness)
                }
            }

            // Labels and tap targets as SwiftUI views
            ForEach(eras, id: \.id) { era in
                let startX = viewport.xPosition(for: era.startDate.asDate)
                let endX = viewport.xPosition(for: era.endDate.asDate)
                let width = endX - startX
                if let row = layout.first(where: { $0.era.id == era.id })?.row, width > 0 {
                    let rowTop = TimelineConstants.eraTrackPadding
                        + CGFloat(row) * TimelineConstants.eraTrackRowHeight
                    let labelY = rowTop + TimelineConstants.eraTrackRowHeight / 2
                    let isSelected = era.id == selectedEraID
                    let color = Color.accentColor.opacity(isSelected ? 1.0 : 0.65)

                    let textWidth = measuredWidths[era.id] ?? 0
                    let labelFitsInside = textWidth + 8 <= width

                    if labelFitsInside {
                        Text(era.name)
                            .font(.caption2)
                            .foregroundColor(color)
                            .lineLimit(1)
                            .position(x: startX + width / 2, y: labelY)
                            .allowsHitTesting(false)
                    } else {
                        // Label overflows: left-align starting just right of the end cap.
                        let rightWidth = max(0, viewport.viewportWidth - endX - 8)
                        Text(era.name)
                            .font(.caption2)
                            .foregroundColor(color)
                            .lineLimit(1)
                            .frame(maxWidth: rightWidth, alignment: .leading)
                            .position(x: endX + 8 + rightWidth / 2, y: labelY)
                            .allowsHitTesting(false)
                    }

                    // Transparent full-row tap target
                    Color.clear
                        .frame(width: max(width, 8),
                               height: TimelineConstants.eraTrackRowHeight)
                        .position(x: startX + max(width, 8) / 2,
                                  y: rowTop + TimelineConstants.eraTrackRowHeight / 2)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelectEra(era) }
                }
            }
        }
        .frame(height: trackHeight)
    }
}
