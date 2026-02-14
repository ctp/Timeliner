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

    @State private var isAddingLane = false
    @State private var newLaneName = ""
    @State private var newLanePickerColor: Color = Color(hex: "#3498DB") ?? .blue

    var body: some View {
        Section("Lanes") {
            ForEach(lanes, id: \.id) { lane in
                HStack {
                    Circle()
                        .fill(Color(hex: lane.color) ?? .gray)
                        .frame(width: 12, height: 12)
                    Text(lane.name)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingLane = lane
                }
            }
            .onDelete(perform: deleteLanes)
            .onMove(perform: moveLanes)

            if isAddingLane {
                HStack {
                    ColorPicker("", selection: $newLanePickerColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 24)

                    TextField("Lane name", text: $newLaneName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addLane()
                    }
                    .disabled(newLaneName.isEmpty)

                    Button("Cancel") {
                        isAddingLane = false
                        newLaneName = ""
                        newLanePickerColor = Color(hex: "#3498DB") ?? .blue
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
        let lane = Lane(name: newLaneName, color: newLanePickerColor.toHex(), sortOrder: maxOrder + 1)
        modelContext.insert(lane)
        newLaneName = ""
        newLanePickerColor = Color(hex: "#3498DB") ?? .blue
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

struct LaneEditorSheet: View {
    @State private var name: String
    @State private var color: Color
    @Environment(\.dismiss) private var dismiss
    let onDone: (String, String) -> Void

    init(lane: Lane, onDone: @escaping (String, String) -> Void) {
        _name = State(initialValue: lane.name)
        _color = State(initialValue: Color(hex: lane.color) ?? .blue)
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Name", text: $name)

                ColorPicker("Color", selection: $color, supportsOpacity: false)
            }
            .formStyle(.grouped)
            .frame(minWidth: 280, minHeight: 120)

            HStack {
                Spacer()
                Button("Done") {
                    onDone(name, color.toHex())
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
    LaneListView(editingLane: .constant(nil))
        .modelContainer(for: Lane.self, inMemory: true)
}
