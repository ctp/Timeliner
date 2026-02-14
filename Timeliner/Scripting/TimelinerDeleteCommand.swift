//
//  TimelinerDeleteCommand.swift
//  Timeliner
//

import AppKit
import Foundation
import SwiftData

/// Custom delete command that resolves scriptable wrapper objects back to
/// their SwiftData models and deletes them from the ModelContext.
@MainActor
@objc(TimelinerDeleteCommand)
class TimelinerDeleteCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // Evaluate the direct parameter specifier to get the objects to delete
        guard let specifier = directParameter as? NSScriptObjectSpecifier else {
            scriptErrorNumber = -1
            scriptErrorString = "No object specified for deletion."
            return nil
        }

        let objects = specifier.objectsByEvaluatingSpecifier

        if let array = objects as? [Any] {
            for obj in array {
                deleteObject(obj)
            }
        } else if let obj = objects {
            deleteObject(obj)
        }

        return nil
    }

    private func deleteObject(_ obj: Any) {
        if let event = obj as? ScriptableEvent {
            event.modelContext.delete(event.event)
        } else if let lane = obj as? ScriptableLane {
            lane.modelContext.delete(lane.lane)
        }
    }
}
