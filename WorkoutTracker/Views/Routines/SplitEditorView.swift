// SplitEditorView.swift
// Create / edit a WorkoutSplit. Hosts day management (add, delete, reorder) and
// delegates per-day exercise editing to DayExerciseEditorView.
// Sub-components: DayEditorRow, DayExerciseEditorView, SplitExerciseRow,
//                 SplitExerciseEditorSheet, TargetStepper.

import SwiftUI

// MARK: - Split Editor

enum SplitEditorMode {
    case create
    case edit(WorkoutSplit)
}

struct SplitEditorView: View {
    @EnvironmentObject var routineVM: RoutineViewModel
    @Environment(\.dismiss) var dismiss

    let mode: SplitEditorMode

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var days: [SplitDay] = []
    @State private var showAddDay = false
    @State private var newDayName = ""
    @State private var editingDay: SplitDay?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            List {
                // Split Info
                Section("Split Name") {
                    TextField("e.g. Push / Pull / Legs", text: $name)
                        .foregroundColor(.white)
                        .tint(.orange)
                        .listRowBackground(Color.white.opacity(0.05))
                }
                Section("Description (optional)") {
                    TextField("Brief description of this routine", text: $description)
                        .foregroundColor(.white)
                        .tint(.orange)
                        .listRowBackground(Color.white.opacity(0.05))
                }

                // Days
                Section {
                    ForEach(days.sorted { $0.order < $1.order }) { day in
                        DayEditorRow(day: day) {
                            editingDay = day
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        .listRowSeparatorTint(Color.white.opacity(0.07))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                days.removeAll { $0.id == day.id }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    .onMove { from, to in
                        days.move(fromOffsets: from, toOffset: to)
                        for i in days.indices { days[i].order = i }
                    }

                    Button(action: { showAddDay = true }) {
                        Label("Add Day", systemImage: "plus")
                            .foregroundColor(.orange)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                } header: {
                    HStack {
                        Text("Training Days")
                        Spacer()
                        Text("Swipe to delete · drag to reorder")
                            .font(.caption2)
                            .foregroundColor(Color.white.opacity(0.25))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .environment(\.editMode, .constant(.active))
            .navigationTitle(isEditing ? "Edit Split" : "New Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Create") { save() }
                        .fontWeight(.semibold)
                        .foregroundColor(name.isEmpty ? Color.white.opacity(0.3) : .orange)
                        .disabled(name.isEmpty)
                }
            }
            // Add day alert
            .alert("Add Training Day", isPresented: $showAddDay) {
                TextField("Day name (e.g. Push, Upper A)", text: $newDayName)
                Button("Add") {
                    guard !newDayName.isEmpty else { return }
                    let day = SplitDay(name: newDayName, order: days.count)
                    days.append(day)
                    newDayName = ""
                }
                Button("Cancel", role: .cancel) { newDayName = "" }
            }
            // Day exercise editor sheet
            .sheet(item: $editingDay) { day in
                DayExerciseEditorView(day: day) { updated in
                    if let idx = days.firstIndex(where: { $0.id == updated.id }) {
                        days[idx] = updated
                    }
                }
            }
        }
        .onAppear { populateFromMode() }
    }

    private func populateFromMode() {
        if case .edit(let split) = mode {
            name = split.name
            description = split.description
            days = split.days
        }
    }

    private func save() {
        switch mode {
        case .create:
            let split = WorkoutSplit(name: name, description: description, days: days)
            routineVM.addSplit(split)
        case .edit(let original):
            var updated = original
            updated.name = name
            updated.description = description
            updated.days = days
            routineVM.updateSplit(updated)
        }
        dismiss()
    }
}

// MARK: - Day Editor Row (inside SplitEditorView list)

struct DayEditorRow: View {
    let day: SplitDay
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(day.exercises.isEmpty
                         ? "No exercises — tap to add"
                         : "\(day.exercises.count) exercise\(day.exercises.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.25))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Exercise Editor

struct DayExerciseEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var day: SplitDay
    let onSave: (SplitDay) -> Void

    @State private var showExercisePicker = false
    @State private var editingEx: SplitExercise?

    init(day: SplitDay, onSave: @escaping (SplitDay) -> Void) {
        _day = State(initialValue: day)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if day.exercises.isEmpty {
                        Text("No exercises yet — tap + to add")
                            .foregroundColor(Color.white.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(day.exercises.sorted { $0.order < $1.order }) { ex in
                            SplitExerciseRow(ex: ex) {
                                editingEx = ex
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                            .listRowSeparatorTint(Color.white.opacity(0.07))
                            .swipeActions {
                                Button(role: .destructive) {
                                    day.exercises.removeAll { $0.id == ex.id }
                                } label: { Label("Remove", systemImage: "trash") }
                            }
                        }
                        .onMove { from, to in
                            day.exercises.move(fromOffsets: from, toOffset: to)
                            for i in day.exercises.indices { day.exercises[i].order = i }
                        }
                    }

                    Button(action: { showExercisePicker = true }) {
                        Label("Add Exercise", systemImage: "plus")
                            .foregroundColor(.orange)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                } header: {
                    Text("\(day.name) — Exercises")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .environment(\.editMode, .constant(.active))
            .navigationTitle(day.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onSave(day); dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { exercise in
                    let splitEx = SplitExercise(
                        exerciseName: exercise.name,
                        targetSets: 3,
                        targetReps: 8,
                        targetRIR: 2,
                        order: day.exercises.count,
                        targetMuscles: exercise.primaryMuscles.map(\.rawValue)
                    )
                    day.exercises.append(splitEx)
                }
            }
            .sheet(item: $editingEx) { ex in
                SplitExerciseEditorSheet(exercise: ex) { updated in
                    if let idx = day.exercises.firstIndex(where: { $0.id == updated.id }) {
                        day.exercises[idx] = updated
                    }
                    editingEx = nil
                }
            }
        }
    }
}

// MARK: - Split Exercise Row

struct SplitExerciseRow: View {
    let ex: SplitExercise
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ex.exerciseName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(ex.summaryText)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.25))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Split Exercise Editor Sheet (sets / reps / RIR)

struct SplitExerciseEditorSheet: View {
    @State private var exercise: SplitExercise
    let onSave: (SplitExercise) -> Void

    init(exercise: SplitExercise, onSave: @escaping (SplitExercise) -> Void) {
        _exercise = State(initialValue: exercise)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Exercise") {
                    Text(exercise.exerciseName)
                        .foregroundColor(Color.white.opacity(0.6))
                        .listRowBackground(Color.white.opacity(0.04))
                }

                Section("Targets") {
                    TargetStepper(label: "Sets", value: $exercise.targetSets, range: 1...10)
                    TargetStepper(label: "Reps", value: $exercise.targetReps, range: 1...30)
                    TargetStepper(label: "RIR",  value: $exercise.targetRIR,  range: 0...4)
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Edit Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { onSave(exercise) }
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - Target Stepper

struct TargetStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 0) {
                Button(action: { if value > range.lowerBound { value -= 1 } }) {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.5))
                        .frame(width: 36, height: 36)
                }
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32)
                Button(action: { if value < range.upperBound { value += 1 } }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.5))
                        .frame(width: 36, height: 36)
                }
            }
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
        }
    }
}
