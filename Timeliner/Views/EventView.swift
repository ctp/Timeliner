//
//  EventView.swift
//  Timeliner
//

import SwiftUI

enum EventDragMode {
    case none
    case move
    case resizeStart
    case resizeEnd
}

private struct SpanOriginXKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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
    var onDragEnd: ((TimelineEvent, FlexibleDate, FlexibleDate?) -> Void)?

    private let eventHeight: CGFloat = 24
    private let baseRowHeight: CGFloat = 40
    private static let edgeHitZone: CGFloat = 6

    @State private var dragMode: EventDragMode = .none
    @State private var dragOffset: CGFloat = 0
    @State private var dragEndOffset: CGFloat = 0
    @State private var spanGlobalOriginX: CGFloat = 0

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

    // MARK: - Drag Helpers

    private var eventPrecision: DatePrecision {
        event.startDate.precision
    }

    /// Compute the snapped date for a given x position, using the event's own precision.
    private func snappedDate(forX x: CGFloat) -> Date {
        let rawDate = viewport.date(forX: x)
        return viewport.snappedDate(from: rawDate, precision: eventPrecision)
    }

    /// Minimum end date: one precision unit after the given start date.
    private func minimumEnd(after startDate: Date) -> Date {
        let cal = Calendar.current
        switch eventPrecision {
        case .time:  return cal.date(byAdding: .hour, value: 1, to: startDate)!
        case .day:   return cal.date(byAdding: .day, value: 1, to: startDate)!
        case .month: return cal.date(byAdding: .month, value: 1, to: startDate)!
        case .year:  return cal.date(byAdding: .year, value: 1, to: startDate)!
        }
    }

    /// Display x position for the event's start during drag (raw pixel offset, no snapping).
    private func draggedStartX(originalStartX: CGFloat) -> CGFloat {
        switch dragMode {
        case .move:
            return originalStartX + dragOffset
        case .resizeStart:
            let candidate = originalStartX + dragOffset
            // Clamp so start doesn't pass end minus minimum width
            if let endDate = event.endDate {
                let endX = viewport.xPosition(for: endDate.asDate)
                let minWidth: CGFloat = 20
                return min(candidate, endX - minWidth)
            }
            return candidate
        default:
            return originalStartX
        }
    }

    /// Display x position for the event's end during drag (raw pixel offset, no snapping).
    private func draggedEndX(originalEndX: CGFloat, startX: CGFloat) -> CGFloat {
        switch dragMode {
        case .move:
            return originalEndX + dragOffset
        case .resizeEnd:
            let candidate = originalEndX + dragEndOffset
            let minWidth: CGFloat = 20
            return max(candidate, startX + minWidth)
        default:
            return originalEndX
        }
    }

    private func commitDrag() {
        let precision = eventPrecision
        let originalStartX = viewport.xPosition(for: event.startDate.asDate)

        switch dragMode {
        case .move:
            let newStartDate = snappedDate(forX: originalStartX + dragOffset)
            let newStartFD = flexibleDate(from: newStartDate, precision: precision)
            var newEndFD: FlexibleDate? = nil
            if let endDate = event.endDate {
                let duration = endDate.asDate.timeIntervalSince(event.startDate.asDate)
                let newEndDate = newStartDate.addingTimeInterval(duration)
                newEndFD = flexibleDate(from: newEndDate, precision: precision)
            }
            onDragEnd?(event, newStartFD, newEndFD)

        case .resizeStart:
            var newStartDate = snappedDate(forX: originalStartX + dragOffset)
            if let endDate = event.endDate {
                let maxStart = minimumEnd(after: newStartDate)
                if maxStart > endDate.asDate {
                    let cal = Calendar.current
                    switch precision {
                    case .time:  newStartDate = cal.date(byAdding: .hour, value: -1, to: endDate.asDate)!
                    case .day:   newStartDate = cal.date(byAdding: .day, value: -1, to: endDate.asDate)!
                    case .month: newStartDate = cal.date(byAdding: .month, value: -1, to: endDate.asDate)!
                    case .year:  newStartDate = cal.date(byAdding: .year, value: -1, to: endDate.asDate)!
                    }
                    newStartDate = viewport.snappedDate(from: newStartDate, precision: precision)
                }
            }
            let newStartFD = flexibleDate(from: newStartDate, precision: precision)
            onDragEnd?(event, newStartFD, event.endDate)

        case .resizeEnd:
            guard let endDate = event.endDate else { break }
            let originalEndX = viewport.xPosition(for: endDate.asDate)
            var newEndDate = snappedDate(forX: originalEndX + dragEndOffset)
            let minEnd = minimumEnd(after: event.startDate.asDate)
            if newEndDate < minEnd {
                newEndDate = viewport.snappedDate(from: minEnd, precision: precision)
            }
            let newEndFD = flexibleDate(from: newEndDate, precision: precision)
            onDragEnd?(event, event.startDate, newEndFD)

        case .none:
            break
        }

        dragMode = .none
        dragOffset = 0
        dragEndOffset = 0
    }

    private func eventInteractions<V: View>(_ content: V) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
            .help(event.title)
    }

    private var pointEventView: some View {
        let originalX = viewport.xPosition(for: event.startDate.asDate)
        let x = dragMode == .move ? draggedStartX(originalStartX: originalX) : originalX
        let isAbove = labelPosition.isAbove
        let showLabel = labelPosition != .none && dragMode == .none
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

                    if isSelected || dragMode != .none {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { value in
                        if dragMode == .none {
                            dragMode = .move
                            onSelect()
                        }
                        dragOffset = value.translation.width
                    }
                    .onEnded { _ in
                        commitDrag()
                    }
            )
            .position(x: x, y: yCenter)

            if showLabel {
                let dotEdge = yCenter + (isAbove ? -6 : 6)
                let lineEnd = dotEdge + (isAbove ? -connectorLength : connectorLength)
                let textY = lineEnd + (isAbove ? -6 : 6)
                let labelX = originalX + labelXOffset

                // Connector line
                Path { path in
                    path.move(to: CGPoint(x: originalX, y: dotEdge))
                    path.addLine(to: CGPoint(x: originalX, y: lineEnd))
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
        let originalStartX = viewport.xPosition(for: event.startDate.asDate)
        let originalEndX = event.endDate.map { viewport.xPosition(for: $0.asDate) } ?? originalStartX

        // Compute dragged positions
        let displayStartX: CGFloat
        let displayEndX: CGFloat
        switch dragMode {
        case .move:
            displayStartX = draggedStartX(originalStartX: originalStartX)
            displayEndX = draggedEndX(originalEndX: originalEndX, startX: displayStartX)
        case .resizeStart:
            displayStartX = draggedStartX(originalStartX: originalStartX)
            displayEndX = originalEndX
        case .resizeEnd:
            displayStartX = originalStartX
            displayEndX = draggedEndX(originalEndX: originalEndX, startX: originalStartX)
        case .none:
            displayStartX = originalStartX
            displayEndX = originalEndX
        }

        let width = max(displayEndX - displayStartX, 20)
        let highlighted = isSelected || dragMode != .none

        return eventInteractions(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(eventColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(highlighted ? Color.accentColor : eventColor, lineWidth: 2)
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
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: SpanOriginXKey.self, value: geo.frame(in: .global).minX)
                    }
                )
                .onPreferenceChange(SpanOriginXKey.self) { value in
                    spanGlobalOriginX = value
                }
        )
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { value in
                    if dragMode == .none {
                        let localX = value.startLocation.x - spanGlobalOriginX
                        let frameWidth = max(originalEndX - originalStartX, 20)

                        if localX <= Self.edgeHitZone {
                            dragMode = .resizeStart
                        } else if localX >= frameWidth - Self.edgeHitZone {
                            dragMode = .resizeEnd
                        } else {
                            dragMode = .move
                        }
                        onSelect()
                    }

                    switch dragMode {
                    case .move, .resizeStart:
                        dragOffset = value.translation.width
                    case .resizeEnd:
                        dragEndOffset = value.translation.width
                    case .none:
                        break
                    }
                }
                .onEnded { _ in
                    commitDrag()
                }
        )
        .position(x: displayStartX + width / 2, y: yCenter)
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
