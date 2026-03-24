//
//  TimelinerSaveCommand.swift
//  Timeliner
//

import AppKit
import Foundation

/// Handles the AppleScript `save` command for Timeliner documents.
///
/// The standard `aevtsave` command would normally route to NSDocument via Cocoa
/// Scripting, but SwiftUI's DocumentGroup hides the NSDocument from the scriptable
/// object hierarchy. This custom command bridges to the real NSDocument via the
/// DocumentRegistry so that `save document "MyTimeline"` works as expected.
@MainActor
@objc(TimelinerSaveCommand)
final class TimelinerSaveCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        // Resolve the target document from the direct parameter or the first open doc.
        let scriptableDoc: ScriptableDocument?

        if let specifier = directParameter as? NSScriptObjectSpecifier,
           let resolved = specifier.objectsByEvaluatingSpecifier {
            if let doc = resolved as? ScriptableDocument {
                scriptableDoc = doc
            } else if let docs = resolved as? [ScriptableDocument] {
                scriptableDoc = docs.first
            } else {
                scriptableDoc = nil
            }
        } else {
            // No direct parameter — save the first (frontmost) document.
            scriptableDoc = DocumentRegistry.shared.allEntries.first.map {
                ScriptableDocument(entry: $0)
            }
        }

        guard let doc = scriptableDoc else {
            scriptErrorNumber = errOSAScriptError
            scriptErrorString = "No document to save."
            return nil
        }

        guard let nsDoc = DocumentRegistry.shared.nsDocument(for: doc.registryID) else {
            scriptErrorNumber = errOSAScriptError
            scriptErrorString = "Could not locate the underlying NSDocument for '\(doc.name)'."
            return nil
        }

        // If a "save in" file URL was provided, perform a Save As to that location.
        if let fileArg = arguments?["File"] {
            let targetURL: URL?
            if let url = fileArg as? URL {
                targetURL = url
            } else if let path = fileArg as? String {
                targetURL = URL(fileURLWithPath: path)
            } else {
                targetURL = nil
            }

            if let url = targetURL {
                let handler = SaveAsCompletionHandler(registryID: doc.registryID, targetURL: url)
                nsDoc.save(to: url, ofType: nsDoc.fileType ?? "com.timeliner.document",
                           for: .saveAsOperation,
                           delegate: handler,
                           didSave: #selector(SaveAsCompletionHandler.document(_:didSave:contextInfo:)),
                           contextInfo: nil)
                return nil
            }
        }

        // Standard save (overwrites existing file, or triggers Save panel for untitled docs).
        nsDoc.save(withDelegate: nil, didSave: nil, contextInfo: nil)
        return nil
    }
}
