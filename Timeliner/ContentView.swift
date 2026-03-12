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

struct ShowInspectorKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct ExportPDFKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct ExportPNGKey: FocusedValueKey {
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

    var showInspector: Binding<Bool>? {
        get { self[ShowInspectorKey.self] }
        set { self[ShowInspectorKey.self] = newValue }
    }

    var exportPDF: Binding<Bool>? {
        get { self[ExportPDFKey.self] }
        set { self[ExportPDFKey.self] = newValue }
    }

    var exportPNG: Binding<Bool>? {
        get { self[ExportPNGKey.self] }
        set { self[ExportPNGKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Lane.sortOrder) private var lanes: [Lane]
    @Query private var allEvents: [TimelineEvent]
    @Query(sort: \Era.sortOrder) private var eras: [Era]

    @State private var fitToContent = false
    @State private var showPointLabels = false
    @State private var showInspector = false
    @State private var exportPDF = false
    @State private var exportPNG = false
    @State private var canvasWidth: CGFloat = 800
    @State private var viewport = TimelineViewport(centerDate: Date(), scale: 86400 * 30, viewportWidth: 800)
    @State private var registryID: UUID?
    @State private var editingLane: Lane?
    @State private var editingEra: Era?

    var body: some View {
        NavigationSplitView {
            List {
                LaneListView(editingLane: $editingLane)
                EraListView(editingEra: $editingEra)
            }
            .sheet(item: $editingLane) { lane in
                LaneEditorSheet(lane: lane, onDone: { name, color in
                    lane.name = name
                    lane.color = color
                })
            }
            .sheet(item: $editingEra) { era in
                EraEditorSheet(era: era, onDone: { name, startDate, endDate in
                    era.name = name
                    era.startDate = startDate
                    era.endDate = endDate
                })
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
            TimelineCanvasView(fitToContent: $fitToContent, showPointLabels: $showPointLabels, showInspector: $showInspector, canvasWidth: $canvasWidth, viewport: $viewport)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showInspector.toggle() }) {
                    Label("Inspector", systemImage: showInspector ? "info.circle.fill" : "info.circle")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showPointLabels.toggle() }) {
                    Label("Show Point Labels", systemImage: showPointLabels ? "tag.fill" : "tag")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { fitToContent = true }) {
                    Label("Fit to Content", systemImage: "arrow.left.and.line.vertical.and.arrow.right")
                }
            }
        }
        .focusedSceneValue(\.fitToContent, $fitToContent)
        .focusedSceneValue(\.showPointLabels, $showPointLabels)
        .focusedSceneValue(\.showInspector, $showInspector)
        .focusedSceneValue(\.exportPDF, $exportPDF)
        .focusedSceneValue(\.exportPNG, $exportPNG)
        .onChange(of: exportPDF) { _, triggered in
            guard triggered else { return }
            exportPDF = false
            let documentTitle = NSDocumentController.shared.documents.first {
                $0.undoManager === undoManager
            }?.displayName ?? ""
            TimelineExporter.exportPDF(
                events: allEvents,
                lanes: lanes,
                eras: eras,
                colorScheme: colorScheme,
                viewport: viewport,
                documentTitle: documentTitle
            )
        }
        .onChange(of: exportPNG) { _, triggered in
            guard triggered else { return }
            exportPNG = false
            let documentTitle = NSDocumentController.shared.documents.first {
                $0.undoManager === undoManager
            }?.displayName ?? ""
            TimelineExporter.exportPNG(
                events: allEvents,
                lanes: lanes,
                eras: eras,
                colorScheme: colorScheme,
                viewport: viewport,
                documentTitle: documentTitle
            )
        }
        .onAppear {
            registerWithScriptingBridge()
        }
        .onDisappear {
            if let id = registryID {
                DocumentRegistry.shared.unregister(id: id)
                registryID = nil
            }
        }
    }

    /// Register this document's ModelContext with the scripting DocumentRegistry
    /// so AppleScript can discover and operate on it.
    private func registerWithScriptingBridge() {
        // Determine the document's file URL by finding the NSDocument whose
        // undoManager matches ours (SwiftUI DocumentGroup shares the undoManager).
        let fileURL: URL? = NSDocumentController.shared.documents.first { doc in
            doc.undoManager === undoManager
        }?.fileURL

        registryID = DocumentRegistry.shared.register(
            context: modelContext,
            fileURL: fileURL
        )
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
        let allEvents: [TimelineEvent] = [
            kickoff, sprint1, designReview, sprint2, clientDemo,
            sprint3, codeFreeze, qaPhase, launchDay, teamRetro,
            birthday, vacation, dentist, moveIn, concert,
            bookClub, homReno, halfMarathon, familyVisit, anniversary,
        ]
        for event in allEvents {
            modelContext.insert(event)
        }

        // ── Sample Eras ──

        let sprintPhase = Era(
            name: "Sprint Phase",
            startDate: flexDay(today),
            endDate: flexDay(dayDate(42)),
            sortOrder: 0
        )
        let vacationSeason = Era(
            name: "Vacation Season",
            startDate: flexDay(dayDate(10)),
            endDate: flexDay(dayDate(17)),
            sortOrder: 1
        )

        modelContext.insert(sprintPhase)
        modelContext.insert(vacationSeason)

        fitToContent = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TimelineEvent.self, Lane.self, Era.self], inMemory: true)
}
