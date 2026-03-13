//
//  EraListView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct EraListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Era.sortOrder) private var eras: [Era]

    var body: some View {
        Section("Eras") {
            ForEach(eras, id: \.id) { era in
                VStack(alignment: .leading, spacing: 2) {
                    Text(era.name)
                    Text(dateRangeSummary(era))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .tag(SidebarSelection.era(era.id))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(era.name)
                .accessibilityValue(dateRangeSummary(era))
                .accessibilityHint("Select to edit era")
                .accessibilityAddTraits(.isButton)
            }
            .onDelete(perform: deleteEras)
            .onMove(perform: moveEras)
        }
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

#Preview {
    EraListView()
        .modelContainer(for: Era.self, inMemory: true)
}
