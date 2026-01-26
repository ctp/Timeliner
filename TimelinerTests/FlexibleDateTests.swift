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
}
