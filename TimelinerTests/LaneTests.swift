//
//  LaneTests.swift
//  TimelinerTests
//

import Testing
import SwiftData
@testable import Timeliner

struct LaneTests {

    @Test func laneInitialization() {
        let lane = Lane(name: "Career", color: "#3498DB")
        #expect(lane.name == "Career")
        #expect(lane.color == "#3498DB")
        #expect(lane.sortOrder == 0)
        #expect(lane.events.isEmpty)
    }

    @Test func laneWithSortOrder() {
        let lane = Lane(name: "Personal", color: "#E74C3C", sortOrder: 5)
        #expect(lane.sortOrder == 5)
    }
}
