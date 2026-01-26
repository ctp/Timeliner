//
//  ContentView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [TimelineEvent]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(events) { event in
                    NavigationLink {
                        Text("Event: \(event.title)")
                    } label: {
                        Text(event.title)
                    }
                }
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
        } detail: {
            Text("Select an event")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimelineEvent.self, inMemory: true)
}
