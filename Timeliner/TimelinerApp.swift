//
//  TimelinerApp.swift
//  Timeliner
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct TimelinerApp: App {
    var body: some Scene {
        DocumentGroup(editing: .timelinerDocument, migrationPlan: TimelinerMigrationPlan.self) {
            ContentView()
        }
    }
}

extension UTType {
    static var timelinerDocument: UTType {
        UTType(importedAs: "com.timeliner.document")
    }
}

struct TimelinerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] = [
        TimelinerVersionedSchema.self,
    ]

    static var stages: [MigrationStage] = []
}

struct TimelinerVersionedSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        TimelineEvent.self,
        Lane.self,
        Tag.self,
    ]
}
