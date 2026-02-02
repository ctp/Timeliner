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
        .commands {
            TimelineCommands()
        }
    }
}

struct TimelineCommands: Commands {
    @FocusedBinding(\.fitToContent) private var fitToContent
    @FocusedBinding(\.showPointLabels) private var showPointLabels

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Fit to Content") {
                fitToContent = true
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(fitToContent == nil)

            Toggle("Show Point Labels", isOn: Binding(
                get: { showPointLabels ?? false },
                set: { showPointLabels = $0 }
            ))
            .keyboardShortcut("l", modifiers: .command)
            .disabled(showPointLabels == nil)
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
