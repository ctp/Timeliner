//
//  TimelineEventTests.swift
//  TimelinerTests
//

import Foundation
import Testing
import SwiftData
@testable import Timeliner

struct TimelineEventTests {

    @Test func pointEventInitialization() {
        let startDate = FlexibleDate(year: 1969, month: 7, day: 20)
        let event = TimelineEvent(title: "Moon Landing", startDate: startDate)

        #expect(event.title == "Moon Landing")
        #expect(event.startDate.year == 1969)
        #expect(event.endDate == nil)
        #expect(event.isPointEvent == true)
    }

    @Test func spanEventInitialization() {
        let startDate = FlexibleDate(year: 1939, month: 9, day: 1)
        let endDate = FlexibleDate(year: 1945, month: 9, day: 2)
        let event = TimelineEvent(title: "World War II", startDate: startDate, endDate: endDate)

        #expect(event.isPointEvent == false)
        #expect(event.endDate?.year == 1945)
    }

    @Test func eventWithDescription() {
        let startDate = FlexibleDate(year: 2000)
        let event = TimelineEvent(
            title: "Y2K",
            eventDescription: "The millennium bug scare",
            startDate: startDate
        )

        #expect(event.eventDescription == "The millennium bug scare")
    }

    @Test func eventMetadataTimestamps() {
        let startDate = FlexibleDate(year: 2020)
        let event = TimelineEvent(title: "Test", startDate: startDate)

        #expect(event.createdAt <= Date())
        #expect(event.modifiedAt <= Date())
    }
}
