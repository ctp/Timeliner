//
//  ContentView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeTagFilters: Set<UUID> = []

    var body: some View {
        NavigationSplitView {
            List {
                LaneListView()
                TagListView(activeTagFilters: $activeTagFilters)
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            #endif
            .toolbar {
                ToolbarItem {
                    Button(action: addSampleData) {
                        Label("Add Sample", systemImage: "wand.and.stars")
                    }
                }
            }
        } detail: {
            TimelineCanvasView()
        }
    }

    private func addSampleData() {
        // Create sample lanes
        let workLane = Lane(name: "Work", color: "#3498DB", sortOrder: 0)
        let personalLane = Lane(name: "Personal", color: "#E74C3C", sortOrder: 1)

        modelContext.insert(workLane)
        modelContext.insert(personalLane)

        // Create sample tags
        let importantTag = Tag(name: "Important", color: "#F39C12")
        modelContext.insert(importantTag)

        // Create sample events
        let today = Date()
        let calendar = Calendar.current

        let event1 = TimelineEvent(
            title: "Project Kickoff",
            eventDescription: "Initial planning meeting",
            startDate: FlexibleDate(
                year: calendar.component(.year, from: today),
                month: calendar.component(.month, from: today),
                day: calendar.component(.day, from: today)
            ),
            lane: workLane
        )
        event1.tags = [importantTag]

        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        let event2 = TimelineEvent(
            title: "Sprint 1",
            startDate: FlexibleDate(
                year: calendar.component(.year, from: today),
                month: calendar.component(.month, from: today),
                day: calendar.component(.day, from: today)
            ),
            endDate: FlexibleDate(
                year: calendar.component(.year, from: nextWeek),
                month: calendar.component(.month, from: nextWeek),
                day: calendar.component(.day, from: nextWeek)
            ),
            lane: workLane
        )

        let birthday = TimelineEvent(
            title: "Birthday Party",
            startDate: FlexibleDate(
                year: calendar.component(.year, from: today),
                month: calendar.component(.month, from: today),
                day: calendar.component(.day, from: today) + 3
            ),
            lane: personalLane
        )

        modelContext.insert(event1)
        modelContext.insert(event2)
        modelContext.insert(birthday)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TimelineEvent.self, Lane.self, Tag.self], inMemory: true)
}
