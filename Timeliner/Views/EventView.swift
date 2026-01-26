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

    private let eventHeight: CGFloat = 24

    var body: some View {
        Group {
            if event.isPointEvent {
                pointEventView
            } else {
                spanEventView
            }
        }
        .onTapGesture {
            onSelect()
        }
    }

    private var pointEventView: some View {
        let x = viewport.xPosition(for: event.startDate.asDate)

        return ZStack {
            Circle()
                .fill(eventColor)
                .frame(width: 12, height: 12)

            if isSelected {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: 16, height: 16)
            }
        }
        .position(x: x, y: eventHeight / 2)
    }

    private var spanEventView: some View {
        let startX = viewport.xPosition(for: event.startDate.asDate)
        let endX = event.endDate.map { viewport.xPosition(for: $0.asDate) } ?? startX
        let width = max(endX - startX, 20) // Minimum width for visibility

        return RoundedRectangle(cornerRadius: 4)
            .fill(eventColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
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
            .position(x: startX + width / 2, y: eventHeight / 2)
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
