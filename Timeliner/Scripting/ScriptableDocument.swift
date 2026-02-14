//
//  ScriptableDocument.swift
//  Timeliner
//

import AppKit
import Foundation
import SwiftData

/// Scriptable wrapper for a Timeliner document.
///
/// Bridges between Cocoa Scripting's KVC-based object model and the SwiftData
/// ModelContext that lives inside SwiftUI's DocumentGroup.
@MainActor
@objc(ScriptableDocument)
class ScriptableDocument: NSObject {
    let registryID: UUID
    let modelContext: ModelContext
    private let _fileURL: URL?

    init(entry: DocumentRegistry.Entry) {
        self.registryID = entry.id
        self.modelContext = entry.modelContext
        self._fileURL = entry.fileURL
        super.init()
    }

    // MARK: - KVC Properties

    @objc var name: String {
        if let url = _fileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        // Find matching NSDocument for untitled name
        for doc in NSDocumentController.shared.documents {
            if let entry = DocumentRegistry.shared.entry(for: doc), entry.id == registryID {
                return doc.displayName
            }
        }
        return "Untitled"
    }

    @objc var isModified: Bool {
        modelContext.hasChanges
    }

    @objc var fileURL: URL? {
        _fileURL
    }

    // MARK: - Lane Elements

    @objc var lanes: [ScriptableLane] {
        let descriptor = FetchDescriptor<Lane>(sortBy: [SortDescriptor(\.sortOrder)])
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return models.map { ScriptableLane(lane: $0, context: modelContext, document: self) }
    }

    @objc func insertInLanes(_ wrapper: ScriptableLane) {
        modelContext.insert(wrapper.lane)
    }

    @objc func insertObject(_ wrapper: ScriptableLane, inLanesAt index: Int) {
        modelContext.insert(wrapper.lane)
    }

    @objc func removeObjectFromLanesAt(_ index: Int) {
        let descriptor = FetchDescriptor<Lane>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let models = try? modelContext.fetch(descriptor),
              index >= 0, index < models.count else { return }
        modelContext.delete(models[index])
    }

    @objc func removeFromLanes(_ wrapper: ScriptableLane) {
        modelContext.delete(wrapper.lane)
    }

    // MARK: - Event Elements

    @objc var events: [ScriptableEvent] {
        let descriptor = FetchDescriptor<TimelineEvent>()
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return models.map { ScriptableEvent(event: $0, context: modelContext, document: self) }
    }

    @objc func insertInEvents(_ wrapper: ScriptableEvent) {
        modelContext.insert(wrapper.event)
    }

    @objc func insertObject(_ wrapper: ScriptableEvent, inEventsAt index: Int) {
        modelContext.insert(wrapper.event)
    }

    @objc func removeObjectFromEventsAt(_ index: Int) {
        let descriptor = FetchDescriptor<TimelineEvent>()
        guard let models = try? modelContext.fetch(descriptor),
              index >= 0, index < models.count else { return }
        modelContext.delete(models[index])
    }

    @objc func removeFromEvents(_ wrapper: ScriptableEvent) {
        modelContext.delete(wrapper.event)
    }

    // MARK: - Era Elements

    @objc var eras: [ScriptableEra] {
        let descriptor = FetchDescriptor<Era>(sortBy: [SortDescriptor(\.sortOrder)])
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return models.map { ScriptableEra(era: $0, context: modelContext, document: self) }
    }

    @objc func insertInEras(_ wrapper: ScriptableEra) {
        modelContext.insert(wrapper.era)
    }

    @objc func insertObject(_ wrapper: ScriptableEra, inErasAt index: Int) {
        modelContext.insert(wrapper.era)
    }

    @objc func removeObjectFromErasAt(_ index: Int) {
        let descriptor = FetchDescriptor<Era>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let models = try? modelContext.fetch(descriptor),
              index >= 0, index < models.count else { return }
        modelContext.delete(models[index])
    }

    @objc func removeFromEras(_ wrapper: ScriptableEra) {
        modelContext.delete(wrapper.era)
    }

    // MARK: - Object Specifier

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appDescription = NSScriptClassDescription(for: NSApplication.self) else {
            return nil
        }

        // Use name-based specifier (matches how AppleScript resolves `document "name"`)
        return NSNameSpecifier(
            containerClassDescription: appDescription,
            containerSpecifier: nil,
            key: "scriptableDocuments",
            name: name
        )
    }
}

