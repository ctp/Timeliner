//
//  EventInspectorView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct EventInspectorView: View {
    let event: TimelineEvent?

    var body: some View {
        Group {
            if let event {
                EventDetailView(event: event)
                    .id(event.id)
            } else {
                ContentUnavailableView("No Selection", systemImage: "calendar", description: Text("Select an event to view details"))
            }
        }
    }
}

private struct EventDetailView: View {
    let event: TimelineEvent

    var body: some View {
        Form {
            Section("Title") {
                Text(event.title)
                    .textSelection(.enabled)
            }

            Section("Description") {
                if let description = event.eventDescription, !description.isEmpty {
                    Text(description)
                        .textSelection(.enabled)
                } else {
                    Text("No description")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Lane") {
                if let lane = event.lane {
                    HStack {
                        Circle()
                            .fill(Color(hex: lane.color) ?? .gray)
                            .frame(width: TimelineConstants.laneColorCircleSize, height: TimelineConstants.laneColorCircleSize)
                        Text(lane.name)
                    }
                } else {
                    Text("Unassigned")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Start Date") {
                Text(event.startDate.isoString)
                    .textSelection(.enabled)
            }

            Section("End Date") {
                if let endDate = event.endDate {
                    Text(endDate.isoString)
                        .textSelection(.enabled)
                } else {
                    Text("Point event")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy Summary", systemImage: "doc.on.doc")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
    }

    private func copyToClipboard() {
        var lines: [String] = []
        lines.append("Title: \(event.title)")
        lines.append("Lane: \(event.lane?.name ?? "Unassigned")")
        lines.append("Start: \(event.startDate.isoString)")
        if let endDate = event.endDate {
            lines.append("End: \(endDate.isoString)")
        } else {
            lines.append("Type: Point event")
        }
        if let description = event.eventDescription, !description.isEmpty {
            lines.append("Description: \(description)")
        }
        let text = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
