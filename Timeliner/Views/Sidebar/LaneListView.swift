//
//  LaneListView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct LaneListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Lane.sortOrder) private var lanes: [Lane]

    @State private var isAddingLane = false
    @State private var newLaneName = ""
    @State private var newLaneColor = "#3498DB"

    var body: some View {
        Section("Lanes") {
            ForEach(lanes, id: \.id) { lane in
                HStack {
                    Circle()
                        .fill(Color(hex: lane.color) ?? .gray)
                        .frame(width: 12, height: 12)
                    Text(lane.name)
                }
            }
            .onDelete(perform: deleteLanes)
            .onMove(perform: moveLanes)

            if isAddingLane {
                HStack {
                    TextField("Lane name", text: $newLaneName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addLane()
                    }
                    .disabled(newLaneName.isEmpty)

                    Button("Cancel") {
                        isAddingLane = false
                        newLaneName = ""
                    }
                }
            } else {
                Button {
                    isAddingLane = true
                } label: {
                    Label("Add Lane", systemImage: "plus")
                }
            }
        }
    }

    private func addLane() {
        let maxOrder = lanes.map(\.sortOrder).max() ?? -1
        let lane = Lane(name: newLaneName, color: newLaneColor, sortOrder: maxOrder + 1)
        modelContext.insert(lane)
        newLaneName = ""
        isAddingLane = false
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
    List {
        LaneListView()
    }
    .modelContainer(for: Lane.self, inMemory: true)
}
