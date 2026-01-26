//
//  Tag.swift
//  Timeliner
//

import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String?

    @Relationship(inverse: \TimelineEvent.tags)
    var events: [TimelineEvent] = []

    init(name: String, color: String? = nil) {
        self.id = UUID()
        self.name = name
        self.color = color
    }
}
