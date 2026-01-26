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

    var asDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month ?? 1
        components.day = day ?? 1
        components.hour = hour ?? 0
        components.minute = minute ?? 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components) ?? Date.distantPast
    }
}

extension FlexibleDate: Comparable {
    static func < (lhs: FlexibleDate, rhs: FlexibleDate) -> Bool {
        lhs.asDate < rhs.asDate
    }
}
