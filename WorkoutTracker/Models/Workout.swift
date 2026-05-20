// Workout.swift
// Models for an active or completed workout session.
// WorkoutSession is the top-level container; WorkoutExercise groups a single
// exercise with all sets logged against it.

import Foundation

// MARK: - Workout Session

/// A complete workout session containing one or more exercises.
struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var date: Date
    var exercises: [WorkoutExercise]
    var notes: String
    /// Total elapsed time in seconds, recorded when the session is finished.
    var durationSeconds: Int?

    init(
        id: UUID = UUID(),
        name: String = "Workout",
        date: Date = .now,
        exercises: [WorkoutExercise] = [],
        notes: String = "",
        durationSeconds: Int? = nil
    ) {
        self.id              = id
        self.name            = name
        self.date            = date
        self.exercises       = exercises
        self.notes           = notes
        self.durationSeconds = durationSeconds
    }

    /// Total number of completed sets across all exercises.
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    /// Total volume (kg) across all completed sets: Σ (weight × reps).
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }

    /// Human-readable duration string, e.g. "1h 15m" or "45m".
    var formattedDuration: String {
        guard let secs = durationSeconds else { return "--" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// MARK: - Workout Exercise

/// One exercise slot within a session — the exercise definition plus all recorded sets.
struct WorkoutExercise: Identifiable, Codable {
    let id: UUID
    var exercise: Exercise
    var sets: [WorkoutSet]
    var notes: String

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        sets: [WorkoutSet] = [],
        notes: String = ""
    ) {
        self.id       = id
        self.exercise = exercise
        self.sets     = sets
        self.notes    = notes
    }

    /// Total volume for completed sets only.
    var totalVolume: Double {
        sets.filter(\.isCompleted).reduce(0) { $0 + $1.volume }
    }

    /// The heaviest completed set (by weight), used to show a "best set" badge.
    var bestSet: WorkoutSet? {
        sets.filter(\.isCompleted).max { $0.weight < $1.weight }
    }
}

// MARK: - Sample Data

extension WorkoutSession {
    /// Pre-populated session used for SwiftUI previews.
    static let sample = WorkoutSession(
        name: "Push Day",
        date: .now,
        exercises: [
            WorkoutExercise(
                exercise: Exercise.sampleData[0],
                sets: [
                    WorkoutSet(setNumber: 1, weight: 60, reps: 12, rir: 3, isCompleted: true, setType: .warmup),
                    WorkoutSet(setNumber: 2, weight: 80, reps: 8,  rir: 2, isCompleted: true),
                    WorkoutSet(setNumber: 3, weight: 80, reps: 7,  rir: 1, isCompleted: true),
                    WorkoutSet(setNumber: 4, weight: 80, reps: 6,  rir: 0, isCompleted: false),
                ]
            ),
            WorkoutExercise(
                exercise: Exercise.sampleData[6],
                sets: [
                    WorkoutSet(setNumber: 1, weight: 24, reps: 10, rir: 2),
                    WorkoutSet(setNumber: 2, weight: 24, reps: 10, rir: 2),
                    WorkoutSet(setNumber: 3, weight: 24, reps: 10, rir: 2),
                ]
            ),
        ]
    )
}
