//
//  TimelineEvent.swift
//  Timeliner
//

import Foundation
import SwiftData

@Model
final class TimelineEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var eventDescription: String?

    // Stored as JSON-encoded data since FlexibleDate is a struct
    private var startDateData: Data
    private var endDateData: Data?

    var lane: Lane?
    var tags: [Tag] = []

    var createdAt: Date
    var modifiedAt: Date

    var startDate: FlexibleDate {
        get {
            (try? JSONDecoder().decode(FlexibleDate.self, from: startDateData))
                ?? FlexibleDate(year: 1970)
        }
        set {
            startDateData = (try? JSONEncoder().encode(newValue)) ?? Data()
            modifiedAt = Date()
        }
    }

    var endDate: FlexibleDate? {
        get {
            guard let data = endDateData else { return nil }
            return try? JSONDecoder().decode(FlexibleDate.self, from: data)
        }
        set {
            endDateData = newValue.flatMap { try? JSONEncoder().encode($0) }
            modifiedAt = Date()
        }
    }

    var isPointEvent: Bool {
        endDate == nil
    }

    init(
        title: String,
        eventDescription: String? = nil,
        startDate: FlexibleDate,
        endDate: FlexibleDate? = nil,
        lane: Lane? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.eventDescription = eventDescription
        self.startDateData = (try? JSONEncoder().encode(startDate)) ?? Data()
        self.endDateData = endDate.flatMap { try? JSONEncoder().encode($0) }
        self.lane = lane
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
