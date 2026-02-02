//
//  ContentView.swift
//  Timeliner
//

import SwiftUI
import SwiftData

struct FitToContentKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct ShowPointLabelsKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var fitToContent: Binding<Bool>? {
        get { self[FitToContentKey.self] }
        set { self[FitToContentKey.self] = newValue }
    }

    var showPointLabels: Binding<Bool>? {
        get { self[ShowPointLabelsKey.self] }
        set { self[ShowPointLabelsKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeTagFilters: Set<UUID> = []
    @State private var fitToContent = false
    @State private var showPointLabels = false

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
            TimelineCanvasView(fitToContent: $fitToContent, showPointLabels: $showPointLabels)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { fitToContent = true }) {
                    Label("Fit to Content", systemImage: "arrow.left.and.line.vertical.and.arrow.right")
                }
            }
        }
        .focusedSceneValue(\.fitToContent, $fitToContent)
        .focusedSceneValue(\.showPointLabels, $showPointLabels)
    }

    private func addSampleData() {
        // Check if sample data already exists
        let laneDescriptor = FetchDescriptor<Lane>()
        let existingLanes = (try? modelContext.fetch(laneDescriptor)) ?? []
        guard existingLanes.isEmpty else { return }

        // Create sample lanes
        let workLane = Lane(name: "Work", color: "#3498DB", sortOrder: 0)
        let personalLane = Lane(name: "Personal", color: "#E74C3C", sortOrder: 1)

        modelContext.insert(workLane)
        modelContext.insert(personalLane)

        // Create sample tags
        let importantTag = Tag(name: "Important", color: "#F39C12")
        let milestoneTag = Tag(name: "Milestone", color: "#9B59B6")
        modelContext.insert(importantTag)
        modelContext.insert(milestoneTag)

        // Helper to make FlexibleDate from a Date offset
        let today = Date()
        let calendar = Calendar.current

        func dayDate(_ offsetDays: Int) -> Date {
            calendar.date(byAdding: .day, value: offsetDays, to: today)!
        }

        func flexDay(_ date: Date) -> FlexibleDate {
            FlexibleDate(
                year: calendar.component(.year, from: date),
                month: calendar.component(.month, from: date),
                day: calendar.component(.day, from: date)
            )
        }

        // ── Work Lane Events ──

        let kickoff = TimelineEvent(
            title: "Project Kickoff",
            eventDescription: "Initial planning meeting with stakeholders",
            startDate: flexDay(today),
            lane: workLane
        )
        kickoff.tags = [importantTag]

        let sprint1 = TimelineEvent(
            title: "Sprint 1",
            eventDescription: "User authentication and onboarding flows",
            startDate: flexDay(today),
            endDate: flexDay(dayDate(14)),
            lane: workLane
        )

        let designReview = TimelineEvent(
            title: "Design Review",
            eventDescription: "Review mockups with design team",
            startDate: flexDay(dayDate(4)),
            lane: workLane
        )

        let sprint2 = TimelineEvent(
            title: "Sprint 2",
            eventDescription: "Dashboard and analytics features",
            startDate: flexDay(dayDate(7)),
            endDate: flexDay(dayDate(35)),
            lane: workLane
        )

        let clientDemo = TimelineEvent(
            title: "Client Demo",
            eventDescription: "Mid-project demo to client stakeholders",
            startDate: flexDay(dayDate(21)),
            lane: workLane
        )
        clientDemo.tags = [importantTag, milestoneTag]

        let sprint3 = TimelineEvent(
            title: "Sprint 3",
            eventDescription: "Notifications and integrations",
            startDate: flexDay(dayDate(28)),
            endDate: flexDay(dayDate(42)),
            lane: workLane
        )

        let codeFreeze = TimelineEvent(
            title: "Code Freeze",
            eventDescription: "Feature-complete cutoff",
            startDate: flexDay(dayDate(42)),
            lane: workLane
        )
        codeFreeze.tags = [milestoneTag]

        let qaPhase = TimelineEvent(
            title: "QA & Bug Fixes",
            eventDescription: "Testing and stabilization period",
            startDate: flexDay(dayDate(42)),
            endDate: flexDay(dayDate(52)),
            lane: workLane
        )

        let launchDay = TimelineEvent(
            title: "Launch Day",
            eventDescription: "Production release",
            startDate: flexDay(dayDate(56)),
            lane: workLane
        )
        launchDay.tags = [importantTag, milestoneTag]

        let teamRetro = TimelineEvent(
            title: "Team Retro",
            eventDescription: "Post-launch retrospective",
            startDate: flexDay(dayDate(60)),
            lane: workLane
        )

        // ── Personal Lane Events ──

        let birthday = TimelineEvent(
            title: "Birthday Party",
            eventDescription: "Surprise party at the park",
            startDate: flexDay(dayDate(3)),
            lane: personalLane
        )

        let vacation = TimelineEvent(
            title: "Beach Vacation",
            eventDescription: "Week off at the coast",
            startDate: flexDay(dayDate(10)),
            endDate: flexDay(dayDate(17)),
            lane: personalLane
        )

        let dentist = TimelineEvent(
            title: "Dentist Appointment",
            startDate: flexDay(dayDate(5)),
            lane: personalLane
        )

        let moveIn = TimelineEvent(
            title: "Move to New Apartment",
            eventDescription: "Packing, moving truck, unpacking",
            startDate: flexDay(dayDate(20)),
            endDate: flexDay(dayDate(23)),
            lane: personalLane
        )
        moveIn.tags = [importantTag]

        let concert = TimelineEvent(
            title: "Concert Night",
            eventDescription: "Live jazz at the downtown venue",
            startDate: flexDay(dayDate(25)),
            lane: personalLane
        )

        let bookClub = TimelineEvent(
            title: "Book Club Meeting",
            startDate: flexDay(dayDate(30)),
            lane: personalLane
        )

        let homReno = TimelineEvent(
            title: "Kitchen Renovation",
            eventDescription: "Cabinets and countertop replacement",
            startDate: flexDay(dayDate(32)),
            endDate: flexDay(dayDate(46)),
            lane: personalLane
        )

        let halfMarathon = TimelineEvent(
            title: "Half Marathon",
            eventDescription: "City half marathon race day",
            startDate: flexDay(dayDate(38)),
            lane: personalLane
        )
        halfMarathon.tags = [milestoneTag]

        let familyVisit = TimelineEvent(
            title: "Family Visit",
            eventDescription: "Parents in town for the week",
            startDate: flexDay(dayDate(48)),
            endDate: flexDay(dayDate(54)),
            lane: personalLane
        )

        let anniversary = TimelineEvent(
            title: "Anniversary Dinner",
            eventDescription: "Reservation at the Italian place",
            startDate: flexDay(dayDate(58)),
            lane: personalLane
        )
        anniversary.tags = [importantTag]

        let allEvents: [TimelineEvent] = [
            kickoff, sprint1, designReview, sprint2, clientDemo,
            sprint3, codeFreeze, qaPhase, launchDay, teamRetro,
            birthday, vacation, dentist, moveIn, concert,
            bookClub, homReno, halfMarathon, familyVisit, anniversary,
        ]
        for event in allEvents {
            modelContext.insert(event)
        }

        fitToContent = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TimelineEvent.self, Lane.self, Tag.self], inMemory: true)
}
