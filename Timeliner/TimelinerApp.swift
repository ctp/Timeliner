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
    @FocusedBinding(\.showInspector) private var showInspector
    @FocusedBinding(\.createPointEvent) private var createPointEvent
    @FocusedBinding(\.createSpanEvent) private var createSpanEvent

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
            Button("New Point Event") {
                createPointEvent = true
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(createPointEvent == nil)

            Button("New Span Event") {
                createSpanEvent = true
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(createSpanEvent == nil)
        }

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

            Toggle("Show Inspector", isOn: Binding(
                get: { showInspector ?? false },
                set: { showInspector = $0 }
            ))
            .keyboardShortcut("i", modifiers: .command)
            .disabled(showInspector == nil)
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
        TimelinerVersionedSchemaV1.self,
        TimelinerVersionedSchema.self,
    ]

    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: TimelinerVersionedSchemaV1.self,
                     toVersion: TimelinerVersionedSchema.self),
    ]
}

struct TimelinerVersionedSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        TimelineEvent.self,
        Lane.self,
    ]
}

struct TimelinerVersionedSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] = [
        TimelineEvent.self,
        Lane.self,
        Era.self,
    ]
}
