//
//  SaveAsCompletionHandler.swift
//  Timeliner
//

import AppKit
import Foundation

/// Trampoline object that receives the `didSave` callback from NSDocument after a
/// Save As operation and keeps NSDocument.fileURL and DocumentRegistry in sync.
///
/// NSDocument's `save(to:ofType:for:delegate:didSave:contextInfo:)` calls the
/// delegate selector once the write completes. We use a dedicated object rather
/// than ScriptableDocument or TimelinerSaveCommand so we can hold a strong
/// reference that outlives the command, and stay @MainActor throughout.
@MainActor
final class SaveAsCompletionHandler: NSObject {
    private let registryID: UUID
    private let targetURL: URL

    init(registryID: UUID, targetURL: URL) {
        self.registryID = registryID
        self.targetURL = targetURL
    }

    /// Called by NSDocument after the save completes (or fails).
    @objc func document(_ doc: NSDocument, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        guard didSave else { return }

        // NSDocument may not have updated fileURL yet for package-type documents;
        // set it explicitly so subsequent scripting lookups work.
        if doc.fileURL?.standardizedFileURL != targetURL.standardizedFileURL {
            doc.fileURL = targetURL
        }

        // Keep the registry entry's URL in sync so nsDocument(for:) keeps finding it.
        DocumentRegistry.shared.updateFileURL(targetURL, for: registryID)
    }
}
