//
//  EraListView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct EraListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Era.sortOrder) private var eras: [Era]
    @Binding var editingEra: Era?

    @State private var isAddingEra = false
    @State private var newEraName = ""

    var body: some View {
        Section("Eras") {
            ForEach(eras, id: \.id) { era in
                VStack(alignment: .leading, spacing: 2) {
                    Text(era.name)
                    Text(dateRangeSummary(era))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingEra = era
                }
            }
            .onDelete(perform: deleteEras)
            .onMove(perform: moveEras)

            if isAddingEra {
                HStack {
                    TextField("Era name", text: $newEraName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addEra()
                    }
                    .disabled(newEraName.isEmpty)

                    Button("Cancel") {
                        isAddingEra = false
                        newEraName = ""
                    }
                }
            } else {
                Button {
                    isAddingEra = true
                } label: {
                    Label("Add Era", systemImage: "plus")
                }
            }
        }
    }

    private func addEra() {
        let maxOrder = eras.map(\.sortOrder).max() ?? -1
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let era = Era(
            name: newEraName,
            startDate: FlexibleDate(year: year),
            endDate: FlexibleDate(year: year + 1),
            sortOrder: maxOrder + 1
        )
        modelContext.insert(era)
        newEraName = ""
        isAddingEra = false
        editingEra = era
    }

    private func deleteEras(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(eras[index])
        }
    }

    private func moveEras(from source: IndexSet, to destination: Int) {
        var reorderedEras = eras
        reorderedEras.move(fromOffsets: source, toOffset: destination)

        for (index, era) in reorderedEras.enumerated() {
            era.sortOrder = index
        }
    }

    private func dateRangeSummary(_ era: Era) -> String {
        "\(era.startDate.isoString) \u{2013} \(era.endDate.isoString)"
    }
}

struct EraEditorSheet: View {
    @State private var name: String
    @State private var startDate: FlexibleDate
    @State private var endDate: FlexibleDate
    @Environment(\.dismiss) private var dismiss
    let onDone: (String, FlexibleDate, FlexibleDate) -> Void

    init(era: Era, onDone: @escaping (String, FlexibleDate, FlexibleDate) -> Void) {
        _name = State(initialValue: era.name)
        _startDate = State(initialValue: era.startDate)
        _endDate = State(initialValue: era.endDate)
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Name", text: $name)

                FlexibleDateEditor(label: "Start Date", flexibleDate: $startDate)

                FlexibleDateEditor(label: "End Date", flexibleDate: $endDate)
            }
            .formStyle(.grouped)
            .frame(minWidth: 300, minHeight: 300)

            HStack {
                Spacer()
                Button("Done") {
                    onDone(name, startDate, endDate)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .padding()
    }
}

#Preview {
    EraListView(editingEra: .constant(nil))
        .modelContainer(for: Era.self, inMemory: true)
}
