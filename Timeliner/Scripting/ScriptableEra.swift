//
//  ScriptableEra.swift
//  Timeliner
//

import AppKit
import Foundation
import SwiftData

/// Scriptable wrapper for an Era model.
@MainActor
@objc(ScriptableEra)
class ScriptableEra: NSObject {
    let era: Era
    let modelContext: ModelContext
    weak var document: ScriptableDocument?

    init(era: Era, context: ModelContext, document: ScriptableDocument?) {
        self.era = era
        self.modelContext = context
        self.document = document
        super.init()
    }

    // MARK: - KVC Properties

    @objc var uniqueID: String {
        era.id.uuidString
    }

    @objc var name: String {
        get { era.name }
        set { era.name = newValue }
    }

    @objc var startDateString: String {
        get { era.startDate.isoString }
        set {
            if let date = FlexibleDate(isoString: newValue) {
                era.startDate = date
            }
        }
    }

    @objc var endDateString: String {
        get { era.endDate.isoString }
        set {
            if let date = FlexibleDate(isoString: newValue) {
                era.endDate = date
            }
        }
    }

    @objc var sortOrder: Int {
        get { era.sortOrder }
        set { era.sortOrder = newValue }
    }

    // MARK: - Object Specifier

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let doc = document else { return nil }
        guard let docSpecifier = doc.objectSpecifier else { return nil }
        guard let docClassDescription = NSScriptClassDescription(for: type(of: doc)) else { return nil }

        return NSNameSpecifier(
            containerClassDescription: docClassDescription,
            containerSpecifier: docSpecifier,
            key: "eras",
            name: era.name
        )
    }
}
