//
//  NSApplication+Scripting.swift
//  Timeliner
//

import AppKit

/// KVC entry point for Cocoa Scripting.
///
/// The SDEF maps `application`'s `document` element to the key `scriptableDocuments`.
/// This extension provides that key on NSApplication, returning ScriptableDocument
/// wrappers from the DocumentRegistry.
extension NSApplication {

    /// Returns scriptable document wrappers for all registered open documents.
    /// Called by Cocoa Scripting when AppleScript accesses `documents of application`.
    @MainActor @objc var scriptableDocuments: [ScriptableDocument] {
        DocumentRegistry.shared.allEntries.map { entry in
            ScriptableDocument(entry: entry)
        }
    }

    /// Called by Cocoa Scripting for `make new document`.
    @MainActor @objc func insertInScriptableDocuments(_ document: ScriptableDocument) {
        // Document creation is handled by CreateDocumentCommand.
        // This is a no-op because the document is already created and registered
        // by the time Cocoa Scripting calls this.
    }
}
