//
//  Era.swift
//  Timeliner
//

import Foundation
import SwiftData

@Model
final class Era {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int

    private var startDateData: Data
    private var endDateData: Data

    var startDate: FlexibleDate {
        get {
            (try? JSONDecoder().decode(FlexibleDate.self, from: startDateData))
                ?? FlexibleDate(year: 1970)
        }
        set {
            startDateData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var endDate: FlexibleDate {
        get {
            (try? JSONDecoder().decode(FlexibleDate.self, from: endDateData))
                ?? FlexibleDate(year: 1971)
        }
        set {
            endDateData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(name: String, startDate: FlexibleDate, endDate: FlexibleDate, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.startDateData = (try? JSONEncoder().encode(startDate)) ?? Data()
        self.endDateData = (try? JSONEncoder().encode(endDate)) ?? Data()
        self.sortOrder = sortOrder
    }
}
