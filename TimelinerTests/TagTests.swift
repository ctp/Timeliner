//
//  TagTests.swift
//  TimelinerTests
//

import Foundation
import Testing
import SwiftData
@testable import Timeliner

struct TagTests {

    @Test func tagInitialization() {
        let tag = Tag(name: "Work")
        #expect(tag.name == "Work")
        #expect(tag.color == nil)
        #expect(tag.id != UUID())
    }

    @Test func tagWithColor() {
        let tag = Tag(name: "Personal", color: "#FF5733")
        #expect(tag.name == "Personal")
        #expect(tag.color == "#FF5733")
    }
}
