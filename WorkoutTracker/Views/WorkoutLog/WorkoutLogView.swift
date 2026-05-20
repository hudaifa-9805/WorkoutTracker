// WorkoutLogView.swift
// Full-screen workout logging experience presented as a modal sheet from HomeView.
//
// This file also hosts shared workout UI components consumed by both WorkoutLogView
// and LogDashboardView to avoid duplication:
//   WorkoutTimerBanner, EmptyWorkoutStartView, SplitDayPickerView,
//   ActiveWorkoutScrollContent, ExerciseLogCard, SetColumnHeader, SetRow,
//   LogTextField, RIRStepper, ExercisePickerSheet

import SwiftUI

// MARK: - WorkoutLogView

struct WorkoutLogView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var routineVM: RoutineViewModel
    @State private var showExercisePicker = false
    @State private var showDiscardAlert   = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSessionActive {
                    ActiveWorkoutScrollContent(
                        viewModel: viewModel,
                        showExercisePicker: $showExercisePicker
                    )
                } else {
                    startPromptView
                }
            }
            .background(Color.appBackground)
            .navigationTitle(viewModel.isSessionActive
                             ? viewModel.activeSession?.name ?? "Workout"
                             : "Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.isSessionActive {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Discard") { showDiscardAlert = true }
                            .foregroundColor(.red)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Finish") { viewModel.finishWorkout() }
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
            }
            .alert("Discard Workout?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) {
                    viewModel.discardWorkout()
                    dismiss()
                }
                Button("Continue", role: .cancel) {}
            } message: {
                Text("Your progress will be lost.")
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { exercise in viewModel.addExercise(exercise) }
            }
        }
    }

    // MARK: - Start Prompt

    private var startPromptView: some View {
        Group {
            if let activeSplit = routineVM.activeSplit {
                SplitDayPickerView(split: activeSplit, viewModel: viewModel)
            } else {
                EmptyWorkoutStartView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - WorkoutTimerBanner
// Displays elapsed time and total completed sets for an active session.

struct WorkoutTimerBanner: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text(viewModel.formattedElapsed)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Spacer()
            let sets = viewModel.activeSession?.totalSets ?? 0
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(sets)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("sets done")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - EmptyWorkoutStartView
// Shown when no active split is selected. Lets the user start a blank session.

struct EmptyWorkoutStartView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    /// Subtitle copy; callers can override for context-specific messaging.
    var subtitle: String = "Start a new session to begin logging sets"

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color.orange.opacity(0.4))
            }
            Text("No active workout")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.3))
                .multilineTextAlignment(.center)
            Button(action: { viewModel.startWorkout() }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 200, height: 52)
                .background(
                    LinearGradient(colors: [.orange, Color.orangeGradientEnd],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(color: .orange.opacity(0.35), radius: 12, y: 6)
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - SplitDayPickerView
// Shows the days of the active routine as tappable cards to start a session.

struct SplitDayPickerView: View {
    let split: WorkoutSplit
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Active split header
                VStack(spacing: 6) {
                    Label("Active Routine", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(split.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("Pick a day to start your session")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.top, 24)

                // Day cards
                ForEach(split.days.sorted { $0.order < $1.order }) { day in
                    Button(action: { viewModel.startWorkout(from: day, in: split) }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(day.exercises.isEmpty
                                     ? "No exercises"
                                     : "\(day.exercises.count) exercise\(day.exercises.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                // Empty workout fallback
                Button(action: { viewModel.startWorkout() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("Empty Workout")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - ActiveWorkoutScrollContent
// Scrollable exercise list shown during an active session.

struct ActiveWorkoutScrollContent: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @Binding var showExercisePicker: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                WorkoutTimerBanner(viewModel: viewModel)
                    .padding(.horizontal, 16)

                ForEach(
                    Array((viewModel.activeSession?.exercises ?? []).enumerated()),
                    id: \.element.id
                ) { exIdx, workoutExercise in
                    ExerciseLogCard(
                        workoutExercise: workoutExercise,
                        onAddSet: { viewModel.addSet(to: exIdx) },
                        onToggleSet: { setIdx in
                            viewModel.toggleSetComplete(exerciseIndex: exIdx, setIndex: setIdx)
                        },
                        onUpdateSet: { setIdx, weight, reps, rir in
                            viewModel.activeSession?.exercises[exIdx].sets[setIdx].weight = weight
                            viewModel.activeSession?.exercises[exIdx].sets[setIdx].reps   = reps
                            viewModel.activeSession?.exercises[exIdx].sets[setIdx].rir    = rir
                        }
                    )
                    .padding(.horizontal, 16)
                }

                Button(action: { showExercisePicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("Add Exercise")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - ExerciseLogCard
// Card displaying a single exercise with its sets during an active session.

struct ExerciseLogCard: View {
    let workoutExercise: WorkoutExercise
    let onAddSet:    () -> Void
    let onToggleSet: (Int) -> Void
    let onUpdateSet: (Int, Double, Int, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workoutExercise.exercise.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(workoutExercise.exercise.primaryMuscles.map(\.rawValue).joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                Spacer()
                if let best = workoutExercise.bestSet {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Best")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.35))
                        Text("\(best.weight, specifier: "%.1f") kg × \(best.reps)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Column headers
            SetColumnHeader()
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 16)

            // Sets
            VStack(spacing: 0) {
                ForEach(Array(workoutExercise.sets.enumerated()), id: \.element.id) { idx, set in
                    SetRow(set: set, onToggle: { onToggleSet(idx) })
                    if idx < workoutExercise.sets.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.04))
                            .padding(.horizontal, 16)
                    }
                }
            }

            // Add set
            Button(action: onAddSet) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Add Set")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color.white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - SetColumnHeader
// Column labels (SET / WEIGHT / REPS / RIR) above the set list.

struct SetColumnHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("SET")   .frame(width: 38, alignment: .center)
            Text("WEIGHT").frame(maxWidth: .infinity, alignment: .center)
            Text("REPS")  .frame(width: 64, alignment: .center)
            Text("RIR")   .frame(width: 76, alignment: .center)
            Spacer().frame(width: 40)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(Color.white.opacity(0.28))
        .kerning(0.6)
    }
}

// MARK: - SetRow
// A single row in the set list: set number, weight, reps, RIR stepper, done toggle.

struct SetRow: View {
    let set:      WorkoutSet
    let onToggle: () -> Void

    @State private var weightText: String
    @State private var repsText:   String
    @State private var rirValue:   Int

    init(set: WorkoutSet, onToggle: @escaping () -> Void) {
        self.set      = set
        self.onToggle = onToggle
        _weightText = State(initialValue: set.weight > 0 ? String(format: "%.1f", set.weight) : "")
        _repsText   = State(initialValue: set.reps > 0 ? "\(set.reps)" : "")
        _rirValue   = State(initialValue: set.rir)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Set number badge
            Text("\(set.setNumber)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(set.isCompleted ? .orange : Color.white.opacity(0.35))
                .frame(width: 38, alignment: .center)

            // Weight
            LogTextField(text: $weightText, placeholder: "0", keyboard: .decimalPad, completed: set.isCompleted)
                .frame(maxWidth: .infinity)
                .padding(.trailing, 6)

            // Reps
            LogTextField(text: $repsText, placeholder: "0", keyboard: .numberPad, completed: set.isCompleted)
                .frame(width: 58)
                .padding(.trailing, 6)

            // RIR stepper
            RIRStepper(value: $rirValue, completed: set.isCompleted)
                .frame(width: 70)

            // Done button
            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(set.isCompleted ? .orange : Color.white.opacity(0.18))
            }
            .frame(width: 40, alignment: .center)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(set.isCompleted ? Color.orange.opacity(0.05) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: set.isCompleted)
    }
}

// MARK: - LogTextField
// Styled text field used for weight and reps input within a SetRow.

struct LogTextField: View {
    @Binding var text: String
    let placeholder: String
    let keyboard:    UIKeyboardType
    let completed:   Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .tint(.orange)
            .frame(height: 36)
            .background(Color.white.opacity(completed ? 0.1 : 0.06))
            .cornerRadius(9)
    }
}

// MARK: - RIRStepper
// Compact +/− stepper for Reps In Reserve (0–4).

struct RIRStepper: View {
    @Binding var value: Int
    let completed: Bool

    private let maxRIR = 4

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { if value > 0 { value -= 1 } }) {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 24, height: 36)
            }
            Text("\(value)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(completed ? .orange : .white)
                .frame(width: 22)
            Button(action: { if value < maxRIR { value += 1 } }) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 24, height: 36)
            }
        }
        .background(Color.white.opacity(completed ? 0.1 : 0.06))
        .cornerRadius(9)
    }
}

// MARK: - ExercisePickerSheet
// Modal sheet for adding an exercise to the active session.
// Also used by SplitEditorView when building routine days.

struct ExercisePickerSheet: View {
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var search = ""

    private var filtered: [Exercise] {
        search.isEmpty
            ? Exercise.sampleData
            : Exercise.sampleData.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { exercise in
                Button(action: {
                    onSelect(exercise)
                    dismiss()
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 42, height: 42)
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text(exercise.primaryMuscles.map(\.rawValue).joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.white.opacity(0.05))
                .listRowSeparatorTint(Color.white.opacity(0.07))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

#Preview {
    WorkoutLogView()
        .environmentObject(WorkoutViewModel())
        .environmentObject(RoutineViewModel())
}
