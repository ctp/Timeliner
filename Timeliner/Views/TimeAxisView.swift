//
//  TimeAxisView.swift
//  Timeliner
//

import SwiftUI

struct TimeAxisView: View {
    let viewport: TimelineViewport

    var body: some View {
        Canvas { context, size in
            let ticks = calculateTicks(for: viewport, width: size.width)
            let interval = tickInterval(for: viewport.scale)
            let calendar = Calendar.current

            for tick in ticks {
                let x = viewport.xPosition(for: tick.date)
                guard x >= 0 && x <= size.width else { continue }

                // Draw tick line
                let tickHeight: CGFloat = tick.isMajor ? 12 : 6
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height - tickHeight))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.secondary), lineWidth: 1)

                // Label ticks using calendar-anchored cadence so the same
                // dates always get labels regardless of viewport position.
                if tick.isMajor || isLabelTick(date: tick.date, interval: interval, calendar: calendar) {
                    let text = Text(tick.label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    context.draw(text, at: CGPoint(x: x, y: size.height - tickHeight - 8))
                }
            }
        }
        .id(viewport)
        .frame(height: 30)
        .accessibilityLabel("Timeline ruler")
        .accessibilityHint("Drag to pan the timeline. Pinch to zoom.")
    }

    private func calculateTicks(for viewport: TimelineViewport, width: CGFloat) -> [Tick] {
        var ticks: [Tick] = []
        let range = viewport.visibleRange
        let calendar = Calendar.current

        // Determine tick interval based on scale
        let interval = tickInterval(for: viewport.scale)

        // Find first tick at or before range start
        var currentDate = calendar.startOfDay(for: range.lowerBound)
        if let rounded = roundDown(date: currentDate, to: interval, calendar: calendar) {
            currentDate = rounded
        }

        // Generate ticks
        while currentDate <= range.upperBound {
            let isMajor = isMajorTick(date: currentDate, interval: interval, calendar: calendar)
            let label = formatTickLabel(date: currentDate, interval: interval)
            ticks.append(Tick(date: currentDate, label: label, isMajor: isMajor))

            if let next = advanceDate(currentDate, by: interval, calendar: calendar) {
                currentDate = next
            } else {
                break
            }
        }

        return ticks
    }

    private enum TickInterval {
        case hour, day, week, month, year, decade
    }

    private func tickInterval(for scale: TimeInterval) -> TickInterval {
        // Thresholds chosen so each tick interval produces ~50-200px spacing.
        // Pixel spacing ≈ intervalSeconds / scale.
        switch scale {
        case ..<60: return .hour       // hour ticks ≥60px apart
        case ..<3000: return .day      // day ticks ≥29px apart
        case ..<15000: return .week    // week ticks ≥40px apart
        case ..<100000: return .month  // month ticks ≥26px apart
        case ..<1000000: return .year  // year ticks ≥32px apart
        default: return .decade
        }
    }

    private func roundDown(date: Date, to interval: TickInterval, calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        var newComponents = DateComponents()
        newComponents.year = components.year

        switch interval {
        case .hour:
            newComponents.month = components.month
            newComponents.day = components.day
            newComponents.hour = components.hour
        case .day, .week:
            newComponents.month = components.month
            newComponents.day = components.day
        case .month:
            newComponents.month = components.month
        case .year, .decade:
            break
        }

        return calendar.date(from: newComponents)
    }

    private func advanceDate(_ date: Date, by interval: TickInterval, calendar: Calendar) -> Date? {
        switch interval {
        case .hour: return calendar.date(byAdding: .hour, value: 1, to: date)
        case .day: return calendar.date(byAdding: .day, value: 1, to: date)
        case .week: return calendar.date(byAdding: .day, value: 7, to: date)
        case .month: return calendar.date(byAdding: .month, value: 1, to: date)
        case .year: return calendar.date(byAdding: .year, value: 1, to: date)
        case .decade: return calendar.date(byAdding: .year, value: 10, to: date)
        }
    }

    /// Calendar-anchored label cadence: every ~3rd tick gets a label, determined
    /// purely by the date so labels never appear or disappear as the viewport resizes.
    private func isLabelTick(date: Date, interval: TickInterval, calendar: Calendar) -> Bool {
        switch interval {
        case .hour:
            return calendar.component(.hour, from: date) % 3 == 0
        case .day:
            return (calendar.ordinality(of: .day, in: .year, for: date) ?? 1) % 3 == 1
        case .week:
            return (calendar.component(.weekOfYear, from: date)) % 3 == 1
        case .month:
            return (calendar.component(.month, from: date) - 1) % 3 == 0
        case .year:
            return calendar.component(.year, from: date) % 3 == 0
        case .decade:
            return (calendar.component(.year, from: date) / 10) % 3 == 0
        }
    }

    private func isMajorTick(date: Date, interval: TickInterval, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.month, .day, .hour, .weekday], from: date)
        switch interval {
        case .hour: return components.hour == 0
        case .day: return components.weekday == 1 // Sunday
        case .week: return components.day == 1
        case .month: return components.month == 1
        case .year: return (calendar.component(.year, from: date) % 10) == 0
        case .decade: return (calendar.component(.year, from: date) % 100) == 0
        }
    }

    private func formatTickLabel(date: Date, interval: TickInterval) -> String {
        let formatter = DateFormatter()
        switch interval {
        case .hour:
            let hour = Calendar.current.component(.hour, from: date)
            if hour == 0 {
                formatter.dateFormat = "MMM d"
            } else {
                formatter.dateFormat = "HH:mm"
            }
        case .day, .week:
            formatter.dateFormat = "MMM d"
        case .month:
            formatter.dateFormat = "MMM yyyy"
        case .year, .decade:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }
}

private struct Tick {
    let date: Date
    let label: String
    let isMajor: Bool
}

#Preview {
    TimeAxisView(viewport: TimelineViewport(
        centerDate: Date(),
        scale: 86400,
        viewportWidth: 800
    ))
    .frame(width: 800)
    .padding()
}
