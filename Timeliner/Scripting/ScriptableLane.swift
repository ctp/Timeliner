//
//  ScriptableLane.swift
//  Timeliner
//

import AppKit
import Foundation
import SwiftData

/// Scriptable wrapper for a Lane model.
@MainActor
@objc(ScriptableLane)
class ScriptableLane: NSObject {
    let lane: Lane
    let modelContext: ModelContext
    weak var document: ScriptableDocument?

    init(lane: Lane, context: ModelContext, document: ScriptableDocument?) {
        self.lane = lane
        self.modelContext = context
        self.document = document
        super.init()
    }

    /// Init for Cocoa Scripting `make new lane with properties {...}`.
    /// Creates a new Lane model with default values; properties are set via KVC after init.
    @objc override convenience init() {
        let lane = Lane(name: "Untitled Lane", color: "#999999", sortOrder: 0)
        // Temporarily use a placeholder context — will be set properly on insertion
        // The lane is not inserted into any context yet
        self.init(lane: lane, context: ModelContext(try! ModelContainer(for: Lane.self, TimelineEvent.self)), document: nil)
    }

    // MARK: - KVC Properties

    @objc var uniqueID: String {
        lane.id.uuidString
    }

    @objc var name: String {
        get { lane.name }
        set { lane.name = newValue }
    }

    @objc var color: String {
        get { lane.color }
        set { lane.color = newValue }
    }

    @objc var sortOrder: Int {
        get { lane.sortOrder }
        set { lane.sortOrder = newValue }
    }

    // MARK: - Event Elements

    @objc var events: [ScriptableEvent] {
        lane.events.map { ScriptableEvent(event: $0, context: modelContext, document: document) }
    }

    @objc func insertInEvents(_ wrapper: ScriptableEvent) {
        wrapper.event.lane = lane
        if wrapper.event.modelContext == nil {
            modelContext.insert(wrapper.event)
        }
    }

    @objc func insertObject(_ wrapper: ScriptableEvent, inEventsAt index: Int) {
        wrapper.event.lane = lane
        if wrapper.event.modelContext == nil {
            modelContext.insert(wrapper.event)
        }
    }

    @objc func removeObjectFromEventsAt(_ index: Int) {
        guard index >= 0, index < lane.events.count else { return }
        let event = lane.events[index]
        modelContext.delete(event)
    }

    // MARK: - Object Specifier

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let doc = document else { return nil }
        guard let docSpecifier = doc.objectSpecifier else { return nil }
        guard let docClassDescription = NSScriptClassDescription(for: type(of: doc)) else { return nil }

        return NSNameSpecifier(
            containerClassDescription: docClassDescription,
            containerSpecifier: docSpecifier,
            key: "lanes",
            name: lane.name
        )
    }
}
