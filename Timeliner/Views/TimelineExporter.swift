//
//  TimelineExporter.swift
//  Timeliner
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export Entry Point

@MainActor
enum TimelineExporter {

    /// Presents an NSSavePanel and exports the full timeline as a PDF.
    /// The viewport is computed to fit all events (same logic as ⌘0).
    /// Point labels are always shown in the PDF regardless of the current app setting.
    /// Pass the app's current `colorScheme` to export in light or dark mode.
    static func exportPDF(
        events: [TimelineEvent],
        lanes: [Lane],
        eras: [Era],
        colorScheme: ColorScheme,
        canvasWidth: CGFloat,
        documentTitle: String
    ) {
        // Always show point labels in the exported PDF — it's a static document.
        let showPointLabels = true

        guard let (exportWidth, totalHeight, viewport) = computeExportGeometry(
            events: events,
            lanes: lanes,
            showPointLabels: showPointLabels,
            canvasWidth: canvasWidth
        ) else {
            // Nothing to export (no events)
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = documentTitle.isEmpty ? "Timeline" : documentTitle
        panel.title = "Export Timeline as PDF"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let exportView = TimelineExportView(
            events: events,
            lanes: lanes,
            eras: eras,
            showPointLabels: showPointLabels,
            colorScheme: colorScheme,
            viewport: viewport,
            exportWidth: exportWidth,
            totalHeight: totalHeight
        )

        let renderer = ImageRenderer(content: exportView)
        renderer.proposedSize = ProposedViewSize(
            width: exportWidth,
            height: totalHeight
        )

        renderer.render { size, draw in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard
                let consumer = CGDataConsumer(url: url as CFURL),
                let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            else { return }

            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
        }
    }

    /// Presents an NSSavePanel and exports the full timeline as a PNG.
    /// Point labels are always shown. Uses @2x rasterization scale for crisp output.
    static func exportPNG(
        events: [TimelineEvent],
        lanes: [Lane],
        eras: [Era],
        colorScheme: ColorScheme,
        canvasWidth: CGFloat,
        documentTitle: String
    ) {
        let showPointLabels = true

        guard let (exportWidth, totalHeight, viewport) = computeExportGeometry(
            events: events,
            lanes: lanes,
            showPointLabels: showPointLabels,
            canvasWidth: canvasWidth
        ) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = documentTitle.isEmpty ? "Timeline" : documentTitle
        panel.title = "Export Timeline as PNG"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let exportView = TimelineExportView(
            events: events,
            lanes: lanes,
            eras: eras,
            showPointLabels: showPointLabels,
            colorScheme: colorScheme,
            viewport: viewport,
            exportWidth: exportWidth,
            totalHeight: totalHeight
        )

        let renderer = ImageRenderer(content: exportView)
        renderer.proposedSize = ProposedViewSize(width: exportWidth, height: totalHeight)
        renderer.scale = 2.0  // @2x for crisp output

        guard let cgImage = renderer.cgImage else { return }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

        try? pngData.write(to: url)
    }

    // MARK: - Geometry Calculation

    /// Returns (exportWidth, totalHeight, viewport) sized to fit all events.
    /// Returns nil if there are no events.
    private static func computeExportGeometry(
        events: [TimelineEvent],
        lanes: [Lane],
        showPointLabels: Bool,
        canvasWidth: CGFloat
    ) -> (exportWidth: CGFloat, totalHeight: CGFloat, viewport: TimelineViewport)? {
        guard !events.isEmpty else { return nil }

        // Find date bounds across all events (same as TimelineCanvasView.eventDateBounds)
        var earliest = Date.distantFuture
        var latest = Date.distantPast
        for event in events {
            let start = event.startDate.asDate
            if start < earliest { earliest = start }
            if start > latest { latest = start }
            if let end = event.endDate {
                let endDate = end.asDate
                if endDate > latest { latest = endDate }
            }
        }

        let rangeSeconds = latest.timeIntervalSince(earliest)
        let effectiveRange = rangeSeconds > 0 ? rangeSeconds * 1.4 : 86400 * 2

        // Use the actual canvas width so the PDF matches the window width.
        let exportWidth: CGFloat = max(canvasWidth, 400)

        let scale = effectiveRange / Double(exportWidth)
        let centerDate = earliest.addingTimeInterval(rangeSeconds / 2)
        let viewport = TimelineViewport(
            centerDate: centerDate,
            scale: scale,
            viewportWidth: exportWidth
        )

        // Compute total height: axis + divider + lane rows
        let axisHeight: CGFloat = 30 + 1  // TimeAxisView + Divider

        let laneEvents = events.filter { $0.lane != nil }
        let unassigned = events.filter { $0.lane == nil }

        var lanesHeight: CGFloat = 0
        for lane in lanes {
            let laneEventsForLane = laneEvents.filter { $0.lane?.id == lane.id }
            lanesHeight += laneRowHeight(
                events: laneEventsForLane,
                viewport: viewport,
                showPointLabels: showPointLabels
            )
        }
        if !unassigned.isEmpty {
            lanesHeight += laneRowHeight(
                events: unassigned,
                viewport: viewport,
                showPointLabels: showPointLabels
            )
        }

        // VStack spacing: 1pt per lane gap (lanes.count - 1 gaps, plus unassigned gap if present)
        let laneCount = lanes.count + (unassigned.isEmpty ? 0 : 1)
        let spacingHeight = CGFloat(max(0, laneCount - 1)) * 1

        let totalHeight = axisHeight + lanesHeight + spacingHeight

        return (exportWidth, totalHeight, viewport)
    }

    /// Compute the rendered height for one lane's events, mirroring LaneRowView's logic.
    private static func laneRowHeight(
        events: [TimelineEvent],
        viewport: TimelineViewport,
        showPointLabels: Bool
    ) -> CGFloat {
        let layout = layoutEvents(events, viewport: viewport)
        let labelResult = showPointLabels
            ? computeLabelPositions(layout: layout, viewport: viewport)
            : (positions: [:], offsets: [:])
        let maxAboveTier = labelResult.positions.values.filter(\.isAbove).map(\.tier).max()
        let maxBelowTier = labelResult.positions.values.filter(\.isBelow).map(\.tier).max()
        let topPadding: CGFloat = maxAboveTier != nil
            ? LabelPosition.connectorBase + LabelPosition.tierHeight * CGFloat(maxAboveTier! + 1)
            : 0
        let bottomPadding: CGFloat = maxBelowTier != nil
            ? LabelPosition.connectorBase + LabelPosition.tierHeight * CGFloat(maxBelowTier! + 1)
            : 0
        let contentHeight = TimelineConstants.baseRowHeight * CGFloat(max(layout.totalRows, 1))
        return topPadding + contentHeight + bottomPadding
    }
}

// MARK: - Export View

/// A self-contained, interaction-free snapshot of the timeline for PDF rendering.
private struct TimelineExportView: View {
    let events: [TimelineEvent]
    let lanes: [Lane]
    let eras: [Era]
    let showPointLabels: Bool
    let colorScheme: ColorScheme
    let viewport: TimelineViewport
    let exportWidth: CGFloat
    let totalHeight: CGFloat

    // Pre-computed lane heights so the ZStack background fills correctly
    private var laneAreaHeight: CGFloat {
        totalHeight - 30 - 1  // minus axis and divider
    }

    var body: some View {
        VStack(spacing: 0) {
            // Time ruler
            TimeAxisView(viewport: viewport)

            Divider()

            // Lanes + era bands
            ZStack(alignment: .topLeading) {
                // Era background bands
                ForEach(eras, id: \.id) { era in
                    EraBandView(
                        era: era,
                        viewport: viewport,
                        totalHeight: laneAreaHeight
                    )
                }

                // Lane rows
                VStack(spacing: 1) {
                    ForEach(lanes, id: \.id) { lane in
                        ExportLaneRowView(
                            lane: lane,
                            viewport: viewport,
                            showPointLabels: showPointLabels
                        )
                    }

                    // Unassigned events
                    let unassigned = events.filter { $0.lane == nil }
                    if !unassigned.isEmpty {
                        ExportUnassignedRowView(
                            events: unassigned,
                            viewport: viewport,
                            showPointLabels: showPointLabels
                        )
                    }
                }
            }
        }
        .frame(width: exportWidth, height: totalHeight)
        .background(colorScheme == .dark ? Color.black : Color.white)
        // Pin the color scheme so adaptive colors resolve consistently
        // regardless of any system appearance change during rendering.
        .environment(\.colorScheme, colorScheme)
    }
}

// MARK: - Export Lane Row

/// A rendering-only variant of LaneRowView with no gesture handlers.
private struct ExportLaneRowView: View {
    let lane: Lane
    let viewport: TimelineViewport
    let showPointLabels: Bool

    private var eventLayout: (layout: [(event: TimelineEvent, subRow: Int)], totalRows: Int) {
        layoutEvents(lane.events, viewport: viewport)
    }

    var body: some View {
        let layout = eventLayout
        let labelResult = showPointLabels
            ? computeLabelPositions(layout: layout, viewport: viewport)
            : (positions: [:], offsets: [:])
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
        let contentHeight = TimelineConstants.baseRowHeight * CGFloat(max(layout.totalRows, 1))
        let totalHeight = topPadding + contentHeight + bottomPadding
        let lines = computeConnectionLines(
            layout: layout.layout,
            viewport: viewport,
            baseRowHeight: TimelineConstants.baseRowHeight,
            yOffset: topPadding
        )

        ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(laneBackgroundColor)

            // Connection lines
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

            // Lane name label
            Text(lane.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 4)

            // Events (no selection, no interaction)
            ForEach(layout.layout, id: \.event.id) { item in
                EventView(
                    event: item.event,
                    viewport: viewport,
                    isSelected: false,
                    onSelect: {},
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

    private var laneStrokeColor: Color {
        Color(hex: lane.color) ?? .gray
    }

    private var laneBackgroundColor: Color {
        (Color(hex: lane.color) ?? .gray).opacity(0.1)
    }
}

// MARK: - Export Unassigned Row

private struct ExportUnassignedRowView: View {
    let events: [TimelineEvent]
    let viewport: TimelineViewport
    let showPointLabels: Bool

    var body: some View {
        let layout = layoutEvents(events, viewport: viewport)
        let labelResult = showPointLabels
            ? computeLabelPositions(layout: layout, viewport: viewport)
            : (positions: [:], offsets: [:])
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
        let contentHeight = TimelineConstants.baseRowHeight * CGFloat(max(layout.totalRows, 1))
        let totalHeight = topPadding + contentHeight + bottomPadding
        let lines = computeConnectionLines(
            layout: layout.layout,
            viewport: viewport,
            baseRowHeight: TimelineConstants.baseRowHeight,
            yOffset: topPadding
        )

        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.05))

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

            Text("Unassigned")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 4)

            ForEach(layout.layout, id: \.event.id) { item in
                EventView(
                    event: item.event,
                    viewport: viewport,
                    isSelected: false,
                    onSelect: {},
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
}
