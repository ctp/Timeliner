//
//  FlexibleDate.swift
//  Timeliner
//

import Foundation

enum DatePrecision: Int, Codable, Comparable {
    case year = 0
    case month = 1
    case day = 2
    case time = 3

    static func < (lhs: DatePrecision, rhs: DatePrecision) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Variable-precision date stored as integer components.
///
/// **Storage convention:**
/// - Year, month, and day precision: components are calendar values with no timezone
///   semantics. "Jan 31" is "Jan 31" regardless of the local timezone.
/// - Time precision: hour and minute are stored as **UTC**. Use `fromLocalTime(...)` to
///   create time-precision dates from local input — it handles the local→UTC conversion.
///   Use `localDisplayComponents` to convert back to local time for display.
struct FlexibleDate: Codable, Hashable, Sendable {
    let year: Int
    let month: Int?
    let day: Int?
    let hour: Int?
    let minute: Int?

    init(year: Int, month: Int? = nil, day: Int? = nil, hour: Int? = nil, minute: Int? = nil) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }

    /// Create a time-precision FlexibleDate from local time components.
    /// Converts the local hour/minute to UTC for storage.
    static func fromLocalTime(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> FlexibleDate {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        let localDate = Calendar.current.date(from: components) ?? Date.distantPast

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let utc = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: localDate)

        return FlexibleDate(
            year: utc.year!, month: utc.month!, day: utc.day!,
            hour: utc.hour!, minute: utc.minute!
        )
    }

    var precision: DatePrecision {
        if hour != nil || minute != nil {
            return .time
        } else if day != nil {
            return .day
        } else if month != nil {
            return .month
        } else {
            return .year
        }
    }

    /// Convert to a Foundation Date for positioning on the timeline.
    ///
    /// - Time precision: interprets stored components as UTC (they were converted on creation).
    /// - Day and coarser: interprets components in the local timezone so calendar dates
    ///   align with the local-time axis ticks.
    var asDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month ?? 1
        components.day = day ?? 1
        components.hour = hour ?? 0
        components.minute = minute ?? 0
        components.second = 0

        if precision == .time {
            components.timeZone = TimeZone(identifier: "UTC")
        }

        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components) ?? Date.distantPast
    }

    /// Local-time display components for time-precision dates.
    /// Converts stored UTC hour/minute back to the local timezone.
    /// For day and coarser precision, returns the stored values unchanged.
    var localDisplayComponents: (year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        if precision == .time {
            let date = asDate
            let cal = Calendar.current
            return (
                year: cal.component(.year, from: date),
                month: cal.component(.month, from: date),
                day: cal.component(.day, from: date),
                hour: cal.component(.hour, from: date),
                minute: cal.component(.minute, from: date)
            )
        }
        return (
            year: year,
            month: month ?? 1,
            day: day ?? 1,
            hour: hour ?? 0,
            minute: minute ?? 0
        )
    }
}

extension FlexibleDate: Comparable {
    static func < (lhs: FlexibleDate, rhs: FlexibleDate) -> Bool {
        lhs.asDate < rhs.asDate
    }
}
