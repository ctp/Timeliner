//
//  TimelinerApp.swift
//  Timeliner
//
//  Created by Chris Parker on 1/25/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct TimelinerApp: App {
    var body: some Scene {
        DocumentGroup(editing: .itemDocument, migrationPlan: TimelinerMigrationPlan.self) {
            ContentView()
        }
    }
}

extension UTType {
    static var itemDocument: UTType {
        UTType(importedAs: "com.example.item-document")
    }
}

struct TimelinerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [
        TimelinerVersionedSchema.self,
    ]

    static var stages: [MigrationStage] = [
        // Stages of migration between VersionedSchema, if required.
    ]
}

struct TimelinerVersionedSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        Item.self,
    ]
}
