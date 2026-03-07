//
//  EventInspectorView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct EventInspectorView: View {
    let event: TimelineEvent?
    var onDelete: () -> Void = {}

    var body: some View {
        Group {
            if let event {
                EventDetailForm(event: event, onDelete: onDelete)
                    .id(event.id)
            } else {
                ContentUnavailableView("No Selection", systemImage: "calendar", description: Text("Select an event to edit"))
            }
        }
    }
}

private struct EventDetailForm: View {
    @Bindable var event: TimelineEvent
    var onDelete: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Lane.sortOrder) private var lanes: [Lane]

    @State private var startDate: FlexibleDate
    @State private var hasEndDate: Bool
    @State private var endDate: FlexibleDate
    @State private var showDeleteConfirmation = false

    init(event: TimelineEvent, onDelete: @escaping () -> Void = {}) {
        self.event = event
        self.onDelete = onDelete
        _startDate = State(initialValue: event.startDate)
        _hasEndDate = State(initialValue: event.endDate != nil)
        _endDate = State(initialValue: event.endDate ?? FlexibleDate(year: event.startDate.year, month: event.startDate.month, day: event.startDate.day))
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $event.title)
            }

            Section("Description") {
                TextEditor(text: Binding(
                    get: { event.eventDescription ?? "" },
                    set: { event.eventDescription = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 60)
                .accessibilityLabel("Event description")
            }

            Section("Lane") {
                Picker("Lane", selection: $event.lane) {
                    Text("Unassigned").tag(nil as Lane?)
                    ForEach(lanes, id: \.id) { lane in
                        HStack {
                            Circle()
                                .fill(Color(hex: lane.color) ?? .gray)
                                .frame(width: TimelineConstants.laneColorCircleSize, height: TimelineConstants.laneColorCircleSize)
                            Text(lane.name)
                        }
                        .tag(lane as Lane?)
                    }
                }
            }

            FlexibleDateEditor(label: "Start Date", flexibleDate: $startDate)
                .onChange(of: startDate) { oldValue, newValue in
                    let shift = newValue.asDate.timeIntervalSince(oldValue.asDate)
                    event.startDate = newValue
                    if hasEndDate {
                        let newEnd = endDate.asDate.addingTimeInterval(shift)
                        endDate = clampEndDate(FlexibleDate(from: newEnd, precision: endDate.precision))
                        event.endDate = endDate
                    }
                }

            Section("End Date") {
                Toggle("Has end date", isOn: $hasEndDate)
                    .onChange(of: hasEndDate) { _, on in
                        if on {
                            endDate = clampEndDate(endDate)
                            event.endDate = endDate
                        } else {
                            event.endDate = nil
                        }
                    }
            }

            if hasEndDate {
                FlexibleDateEditor(label: "End Date", flexibleDate: $endDate)
                    .onChange(of: endDate) { _, newValue in
                        let clamped = clampEndDate(newValue)
                        if clamped != newValue {
                            endDate = clamped
                        }
                        event.endDate = endDate
                    }
            }

            Section {
                Button("Delete Event", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Delete \"\(event.title)\"?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(event)
                try? modelContext.save()
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This event will be permanently deleted.")
        }
    }

    private var minimumEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startDate.asDate) ?? startDate.asDate
    }

    private func clampEndDate(_ candidate: FlexibleDate) -> FlexibleDate {
        if candidate.asDate < minimumEndDate {
            return FlexibleDate(from: minimumEndDate, precision: candidate.precision)
        }
        return candidate
    }
}
