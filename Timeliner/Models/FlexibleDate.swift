//
//  FlexibleDate.swift
//  Timeliner
//

import Foundation

enum DatePrecision: Int, Codable, Comparable, CaseIterable {
    case year = 0
    case month = 1
    case day = 2
    case time = 3

    var label: String {
        switch self {
        case .year: "Year"
        case .month: "Month"
        case .day: "Day"
        case .time: "Time"
        }
    }

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

    /// Create a FlexibleDate from a Foundation Date at the given precision.
    ///
    /// Time precision stores UTC components; day and coarser store local calendar values.
    init(from date: Date, precision: DatePrecision) {
        if precision >= .time {
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(identifier: "UTC")!
            self.year = utcCal.component(.year, from: date)
            self.month = utcCal.component(.month, from: date)
            self.day = utcCal.component(.day, from: date)
            self.hour = utcCal.component(.hour, from: date)
            self.minute = utcCal.component(.minute, from: date)
        } else {
            let cal = Calendar.current
            self.year = cal.component(.year, from: date)
            self.month = precision >= .month ? cal.component(.month, from: date) : nil
            self.day = precision >= .day ? cal.component(.day, from: date) : nil
            self.hour = nil
            self.minute = nil
        }
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

// MARK: - ISO String Conversion

extension FlexibleDate {
    /// Create a FlexibleDate from an ISO-ish string with precision inferred from the format.
    ///
    /// Supported formats:
    /// - `"2026"` → year precision
    /// - `"2026-02"` → month precision
    /// - `"2026-02-13"` → day precision
    /// - `"2026-02-13T14:30"` → time precision (interpreted as local time)
    init?(isoString: String) {
        let s = isoString.trimmingCharacters(in: .whitespaces)

        // Time precision: YYYY-MM-DDThh:mm
        if let tIndex = s.firstIndex(of: "T") {
            let datePart = s[s.startIndex..<tIndex]
            let timePart = s[s.index(after: tIndex)...]
            let dateComponents = datePart.split(separator: "-")
            let timeComponents = timePart.split(separator: ":")
            guard dateComponents.count == 3, timeComponents.count == 2,
                  let y = Int(dateComponents[0]),
                  let mo = Int(dateComponents[1]), (1...12).contains(mo),
                  let d = Int(dateComponents[2]), (1...31).contains(d),
                  let h = Int(timeComponents[0]), (0...23).contains(h),
                  let mi = Int(timeComponents[1]), (0...59).contains(mi) else {
                return nil
            }
            // Time strings are local time — use fromLocalTime to convert to UTC storage
            self = FlexibleDate.fromLocalTime(year: y, month: mo, day: d, hour: h, minute: mi)
            return
        }

        let parts = s.split(separator: "-")
        switch parts.count {
        case 1:
            guard let y = Int(parts[0]) else { return nil }
            self.init(year: y)
        case 2:
            guard let y = Int(parts[0]),
                  let mo = Int(parts[1]), (1...12).contains(mo) else { return nil }
            self.init(year: y, month: mo)
        case 3:
            guard let y = Int(parts[0]),
                  let mo = Int(parts[1]), (1...12).contains(mo),
                  let d = Int(parts[2]), (1...31).contains(d) else { return nil }
            self.init(year: y, month: mo, day: d)
        default:
            return nil
        }
    }

    /// Format as an ISO-ish string matching this date's precision.
    ///
    /// - Year: `"2026"`
    /// - Month: `"2026-02"`
    /// - Day: `"2026-02-13"`
    /// - Time: `"2026-02-13T14:30"` (local time)
    var isoString: String {
        switch precision {
        case .year:
            return String(format: "%04d", year)
        case .month:
            return String(format: "%04d-%02d", year, month ?? 1)
        case .day:
            return String(format: "%04d-%02d-%02d", year, month ?? 1, day ?? 1)
        case .time:
            let local = localDisplayComponents
            return String(format: "%04d-%02d-%02dT%02d:%02d",
                          local.year, local.month, local.day, local.hour, local.minute)
        }
    }
}
