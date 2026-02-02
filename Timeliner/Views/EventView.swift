//
//  EventView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct EventView: View {
    let event: TimelineEvent
    let viewport: TimelineViewport
    let isSelected: Bool
    let onSelect: () -> Void
    var subRow: Int = 0
    var rowHeight: CGFloat = 40
    var labelPosition: LabelPosition = .none
    var labelXOffset: CGFloat = 0
    var yOffset: CGFloat = 0

    @State private var isHovered = false

    private let eventHeight: CGFloat = 24
    private let baseRowHeight: CGFloat = 40

    private var yCenter: CGFloat {
        yOffset + baseRowHeight * CGFloat(subRow) + baseRowHeight / 2
    }

    var body: some View {
        if event.isPointEvent {
            pointEventView
        } else {
            spanEventView
        }
    }

    private func eventInteractions<V: View>(_ content: V) -> some View {
        content
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .popover(isPresented: $isHovered, arrowEdge: .bottom) {
                tooltipView
                    .padding(8)
            }
            .onTapGesture {
                onSelect()
            }
    }

    private var pointEventView: some View {
        let x = viewport.xPosition(for: event.startDate.asDate)
        let isAbove = labelPosition.isAbove
        let showLabel = labelPosition != .none
        let tier = CGFloat(labelPosition.tier)
        let connectorLength = LabelPosition.connectorBase + LabelPosition.tierHeight * tier

        return ZStack {
            eventInteractions(
                ZStack {
                    Circle()
                        .fill(Color(nsColor: .textBackgroundColor))
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(eventColor.opacity(0.1))
                        .strokeBorder(eventColor, lineWidth: 2)
                        .frame(width: 12, height: 12)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                }
            )
            .position(x: x, y: yCenter)

            if showLabel {
                let dotEdge = yCenter + (isAbove ? -6 : 6)
                let lineEnd = dotEdge + (isAbove ? -connectorLength : connectorLength)
                let textY = lineEnd + (isAbove ? -6 : 6)
                let labelX = x + labelXOffset

                // Connector line
                Path { path in
                    path.move(to: CGPoint(x: x, y: dotEdge))
                    path.addLine(to: CGPoint(x: x, y: lineEnd))
                }
                .stroke(eventColor.opacity(0.5), lineWidth: 1)

                // Label text
                Text(event.title)
                    .font(.caption2)
                    .foregroundColor(eventColor)
                    .lineLimit(1)
                    .fixedSize()
                    .position(x: labelX, y: textY)
            }
        }
    }

    private var spanEventView: some View {
        let startX = viewport.xPosition(for: event.startDate.asDate)
        let endX = event.endDate.map { viewport.xPosition(for: $0.asDate) } ?? startX
        let width = max(endX - startX, 20) // Minimum width for visibility

        return eventInteractions(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(eventColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(isSelected ? Color.accentColor : eventColor, lineWidth: 2)
                )
                .overlay(
                    Text(event.title)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .foregroundColor(.white),
                    alignment: .leading
                )
                .frame(width: width, height: eventHeight)
        )
        .position(x: startX + width / 2, y: yCenter)
    }

    private var tooltipView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.headline)

            if let desc = event.eventDescription, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if event.isPointEvent {
                Text("**Date:** \(formatted(event.startDate))")
            } else {
                Text("**Start:** \(formatted(event.startDate))")
            }

            if let end = event.endDate {
                Text("**End:** \(formatted(end))")
            }

            if !event.tags.isEmpty {
                let tagNames = event.tags.map(\.name).joined(separator: ", ")
                Text("**Tags:** \(tagNames)")
            }
        }
        .font(.callout)
    }

    private func formatted(_ date: FlexibleDate) -> String {
        switch date.precision {
        case .year:
            return "\(date.year)"
        case .month:
            let m = date.month ?? 1
            return String(format: "%04d-%02d", date.year, m)
        case .day:
            let m = date.month ?? 1
            let d = date.day ?? 1
            return String(format: "%04d-%02d-%02d", date.year, m, d)
        case .time:
            let local = date.localDisplayComponents
            return String(format: "%04d-%02d-%02d %02d:%02d",
                          local.year, local.month, local.day, local.hour, local.minute)
        }
    }

    private var eventColor: Color {
        if let lane = event.lane, let hex = Color(hex: lane.color) {
            return hex
        }
        return .blue
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    let event = TimelineEvent(
        title: "Test Event",
        startDate: FlexibleDate(year: 2024, month: 6, day: 15)
    )
    return EventView(
        event: event,
        viewport: TimelineViewport(centerDate: Date(), scale: 86400, viewportWidth: 400),
        isSelected: false,
        onSelect: {}
    )
    .frame(width: 400, height: 50)
}
