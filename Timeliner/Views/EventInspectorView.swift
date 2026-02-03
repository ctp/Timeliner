//
//  EventInspectorView.swift
//  Timeliner
//

import SwiftUI

struct EventInspectorView: View {
    let event: TimelineEvent?

    var body: some View {
        Group {
            if let event {
                EventDetailForm(event: event)
            } else {
                ContentUnavailableView("No Selection", systemImage: "calendar", description: Text("Select an event to edit"))
            }
        }
    }
}

private struct EventDetailForm: View {
    @Bindable var event: TimelineEvent

    @State private var startDate: FlexibleDate
    @State private var hasEndDate: Bool
    @State private var endDate: FlexibleDate

    init(event: TimelineEvent) {
        self.event = event
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
            }

            FlexibleDateEditor(label: "Start Date", flexibleDate: $startDate)
                .onChange(of: startDate) { _, newValue in
                    event.startDate = newValue
                }

            Section("End Date") {
                Toggle("Has end date", isOn: $hasEndDate)
                    .onChange(of: hasEndDate) { _, on in
                        if on {
                            event.endDate = endDate
                        } else {
                            event.endDate = nil
                        }
                    }
            }

            if hasEndDate {
                FlexibleDateEditor(label: "End Date", flexibleDate: $endDate)
                    .onChange(of: endDate) { _, newValue in
                        event.endDate = newValue
                    }
            }
        }
        .formStyle(.grouped)
    }
}
