//
//  TagListView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct TagListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]

    @Binding var activeTagFilters: Set<UUID>

    @State private var isAddingTag = false
    @State private var newTagName = ""

    var body: some View {
        Section("Tags") {
            ForEach(tags, id: \.id) { tag in
                HStack {
                    Toggle(isOn: binding(for: tag.id)) {
                        HStack {
                            if let color = tag.color, let c = Color(hex: color) {
                                Circle()
                                    .fill(c)
                                    .frame(width: 10, height: 10)
                            }
                            Text(tag.name)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .onDelete(perform: deleteTags)

            if isAddingTag {
                HStack {
                    TextField("Tag name", text: $newTagName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addTag()
                    }
                    .disabled(newTagName.isEmpty)

                    Button("Cancel") {
                        isAddingTag = false
                        newTagName = ""
                    }
                }
            } else {
                Button {
                    isAddingTag = true
                } label: {
                    Label("Add Tag", systemImage: "plus")
                }
            }
        }
    }

    private func binding(for tagID: UUID) -> Binding<Bool> {
        Binding(
            get: { activeTagFilters.contains(tagID) },
            set: { isActive in
                if isActive {
                    activeTagFilters.insert(tagID)
                } else {
                    activeTagFilters.remove(tagID)
                }
            }
        )
    }

    private func addTag() {
        let tag = Tag(name: newTagName)
        modelContext.insert(tag)
        activeTagFilters.insert(tag.id)
        newTagName = ""
        isAddingTag = false
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            activeTagFilters.remove(tag.id)
            modelContext.delete(tag)
        }
    }
}

#Preview {
    @Previewable @State var filters: Set<UUID> = []
    List {
        TagListView(activeTagFilters: $filters)
    }
    .modelContainer(for: Tag.self, inMemory: true)
}
