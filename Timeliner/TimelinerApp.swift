//
//  TimelinerApp.swift
//  Timeliner
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct TimelinerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: TimelinerAppDelegate

    var body: some Scene {
        DocumentGroup(editing: .timelinerDocument, migrationPlan: TimelinerMigrationPlan.self) {
            ContentView()
        }
        .commands {
            TimelineCommands()
        }
    }
}

class TimelinerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        removeShareMenu()
    }

    private func removeShareMenu() {
        guard let fileMenu = NSApp.mainMenu?.item(withTitle: "File")?.submenu else { return }

        // Remove the Share item and any separator immediately following it.
        var indexToRemove: Int? = nil
        for (i, item) in fileMenu.items.enumerated() {
            if item.submenu?.title == "Share" || item.title == "Share" {
                indexToRemove = i
                break
            }
        }
        guard let idx = indexToRemove else { return }
        fileMenu.removeItem(at: idx)

        // Remove the separator that was directly after the Share item (now at the same index).
        if idx < fileMenu.items.count, fileMenu.items[idx].isSeparatorItem {
            fileMenu.removeItem(at: idx)
        }
    }
}

struct TimelineCommands: Commands {
    @FocusedBinding(\.fitToContent) private var fitToContent
    @FocusedBinding(\.showPointLabels) private var showPointLabels
    @FocusedBinding(\.showInspector) private var showInspector
@FocusedBinding(\.exportPDF) private var exportPDF
    @FocusedBinding(\.exportPNG) private var exportPNG

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Menu("Export") {
                Button("Export as PDF\u{2026}") {
                    exportPDF = true
                }
                .disabled(exportPDF == nil)

                Button("Export as PNG\u{2026}") {
                    exportPNG = true
                }
                .disabled(exportPNG == nil)
            }
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
