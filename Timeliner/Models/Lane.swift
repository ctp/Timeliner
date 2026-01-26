//
//  Lane.swift
//  Timeliner
//

import Foundation
import SwiftData

@Model
final class Lane {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String
    var sortOrder: Int

    @Relationship(inverse: \TimelineEvent.lane)
    var events: [TimelineEvent] = []

    init(name: String, color: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
    }
}
