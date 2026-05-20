// AIRoutineService.swift
// Generates coaching hints for exercises in a WorkoutSplit.
//
// Architecture notes:
//   • Singleton — created once, shared via AIRoutineService.shared.
//   • Non-throwing — all errors are swallowed so the app always works offline.
//   • Currently rule-based (see generateHint). Swap the body of that method
//     for an Anthropic API call when a real LLM integration is ready.
//   • Feature-gated: callers should check RoutineViewModel.aiEnabled before
//     calling suggest(for:).

import Foundation

final class AIRoutineService {
    static let shared = AIRoutineService()
    private init() {}

    // MARK: - Public

    /// Returns a dictionary mapping SplitExercise IDs to hint strings.
    /// Simulates a ~600 ms network round-trip.
    /// Never throws — failures produce an empty result rather than an error.
    ///
    /// - Parameter split: The split whose exercises should be analysed.
    /// - Returns: `[exerciseID: hintText]`. Exercises with no hint are absent.
    func suggest(for split: WorkoutSplit) async -> [UUID: String] {
        try? await Task.sleep(for: .milliseconds(600))

        var hints: [UUID: String] = [:]
        for day in split.days {
            for exercise in day.exercises {
                if let hint = generateHint(exercise: exercise, dayExerciseCount: day.exercises.count) {
                    hints[exercise.id] = hint
                }
            }
        }
        return hints
    }

    // MARK: - Private

    /// Rule-based hint generator — replace with an LLM call when ready.
    ///
    /// - Parameters:
    ///   - exercise: The exercise being analysed.
    ///   - dayExerciseCount: Total number of exercises in the same day,
    ///     used to warn about overly long sessions.
    /// - Returns: A hint string, or `nil` if no applicable rule fires.
    private func generateHint(exercise: SplitExercise, dayExerciseCount: Int) -> String? {
        if exercise.targetReps <= 4 {
            return "💡 Very low reps — ideal for max strength. Add 2–3 warm-up sets before working sets."
        }
        if exercise.targetReps >= 15 {
            return "💡 High rep range — keep rest short (60–90 s) and ensure RIR ≥ 1 on each set."
        }
        if exercise.targetSets >= 5 {
            return "💡 High volume — track weekly sets per muscle group to avoid junk volume."
        }
        if exercise.targetRIR == 0 {
            return "💡 Training to failure every set — consider leaving 1 RIR on early sets to preserve quality."
        }
        if dayExerciseCount > 6 {
            return "💡 Long session — prioritise compound movements first; consider splitting into AM/PM."
        }
        return nil
    }
}
