//
//  DocumentRegistry.swift
//  Timeliner
//

import AppKit
import Foundation
import SwiftData

/// Central registry mapping open documents to their SwiftData ModelContexts.
///
/// SwiftUI's DocumentGroup hides NSDocument from the view layer. This singleton
/// bridges that gap by letting ContentView register its ModelContext on appear,
/// making it accessible to the Cocoa Scripting infrastructure.
@MainActor
final class DocumentRegistry {
    static let shared = DocumentRegistry()

    /// Posted when a new document is registered. The notification object is the entry's id.
    static let documentRegisteredNotification = Notification.Name("DocumentRegistryDidRegister")

    struct Entry {
        let id: UUID
        let modelContext: ModelContext
        /// File URL of the .timeliner package, nil for untitled documents.
        var fileURL: URL?
    }

    /// Ordered list of entries preserving insertion order.
    private var orderedEntries: [Entry] = []

    private init() {}

    /// Register a document's ModelContext. Returns the registration ID.
    @discardableResult
    func register(context: ModelContext, fileURL: URL?) -> UUID {
        // Check if this context is already registered (by identity)
        if let index = orderedEntries.firstIndex(where: { $0.modelContext === context }) {
            let existing = orderedEntries[index]
            orderedEntries[index] = Entry(id: existing.id, modelContext: context, fileURL: fileURL)
            return existing.id
        }

        let id = UUID()
        let entry = Entry(id: id, modelContext: context, fileURL: fileURL)
        orderedEntries.append(entry)

        NotificationCenter.default.post(
            name: Self.documentRegisteredNotification,
            object: id
        )

        return id
    }

    /// Unregister by registration ID.
    func unregister(id: UUID) {
        orderedEntries.removeAll { $0.id == id }
    }

    /// Unregister by ModelContext identity.
    func unregister(context: ModelContext) {
        orderedEntries.removeAll { $0.modelContext === context }
    }

    /// Look up an entry by its file URL.
    func entry(for fileURL: URL) -> Entry? {
        orderedEntries.first { entry in
            guard let url = entry.fileURL else { return false }
            return url.standardizedFileURL == fileURL.standardizedFileURL
        }
    }

    /// Look up an entry matching an NSDocument by comparing file URLs.
    func entry(for document: NSDocument) -> Entry? {
        guard let docURL = document.fileURL else {
            // Untitled document — match the first entry without a file URL
            let untitledEntries = orderedEntries.filter { $0.fileURL == nil }
            if untitledEntries.count == 1 { return untitledEntries.first }
            return nil
        }
        return entry(for: docURL)
    }

    /// All registered entries, ordered to match NSApp.orderedDocuments when possible.
    var allEntries: [Entry] {
        let nsDocuments = NSDocumentController.shared.documents
        var ordered: [Entry] = []
        var matched = Set<UUID>()

        for doc in nsDocuments {
            if let entry = entry(for: doc) {
                ordered.append(entry)
                matched.insert(entry.id)
            }
        }

        // Append any entries not matched to an NSDocument
        for entry in orderedEntries where !matched.contains(entry.id) {
            ordered.append(entry)
        }

        return ordered
    }

    /// The most recently registered entry. Useful after `make new document`.
    var mostRecentEntry: Entry? {
        orderedEntries.last
    }

    /// Number of registered documents.
    var count: Int { orderedEntries.count }
}
