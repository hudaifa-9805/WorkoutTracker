// WorkoutSplit.swift
// Defines a user's training plan as a hierarchy:
//   WorkoutSplit → [SplitDay] → [SplitExercise]
// Splits are persisted to UserDefaults (via RoutineViewModel) and can carry
// optional AI-generated hints on each exercise.

import Foundation

// MARK: - WorkoutSplit

/// A named training programme containing one or more training days.
struct WorkoutSplit: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var days: [SplitDay]
    var createdAt: Date
    /// Whether this is the user's currently selected training programme.
    var isActive: Bool
    var aiSuggestionsEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        days: [SplitDay] = [],
        createdAt: Date = .now,
        isActive: Bool = false,
        aiSuggestionsEnabled: Bool = true
    ) {
        self.id                    = id
        self.name                  = name
        self.description           = description
        self.days                  = days
        self.createdAt             = createdAt
        self.isActive              = isActive
        self.aiSuggestionsEnabled  = aiSuggestionsEnabled
    }

    /// Human-readable training frequency, e.g. "3 days / week".
    var frequency: String {
        "\(days.count) day\(days.count == 1 ? "" : "s") / week"
    }

    /// Total number of exercises across all days.
    var totalExercises: Int {
        days.reduce(0) { $0 + $1.exercises.count }
    }

    /// Unique muscle group names targeted by this split, in insertion order.
    var muscleGroupTags: [String] {
        let all = days.flatMap { $0.exercises.flatMap { $0.targetMuscles } }
        var seen = Set<String>()
        return all.filter { seen.insert($0).inserted }
    }
}

// MARK: - SplitDay

/// One training day within a split (e.g. "Push", "Upper A").
struct SplitDay: Identifiable, Codable {
    let id: UUID
    var name: String
    /// Zero-based position within the split, used for display ordering.
    var order: Int
    var exercises: [SplitExercise]

    init(
        id: UUID = UUID(),
        name: String,
        order: Int = 0,
        exercises: [SplitExercise] = []
    ) {
        self.id        = id
        self.name      = name
        self.order     = order
        self.exercises = exercises
    }

    /// Comma-separated list of up to 3 unique targeted muscles, for subtitle display.
    var muscleSummary: String {
        let muscles = exercises.flatMap { $0.targetMuscles }
        var seen    = Set<String>()
        let unique  = muscles.filter { seen.insert($0).inserted }
        return unique.prefix(3).joined(separator: " · ")
    }
}

// MARK: - SplitExercise

/// A prescribed exercise within a training day, including target sets/reps/RIR.
struct SplitExercise: Identifiable, Codable {
    let id: UUID
    var exerciseName: String
    var targetSets: Int
    var targetReps: Int
    var targetRIR: Int
    var order: Int
    /// Muscle groups stored directly so look-ups against Exercise.sampleData are avoided.
    var targetMuscles: [String]
    /// Optional AI-generated coaching hint (non-blocking; may be nil).
    var aiHint: String?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        targetSets: Int = 3,
        targetReps: Int = 8,
        targetRIR: Int = 2,
        order: Int = 0,
        targetMuscles: [String] = [],
        aiHint: String? = nil
    ) {
        self.id            = id
        self.exerciseName  = exerciseName
        self.targetSets    = targetSets
        self.targetReps    = targetReps
        self.targetRIR     = targetRIR
        self.order         = order
        self.targetMuscles = targetMuscles
        self.aiHint        = aiHint
    }

    /// Short prescription summary used in list rows, e.g. "3 × 8  ·  RIR 2".
    var summaryText: String { "\(targetSets) × \(targetReps)  ·  RIR \(targetRIR)" }
}

// MARK: - Sample Data

extension WorkoutSplit {
    /// Two pre-built splits used as defaults on first launch.
    static let sampleSplits: [WorkoutSplit] = [
        WorkoutSplit(
            name: "Push / Pull / Legs",
            description: "Classic 6-day PPL split for hypertrophy",
            days: [
                SplitDay(name: "Push", order: 0, exercises: [
                    SplitExercise(exerciseName: "Bench Press",           targetSets: 4, targetReps: 8,  targetRIR: 2, order: 0, targetMuscles: ["Chest", "Triceps"]),
                    SplitExercise(exerciseName: "Incline Dumbbell Press", targetSets: 3, targetReps: 10, targetRIR: 2, order: 1, targetMuscles: ["Chest"]),
                    SplitExercise(exerciseName: "Overhead Press",         targetSets: 3, targetReps: 10, targetRIR: 2, order: 2, targetMuscles: ["Shoulders"]),
                    SplitExercise(exerciseName: "Tricep Pushdown",        targetSets: 3, targetReps: 12, targetRIR: 2, order: 3, targetMuscles: ["Triceps"]),
                ]),
                SplitDay(name: "Pull", order: 1, exercises: [
                    SplitExercise(exerciseName: "Pull-Up",     targetSets: 4, targetReps: 8,  targetRIR: 2, order: 0, targetMuscles: ["Back", "Biceps"]),
                    SplitExercise(exerciseName: "Cable Row",   targetSets: 3, targetReps: 10, targetRIR: 2, order: 1, targetMuscles: ["Back"]),
                    SplitExercise(exerciseName: "Lat Pulldown",targetSets: 3, targetReps: 12, targetRIR: 2, order: 2, targetMuscles: ["Back"]),
                ]),
                SplitDay(name: "Legs", order: 2, exercises: [
                    SplitExercise(exerciseName: "Squat",             targetSets: 4, targetReps: 6,  targetRIR: 2, order: 0, targetMuscles: ["Quads", "Glutes"]),
                    SplitExercise(exerciseName: "Romanian Deadlift", targetSets: 3, targetReps: 10, targetRIR: 2, order: 1, targetMuscles: ["Hamstrings"]),
                ]),
            ],
            isActive: true
        ),
        WorkoutSplit(
            name: "Upper / Lower",
            description: "4-day upper/lower split",
            days: [
                SplitDay(name: "Upper A", order: 0, exercises: [
                    SplitExercise(exerciseName: "Bench Press", targetSets: 4, targetReps: 5, targetRIR: 2, order: 0, targetMuscles: ["Chest"]),
                    SplitExercise(exerciseName: "Pull-Up",     targetSets: 4, targetReps: 6, targetRIR: 2, order: 1, targetMuscles: ["Back"]),
                ]),
                SplitDay(name: "Lower A", order: 1, exercises: [
                    SplitExercise(exerciseName: "Squat",    targetSets: 4, targetReps: 5, targetRIR: 2, order: 0, targetMuscles: ["Quads"]),
                    SplitExercise(exerciseName: "Deadlift", targetSets: 3, targetReps: 5, targetRIR: 2, order: 1, targetMuscles: ["Back", "Hamstrings"]),
                ]),
            ]
        ),
    ]
}
