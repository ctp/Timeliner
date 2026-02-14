//
//  FlexibleDateTests.swift
//  TimelinerTests
//

import Foundation
import Testing
@testable import Timeliner

struct FlexibleDateTests {

    @Test func yearOnlyPrecision() {
        let date = FlexibleDate(year: 1776)
        #expect(date.year == 1776)
        #expect(date.month == nil)
        #expect(date.day == nil)
        #expect(date.hour == nil)
        #expect(date.minute == nil)
        #expect(date.precision == .year)
    }

    @Test func monthPrecision() {
        let date = FlexibleDate(year: 1776, month: 7)
        #expect(date.precision == .month)
    }

    @Test func dayPrecision() {
        let date = FlexibleDate(year: 1776, month: 7, day: 4)
        #expect(date.precision == .day)
    }

    @Test func timePrecision() {
        let date = FlexibleDate(year: 1776, month: 7, day: 4, hour: 14, minute: 30)
        #expect(date.precision == .time)
    }

    @Test func asDateYearOnly() {
        let flexDate = FlexibleDate(year: 2000)
        let date = flexDate.asDate
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == 2000)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    @Test func asDateFullPrecision() {
        let flexDate = FlexibleDate(year: 2000, month: 6, day: 15, hour: 10, minute: 30)
        let date = flexDate.asDate
        let calendar = Calendar(identifier: .gregorian)
        var expectedComponents = DateComponents()
        expectedComponents.year = 2000
        expectedComponents.month = 6
        expectedComponents.day = 15
        expectedComponents.hour = 10
        expectedComponents.minute = 30
        expectedComponents.timeZone = TimeZone(identifier: "UTC")
        let expectedDate = calendar.date(from: expectedComponents)!
        #expect(date == expectedDate)
    }

    @Test func comparableDifferentYears() {
        let earlier = FlexibleDate(year: 1900)
        let later = FlexibleDate(year: 2000)
        #expect(earlier < later)
    }

    @Test func comparableSameYearDifferentMonth() {
        let earlier = FlexibleDate(year: 2000, month: 3)
        let later = FlexibleDate(year: 2000, month: 7)
        #expect(earlier < later)
    }

    // MARK: - ISO String Parsing

    @Test func isoStringParseYear() {
        let date = FlexibleDate(isoString: "2026")
        #expect(date != nil)
        #expect(date?.year == 2026)
        #expect(date?.month == nil)
        #expect(date?.precision == .year)
    }

    @Test func isoStringParseMonth() {
        let date = FlexibleDate(isoString: "2026-02")
        #expect(date != nil)
        #expect(date?.year == 2026)
        #expect(date?.month == 2)
        #expect(date?.day == nil)
        #expect(date?.precision == .month)
    }

    @Test func isoStringParseDay() {
        let date = FlexibleDate(isoString: "2026-02-13")
        #expect(date != nil)
        #expect(date?.year == 2026)
        #expect(date?.month == 2)
        #expect(date?.day == 13)
        #expect(date?.hour == nil)
        #expect(date?.precision == .day)
    }

    @Test func isoStringParseTime() {
        let date = FlexibleDate(isoString: "2026-02-13T14:30")
        #expect(date != nil)
        #expect(date?.precision == .time)
        // Time-precision dates are stored as UTC internally.
        // localDisplayComponents should give us back the local input values.
        let local = date!.localDisplayComponents
        #expect(local.year == 2026)
        #expect(local.month == 2)
        #expect(local.day == 13)
        #expect(local.hour == 14)
        #expect(local.minute == 30)
    }

    @Test func isoStringParseMidnightTime() {
        let date = FlexibleDate(isoString: "2026-01-01T00:00")
        #expect(date != nil)
        #expect(date?.precision == .time)
        let local = date!.localDisplayComponents
        #expect(local.hour == 0)
        #expect(local.minute == 0)
    }

    @Test func isoStringParseInvalid() {
        #expect(FlexibleDate(isoString: "") == nil)
        #expect(FlexibleDate(isoString: "abc") == nil)
        #expect(FlexibleDate(isoString: "2026-13") == nil)    // month > 12
        #expect(FlexibleDate(isoString: "2026-00") == nil)    // month < 1
        #expect(FlexibleDate(isoString: "2026-02-32") == nil) // day > 31
        #expect(FlexibleDate(isoString: "2026-02-13T25:00") == nil) // hour > 23
        #expect(FlexibleDate(isoString: "2026-02-13T14:60") == nil) // minute > 59
        #expect(FlexibleDate(isoString: "2026-02-13T") == nil) // T with no time
    }

    @Test func isoStringParseTrimmed() {
        let date = FlexibleDate(isoString: "  2026-06  ")
        #expect(date != nil)
        #expect(date?.year == 2026)
        #expect(date?.month == 6)
    }

    // MARK: - ISO String Formatting

    @Test func isoStringFormatYear() {
        let date = FlexibleDate(year: 2026)
        #expect(date.isoString == "2026")
    }

    @Test func isoStringFormatMonth() {
        let date = FlexibleDate(year: 2026, month: 2)
        #expect(date.isoString == "2026-02")
    }

    @Test func isoStringFormatDay() {
        let date = FlexibleDate(year: 2026, month: 2, day: 13)
        #expect(date.isoString == "2026-02-13")
    }

    @Test func isoStringFormatTime() {
        // Create via fromLocalTime to ensure proper UTC conversion
        let date = FlexibleDate.fromLocalTime(year: 2026, month: 2, day: 13, hour: 14, minute: 30)
        // isoString should output in local time
        #expect(date.isoString == "2026-02-13T14:30")
    }

    // MARK: - ISO String Round-Trip

    @Test func isoStringRoundTripYear() {
        let original = FlexibleDate(year: 1776)
        let parsed = FlexibleDate(isoString: original.isoString)
        #expect(parsed == original)
    }

    @Test func isoStringRoundTripMonth() {
        let original = FlexibleDate(year: 1776, month: 7)
        let parsed = FlexibleDate(isoString: original.isoString)
        #expect(parsed == original)
    }

    @Test func isoStringRoundTripDay() {
        let original = FlexibleDate(year: 1776, month: 7, day: 4)
        let parsed = FlexibleDate(isoString: original.isoString)
        #expect(parsed == original)
    }

    @Test func isoStringRoundTripTime() {
        let original = FlexibleDate.fromLocalTime(year: 2026, month: 2, day: 13, hour: 14, minute: 30)
        let parsed = FlexibleDate(isoString: original.isoString)
        #expect(parsed != nil)
        // Round-trip should preserve the same date point
        #expect(parsed!.asDate == original.asDate)
    }
}
