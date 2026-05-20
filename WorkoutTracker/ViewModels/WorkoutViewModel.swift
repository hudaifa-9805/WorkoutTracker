// WorkoutViewModel.swift
// Manages the lifecycle of the currently active workout session and the list of
// past sessions. Also owns the elapsed-time timer that drives the session timer UI.

import Foundation
import Combine

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var activeSession: WorkoutSession?
    @Published var pastSessions: [WorkoutSession] = []
    @Published var isSessionActive = false
    @Published var elapsedSeconds  = 0

    private var timer: AnyCancellable?

    // MARK: - Session Lifecycle

    /// Starts a new empty workout session with an optional name.
    func startWorkout(name: String = "Workout") {
        activeSession  = WorkoutSession(name: name)
        isSessionActive = true
        elapsedSeconds  = 0
        startTimer()
    }

    /// Starts a session pre-populated from a split day's exercise prescriptions.
    /// Exercises are matched by name against `Exercise.sampleData`; unmatched
    /// names produce a placeholder Exercise so the UI never crashes.
    ///
    /// - Parameters:
    ///   - day: The SplitDay to use as a template.
    ///   - split: The parent WorkoutSplit (used to build the session name).
    func startWorkout(from day: SplitDay, in split: WorkoutSplit) {
        let sessionName = "\(split.name)  ·  \(day.name)"
        activeSession   = WorkoutSession(name: sessionName)
        isSessionActive  = true
        elapsedSeconds   = 0

        for splitEx in day.exercises.sorted(by: { $0.order < $1.order }) {
            // Name-based look-up — replace with ID-based look-up once exercises
            // are persisted in Supabase.
            let exercise = Exercise.sampleData.first {
                $0.name.lowercased() == splitEx.exerciseName.lowercased()
            } ?? Exercise(
                id: UUID(),
                name: splitEx.exerciseName,
                category: .strength,
                primaryMuscles: [],
                secondaryMuscles: [],
                equipment: .barbell,
                instructions: ""
            )
            let sets = (0..<splitEx.targetSets).enumerated().map { i, _ in
                WorkoutSet(setNumber: i + 1, reps: splitEx.targetReps, rir: splitEx.targetRIR)
            }
            activeSession?.exercises.append(WorkoutExercise(exercise: exercise, sets: sets))
        }
        startTimer()
    }

    /// Appends a new exercise with one empty working set to the active session.
    func addExercise(_ exercise: Exercise) {
        guard activeSession != nil else { return }
        let slot = WorkoutExercise(exercise: exercise, sets: [WorkoutSet(setNumber: 1)])
        activeSession?.exercises.append(slot)
    }

    /// Appends a new empty working set to the exercise at `exerciseIndex`.
    func addSet(to exerciseIndex: Int) {
        guard activeSession != nil else { return }
        let nextNumber = (activeSession?.exercises[exerciseIndex].sets.count ?? 0) + 1
        activeSession?.exercises[exerciseIndex].sets.append(WorkoutSet(setNumber: nextNumber))
    }

    /// Removes the set at `setIndex` from the exercise at `exerciseIndex`.
    func removeSet(from exerciseIndex: Int, setIndex: Int) {
        activeSession?.exercises[exerciseIndex].sets.remove(at: setIndex)
    }

    /// Toggles the completed state of a single set.
    func toggleSetComplete(exerciseIndex: Int, setIndex: Int) {
        activeSession?.exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
    }

    /// Finalises the active session: stamps the duration, prepends it to history,
    /// and clears active state.
    func finishWorkout() {
        guard var session = activeSession else { return }
        session.durationSeconds = elapsedSeconds
        pastSessions.insert(session, at: 0)
        activeSession   = nil
        isSessionActive  = false
        stopTimer()
    }

    /// Discards the active session without saving.
    func discardWorkout() {
        activeSession   = nil
        isSessionActive  = false
        stopTimer()
    }

    // MARK: - Timer

    /// Human-readable elapsed time, e.g. "42:07" or "1:02:33".
    var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    private func stopTimer() {
        timer?.cancel()
        timer          = nil
        elapsedSeconds = 0
    }
}
