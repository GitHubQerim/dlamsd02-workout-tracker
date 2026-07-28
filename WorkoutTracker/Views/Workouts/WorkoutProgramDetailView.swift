import SwiftUI
import SwiftData

/// Übersicht eines `WorkoutProgram`: geordnete Tage, Standard-Markierung und
/// die "weiter mit Day N"-Aktion zum direkten Start des nächsten Tages.
struct WorkoutProgramDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate == nil }) private var openSessions: [WorkoutSession]
    let program: WorkoutProgram

    @State private var isPresentingEditor = false
    @State private var activeSessionViewModel: WorkoutSessionViewModel?

    private var orderedEntries: [WorkoutProgramEntry] {
        program.entries.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var nextEntry: WorkoutProgramEntry? {
        program.nextEntry(in: modelContext)
    }

    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                HStack {
                    Text(program.name)
                        .font(DSFont.screenTitle)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer()
                    if program.isDefault {
                        DSChip(title: "Standard", active: true) {}
                    }
                }

                if !program.isDefault {
                    DSButton(title: "Als Standard festlegen", variant: .outline, fullWidth: true) {
                        WorkoutProgramEditorViewModel.setAsDefaultAndSave(program, in: modelContext)
                    }
                }

                VStack(spacing: DSSpacing.cardGap) {
                    ForEach(orderedEntries) { entry in
                        if let workout = entry.workout {
                            NavigationLink {
                                WorkoutDetailView(plan: workout)
                            } label: {
                                entryCard(entry, workoutMissing: false)
                            }
                            .buttonStyle(.plain)
                        } else {
                            entryCard(entry, workoutMissing: true)
                        }
                    }
                }

                DSButton(title: "Bearbeiten", variant: .outline, fullWidth: true) {
                    isPresentingEditor = true
                }

                if let nextEntry {
                    DSButton(title: nextEntry.nextDayDisplayText, fullWidth: true) {
                        activeSessionViewModel = WorkoutSessionViewModel.start(
                            context: modelContext,
                            programEntry: nextEntry,
                            programName: program.name
                        )
                    }
                    .disabled(!openSessions.isEmpty || nextEntry.workout == nil)

                    if nextEntry.workout == nil {
                        Text("Workout wurde gelöscht - dieser Tag kann nicht gestartet werden.")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textTertiary)
                    } else if !openSessions.isEmpty {
                        Text("Es läuft bereits ein Training - erst dort beenden oder abbrechen.")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textTertiary)
                    }
                }
            }
        }
        .navigationTitle("Plan")
        .sheet(isPresented: $isPresentingEditor) {
            WorkoutProgramEditorView(context: modelContext, editing: program)
        }
        .fullScreenCover(item: $activeSessionViewModel) { sessionViewModel in
            WorkoutSessionView(viewModel: sessionViewModel)
        }
    }

    @ViewBuilder
    private func entryCard(_ entry: WorkoutProgramEntry, workoutMissing: Bool) -> some View {
        DSCard {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.s4) {
                    Text(entry.dayLabel)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(entry.workoutName)
                        .font(DSFont.caption)
                        .foregroundStyle(workoutMissing ? DSColor.textTertiary : DSColor.textSecondary)
                }
                Spacer()
            }
        }
    }
}
