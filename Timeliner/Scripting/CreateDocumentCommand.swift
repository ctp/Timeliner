//
//  CreateDocumentCommand.swift
//  Timeliner
//

import AppKit
import Foundation
import SwiftData

/// Custom `make` command that intercepts document creation while delegating
/// lane/event creation to the standard NSCreateCommand machinery.
///
/// Documents require special handling because SwiftUI's DocumentGroup manages
/// document lifecycle — we must create documents via NSDocumentController
/// rather than simple alloc/init.
@MainActor
@objc(TimelinerCreateCommand)
class TimelinerCreateCommand: NSCreateCommand {
    override func performDefaultImplementation() -> Any? {
        let className = createClassDescription.className

        if className == "document" {
            return createDocument()
        }

        // For lanes and events, NSCreateCommand calls alloc/init (with a throwaway
        // ModelContext), sets properties via KVC, then inserts into the container.
        // The object that comes back has a stale document reference, so we look up
        // the real wrapper from the document after insertion.
        let result = super.performDefaultImplementation()

        // Try to return a proper object specifier for the newly created object
        if let lane = result as? ScriptableLane {
            return resolveInsertedLane(lane)
        }
        if let event = result as? ScriptableEvent {
            return resolveInsertedEvent(event)
        }

        return result
    }

    /// After NSCreateCommand inserts a ScriptableLane, look up the real wrapper
    /// from the document so its objectSpecifier has the correct parent.
    private func resolveInsertedLane(_ placeholder: ScriptableLane) -> Any? {
        // Find the document container from the receivers specifier
        guard let containerSpecifier = receiversSpecifier,
              let containers = containerSpecifier.objectsByEvaluatingSpecifier as? [ScriptableDocument],
              let doc = containers.first else {
            return placeholder.objectSpecifier
        }

        // Find the lane we just created by matching name (properties were already set)
        let name = placeholder.lane.name
        if let real = doc.lanes.first(where: { $0.name == name }) {
            return real.objectSpecifier
        }
        return placeholder.objectSpecifier
    }

    /// After NSCreateCommand inserts a ScriptableEvent, look up the real wrapper.
    private func resolveInsertedEvent(_ placeholder: ScriptableEvent) -> Any? {
        guard let containerSpecifier = receiversSpecifier,
              let containers = containerSpecifier.objectsByEvaluatingSpecifier as? [ScriptableDocument],
              let doc = containers.first else {
            return placeholder.objectSpecifier
        }

        let id = placeholder.event.id.uuidString
        if let real = doc.events.first(where: { $0.uniqueID == id }) {
            return real.objectSpecifier
        }
        return placeholder.objectSpecifier
    }

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
