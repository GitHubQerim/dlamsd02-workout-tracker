import SwiftUI
import SwiftData

private enum WorkoutsTab: String, CaseIterable {
    case plans = "Pläne"
    case workouts = "Workouts"
}

struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.createdAt, order: .reverse) private var plans: [Workout]
    @Query(sort: \WorkoutProgram.createdAt, order: .reverse) private var programs: [WorkoutProgram]
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate == nil }) private var openSessions: [WorkoutSession]

    @State private var isPresentingNewPlan = false
    @State private var isPresentingNewProgram = false
    @State private var freeTrainingSessionViewModel: WorkoutSessionViewModel?
    @State private var selectedTab: WorkoutsTab = .plans
    @State private var isShowingAllPrograms = false
    @State private var expandedWorkoutGroups: Set<ActivityType> = []

    private static let collapsedItemLimit = 5

    private var hasOpenSession: Bool { !openSessions.isEmpty }

    /// Workouts nach `ActivityType` gruppiert, in der festen `allCases`-
    /// Reihenfolge statt der unbestimmten Dictionary-Reihenfolge. Innerhalb
    /// einer Gruppe bleibt die Query-Sortierung (neueste zuerst) erhalten.
    private var groupedPlans: [(ActivityType, [Workout])] {
        let grouped = Dictionary(grouping: plans, by: \.activityType)
        return ActivityType.allCases.compactMap { type in
            guard let items = grouped[type], !items.isEmpty else { return nil }
            return (type, items)
        }
    }

    private var visiblePrograms: [WorkoutProgram] {
        isShowingAllPrograms ? programs : Array(programs.prefix(Self.collapsedItemLimit))
    }

    private func visibleItems(_ items: [Workout], isExpanded: Bool) -> [Workout] {
        isExpanded ? items : Array(items.prefix(Self.collapsedItemLimit))
    }

    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                if let openSession = openSessions.first {
                    openSessionBanner(openSession)
                }

                HStack(spacing: DSSpacing.s8) {
                    ForEach(WorkoutsTab.allCases, id: \.self) { tab in
                        DSChip(title: tab.rawValue, active: selectedTab == tab) {
                            selectedTab = tab
                        }
                    }
                }

                if selectedTab == .plans {
                    // "calendar" existiert nicht als Asset im Catalog - bis
                    // ein eigenes Kalender-Icon ergänzt wird, "chart-column"
                    // als nächstliegender Stand-in (Struktur/Plan-Symbolik).
                    DSButton(title: "Plan erstellen", icon: "chart-column", fullWidth: true) {
                        isPresentingNewProgram = true
                    }
                    .disabled(hasOpenSession)

                    if programs.isEmpty {
                        Text("Noch keine Pläne erstellt")
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)
                    } else {
                        VStack(spacing: DSSpacing.cardGap) {
                            ForEach(visiblePrograms) { program in
                                NavigationLink {
                                    WorkoutProgramDetailView(program: program)
                                } label: {
                                    programCard(program)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        expandToggle(totalCount: programs.count, isExpanded: isShowingAllPrograms) {
                            isShowingAllPrograms.toggle()
                        }
                    }
                } else {
                    DSButton(title: "Neues Workout", icon: "dumbbell", fullWidth: true) {
                        isPresentingNewPlan = true
                    }
                    .disabled(hasOpenSession)

                    if plans.isEmpty {
                        Text("Noch keine Workouts angelegt")
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: DSSpacing.cardGap) {
                            ForEach(groupedPlans, id: \.0) { activityType, items in
                                Text(activityType.displayName)
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textTertiary)

                                let isExpanded = expandedWorkoutGroups.contains(activityType)
                                VStack(spacing: DSSpacing.cardGap) {
                                    ForEach(visibleItems(items, isExpanded: isExpanded)) { plan in
                                        NavigationLink {
                                            WorkoutDetailView(plan: plan)
                                        } label: {
                                            DSCard {
                                                HStack {
                                                    Text(plan.name)
                                                        .font(DSFont.body)
                                                        .foregroundStyle(DSColor.textPrimary)
                                                    Spacer()
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                expandToggle(totalCount: items.count, isExpanded: isExpanded) {
                                    if isExpanded {
                                        expandedWorkoutGroups.remove(activityType)
                                    } else {
                                        expandedWorkoutGroups.insert(activityType)
                                    }
                                }
                            }
                        }
                    }
                }

                Text("Freies Training")
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.cardGap) {
                        ForEach(ActivityType.allCases) { type in
                            DSChip(title: type.displayName, icon: "flame") {
                                freeTrainingSessionViewModel = WorkoutSessionViewModel.start(
                                    context: modelContext,
                                    plan: nil,
                                    activityType: type
                                )
                            }
                        }
                    }
                }
                .disabled(hasOpenSession)
            }
        }
        .navigationTitle("Workouts")
        .sheet(isPresented: $isPresentingNewPlan) {
            WorkoutEditorView(context: modelContext)
        }
        .sheet(isPresented: $isPresentingNewProgram) {
            WorkoutProgramEditorView(context: modelContext)
        }
        .fullScreenCover(item: $freeTrainingSessionViewModel) { sessionViewModel in
            WorkoutSessionView(viewModel: sessionViewModel)
        }
    }

    @ViewBuilder
    private func programCard(_ program: WorkoutProgram) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                HStack {
                    Text(program.name)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                    if program.isDefault {
                        DSChip(title: "Standard", active: true) {}
                    }
                    Spacer()
                }
                Text("\(program.entries.count) Tage")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textTertiary)
                if program.isDefault, let next = program.nextEntry(in: modelContext) {
                    Text(next.nextDayDisplayText)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func expandToggle(totalCount: Int, isExpanded: Bool, toggle: @escaping () -> Void) -> some View {
        if totalCount > Self.collapsedItemLimit {
            Button(action: toggle) {
                Text(isExpanded ? "Weniger anzeigen" : "Alle \(totalCount) anzeigen")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.accent)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func openSessionBanner(_ session: WorkoutSession) -> some View {
        DSCard(borderColor: DSColor.accent) {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.s4) {
                    Text("Training läuft")
                        .font(DSFont.label)
                        .foregroundStyle(DSColor.accent)
                    Text(session.activityType.displayName)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                }
                Spacer()
                DSButton(title: "Fortsetzen", variant: .outline) {
                    freeTrainingSessionViewModel = WorkoutSessionViewModel(context: modelContext, session: session)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutsView()
    }
}
