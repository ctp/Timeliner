//
//  EventInspectorView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct InspectorView: View {
    let event: TimelineEvent?
    @Binding var editingLane: Lane?
    @Binding var editingEra: Era?

    var body: some View {
        Group {
            if let lane = editingLane {
                LaneInspectorView(lane: lane)
                    .id(lane.id)
            } else if let era = editingEra {
                EraInspectorView(era: era)
                    .id(era.id)
            } else if let event {
                EventDetailView(event: event)
                    .id(event.id)
            } else {
                ContentUnavailableView("No Selection", systemImage: "calendar", description: Text("Select an event, lane, or era to view details"))
            }
        }
    }
}

// MARK: - Event Detail (read-only)

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

// MARK: - Lane Inspector (editable)

private struct LaneInspectorView: View {
    @Bindable var lane: Lane
    @State private var pickerColor: Color

    init(lane: Lane) {
        self.lane = lane
        _pickerColor = State(initialValue: Color(hex: lane.color) ?? .blue)
    }

    var body: some View {
        Form {
            Section("Lane") {
                TextField("Name", text: $lane.name)

                ColorPicker("Color", selection: $pickerColor, supportsOpacity: false)
                    .onChange(of: pickerColor) { _, newColor in
                        lane.color = newColor.toHex()
                    }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Era Inspector (editable)

private struct EraInspectorView: View {
    @Bindable var era: Era
    @State private var startDate: FlexibleDate
    @State private var endDate: FlexibleDate

    init(era: Era) {
        self.era = era
        _startDate = State(initialValue: era.startDate)
        _endDate = State(initialValue: era.endDate)
    }

    var body: some View {
        Form {
            Section("Era") {
                TextField("Name", text: $era.name)
            }

            FlexibleDateEditor(label: "Start Date", flexibleDate: $startDate)
                .onChange(of: startDate) { _, newValue in
                    era.startDate = newValue
                }

            FlexibleDateEditor(label: "End Date", flexibleDate: $endDate)
                .onChange(of: endDate) { _, newValue in
                    era.endDate = newValue
                }
        }
        .formStyle(.grouped)
    }
}
