//
//  CreateDocumentCommand.swift
//  Timeliner
//

import AppKit
import Foundation
import SwiftData

/// Custom `make` command that handles creation of all Timeliner objects.
///
/// We bypass NSCreateCommand's default alloc/init flow entirely for lanes and
/// events because that flow creates scriptable wrappers with throwaway
/// ModelContexts and nil document references, causing `objectSpecifier` to
/// return nil (which becomes `missing value` in AppleScript).
///
/// Instead, we create the SwiftData model objects directly, insert them into
/// the target document's ModelContext, and return proper object specifiers.
@MainActor
@objc(TimelinerCreateCommand)
class TimelinerCreateCommand: NSCreateCommand {
    override func performDefaultImplementation() -> Any? {
        let className = createClassDescription.className

        switch className {
        case "document":
            return createDocument()
        case "lane":
            return createLane()
        case "timeline event":
            return createTimelineEvent()
        case "era":
            return createEra()
        default:
            return super.performDefaultImplementation()
        }
    }

    // MARK: - Lane Creation

    private func createLane() -> Any? {
        guard let doc = resolveTargetDocument() else {
            scriptErrorNumber = -1
            scriptErrorString = "Could not find target document for lane creation."
            return nil
        }

        let lane = Lane(name: "Untitled Lane", color: "#999999", sortOrder: 0)

        let properties = resolvedKeyDictionary
        if let name = properties["name"] as? String { lane.name = name }
        if let color = properties["color"] as? String { lane.color = color }
        if let sortOrder = properties["sortOrder"] as? Int { lane.sortOrder = sortOrder }

        doc.modelContext.insert(lane)

        let wrapper = ScriptableLane(lane: lane, context: doc.modelContext, document: doc)
        return wrapper.objectSpecifier
    }

    // MARK: - Event Creation

    private func createTimelineEvent() -> Any? {
        guard let doc = resolveTargetDocument() else {
            scriptErrorNumber = -1
            scriptErrorString = "Could not find target document for event creation."
            return nil
        }

        let event = TimelineEvent(
            title: "Untitled Event",
            startDate: FlexibleDate(year: Calendar.current.component(.year, from: Date()))
        )

        let properties = resolvedKeyDictionary
        if let title = properties["title"] as? String { event.title = title }
        if let desc = properties["eventDescription"] as? String {
            event.eventDescription = desc.isEmpty ? nil : desc
        }
        if let startStr = properties["startDateString"] as? String,
           let d = FlexibleDate(isoString: startStr) {
            event.startDate = d
        }
        if let endStr = properties["endDateString"] as? String, !endStr.isEmpty,
           let d = FlexibleDate(isoString: endStr) {
            event.endDate = d
        }
        if let laneWrapper = properties["scriptableLane"] as? ScriptableLane {
            event.lane = laneWrapper.lane
        }

        doc.modelContext.insert(event)

        let wrapper = ScriptableEvent(event: event, context: doc.modelContext, document: doc)
        return wrapper.objectSpecifier
    }

    // MARK: - Era Creation

    private func createEra() -> Any? {
        guard let doc = resolveTargetDocument() else {
            scriptErrorNumber = -1
            scriptErrorString = "Could not find target document for era creation."
            return nil
        }

        let era = Era(
            name: "Untitled Era",
            startDate: FlexibleDate(year: 2025),
            endDate: FlexibleDate(year: 2026)
        )

        let properties = resolvedKeyDictionary
        if let name = properties["name"] as? String { era.name = name }
        if let startStr = properties["startDateString"] as? String,
           let d = FlexibleDate(isoString: startStr) {
            era.startDate = d
        }
        if let endStr = properties["endDateString"] as? String,
           let d = FlexibleDate(isoString: endStr) {
            era.endDate = d
        }
        if let sortOrder = properties["sortOrder"] as? Int { era.sortOrder = sortOrder }

        doc.modelContext.insert(era)

        let wrapper = ScriptableEra(era: era, context: doc.modelContext, document: doc)
        return wrapper.objectSpecifier
    }

    // MARK: - Target Document Resolution

    /// Finds the target document for lane/event creation.
    /// Checks the receivers specifier first (`tell document 1 ... make ...`),
    /// then falls back to the first open document.
    private func resolveTargetDocument() -> ScriptableDocument? {
        if let spec = receiversSpecifier {
            let evaluated = spec.objectsByEvaluatingSpecifier
            if let doc = evaluated as? ScriptableDocument {
                return doc
            }
            if let docs = evaluated as? [ScriptableDocument], let doc = docs.first {
                return doc
            }
        }

        // Fallback: first open document
        if let entry = DocumentRegistry.shared.allEntries.first {
            return ScriptableDocument(entry: entry)
        }

        return nil
    }

    // MARK: - Document Creation

    private func createDocument() -> Any? {
        let registry = DocumentRegistry.shared
        let countBefore = registry.count

        do {
            try NSDocumentController.shared.openUntitledDocumentAndDisplay(true)
        } catch {
            scriptErrorNumber = -1
            scriptErrorString = "Failed to create new document: \(error.localizedDescription)"
            return nil
        }

        // Wait for the new document's ContentView to register its ModelContext.
        var attempts = 0
        while registry.count <= countBefore && attempts < 50 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            attempts += 1
        }

        guard let entry = registry.mostRecentEntry, registry.count > countBefore else {
            scriptErrorNumber = -2
            scriptErrorString = "Document was created but its data context did not register in time."
            return nil
        }

        let doc = ScriptableDocument(entry: entry)

        let properties = resolvedKeyDictionary
        if !properties.isEmpty {
            for (key, value) in properties {
                doc.setValue(value, forKey: key)
            }
        }

        return doc.objectSpecifier
    }
}
