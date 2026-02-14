//
//  ScriptableEvent.swift
//  Timeliner
//

import AppKit
import Foundation
import SwiftData

/// Scriptable wrapper for a TimelineEvent model.
@MainActor
@objc(ScriptableEvent)
class ScriptableEvent: NSObject {
    let event: TimelineEvent
    let modelContext: ModelContext
    weak var document: ScriptableDocument?

    init(event: TimelineEvent, context: ModelContext, document: ScriptableDocument?) {
        self.event = event
        self.modelContext = context
        self.document = document
        super.init()
    }

    /// Init for Cocoa Scripting `make new timeline event with properties {...}`.
    /// Creates a new TimelineEvent with defaults; properties are set via KVC after init.
    @objc override convenience init() {
        let event = TimelineEvent(
            title: "Untitled Event",
            startDate: FlexibleDate(year: Calendar.current.component(.year, from: Date()))
        )
        self.init(event: event, context: ModelContext(try! ModelContainer(for: Lane.self, TimelineEvent.self)), document: nil)
    }

    // MARK: - KVC Properties

    @objc var uniqueID: String {
        event.id.uuidString
    }

    @objc var title: String {
        get { event.title }
        set { event.title = newValue }
    }

    @objc var eventDescription: String {
        get { event.eventDescription ?? "" }
        set { event.eventDescription = newValue.isEmpty ? nil : newValue }
    }

    @objc var startDateString: String {
        get { event.startDate.isoString }
        set {
            if let date = FlexibleDate(isoString: newValue) {
                event.startDate = date
            }
        }
    }

    @objc var endDateString: String {
        get { event.endDate?.isoString ?? "" }
        set {
            if newValue.isEmpty {
                event.endDate = nil
            } else if let date = FlexibleDate(isoString: newValue) {
                event.endDate = date
            }
        }
    }

    @objc var isPointEvent: Bool {
        event.isPointEvent
    }

    /// The lane this event belongs to, as a scriptable wrapper.
    @objc var scriptableLane: ScriptableLane? {
        get {
            guard let lane = event.lane else { return nil }
            return ScriptableLane(lane: lane, context: modelContext, document: document)
        }
        set {
            event.lane = newValue?.lane
        }
    }

    // MARK: - Object Specifier

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let doc = document else { return nil }
        guard let docSpecifier = doc.objectSpecifier else { return nil }
        guard let docClassDescription = doc.classDescription as? NSScriptClassDescription else { return nil }

        // Use unique ID specifier since event titles may not be unique
        return NSUniqueIDSpecifier(
            containerClassDescription: docClassDescription,
            containerSpecifier: docSpecifier,
            key: "events",
            uniqueID: event.id.uuidString
        )
    }
}
