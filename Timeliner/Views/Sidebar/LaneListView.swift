//
//  LaneListView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct LaneListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Lane.sortOrder) private var lanes: [Lane]
    @Binding var editingLane: Lane?

    var body: some View {
        Section("Lanes") {
            ForEach(lanes, id: \.id) { lane in
                HStack {
                    Circle()
                        .fill(Color(hex: lane.color) ?? .gray)
                        .frame(width: TimelineConstants.laneColorCircleSize, height: TimelineConstants.laneColorCircleSize)
                        .accessibilityHidden(true)
                    Text(lane.name)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingLane = lane
                }
                .listRowBackground(
                    editingLane?.id == lane.id
                        ? Color.accentColor.opacity(0.15)
                        : nil
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(lane.name)
                .accessibilityHint("Double-tap to edit lane")
                .accessibilityAddTraits(.isButton)
            }
            .onDelete(perform: deleteLanes)
            .onMove(perform: moveLanes)
        }
    }

    private func deleteLanes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(lanes[index])
        }
    }

    private func moveLanes(from source: IndexSet, to destination: Int) {
        var reorderedLanes = lanes
        reorderedLanes.move(fromOffsets: source, toOffset: destination)

        for (index, lane) in reorderedLanes.enumerated() {
            lane.sortOrder = index
        }
    }
}

#Preview {
    LaneListView(editingLane: .constant(nil))
        .modelContainer(for: Lane.self, inMemory: true)
}
