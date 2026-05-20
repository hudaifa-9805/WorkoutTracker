// Exercise.swift
// Defines the Exercise model and all its nested enumerations (category, muscle
// group, equipment). Also ships a curated list of sample exercises used as the
// in-memory exercise library until a Supabase-backed library is implemented.

import Foundation

/// A single exercise in the library.
struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]
    var equipment: Equipment
    var instructions: String

    // MARK: - Category

    enum ExerciseCategory: String, Codable, CaseIterable {
        case strength    = "Strength"
        case cardio      = "Cardio"
        case flexibility = "Flexibility"

        /// SF Symbol name representing this category.
        var icon: String {
            switch self {
            case .strength:    return "dumbbell.fill"
            case .cardio:      return "heart.fill"
            case .flexibility: return "figure.flexibility"
            }
        }
    }

    // MARK: - Muscle Group

    enum MuscleGroup: String, Codable, CaseIterable {
        case chest      = "Chest"
        case back       = "Back"
        case shoulders  = "Shoulders"
        case biceps     = "Biceps"
        case triceps    = "Triceps"
        case forearms   = "Forearms"
        case core       = "Core"
        case glutes     = "Glutes"
        case quadriceps = "Quads"
        case hamstrings = "Hamstrings"
        case calves     = "Calves"
    }

    // MARK: - Equipment

    enum Equipment: String, Codable, CaseIterable {
        case barbell    = "Barbell"
        case dumbbell   = "Dumbbell"
        case machine    = "Machine"
        case cable      = "Cable"
        case bodyweight = "Bodyweight"
        case kettlebell = "Kettlebell"
        case band       = "Band"

        /// SF Symbol name representing this equipment type.
        var icon: String {
            switch self {
            case .barbell:    return "minus.circle"
            case .dumbbell:   return "dumbbell"
            case .machine:    return "gearshape"
            case .cable:      return "cable.connector"
            case .bodyweight: return "figure.strengthtraining.traditional"
            case .kettlebell: return "scalemass"
            case .band:       return "oval"
            }
        }
    }
}

// MARK: - Sample Data

extension Exercise {
    /// Curated list of common compound and isolation exercises.
    /// Used as the exercise library until a remote data source is available.
    static let sampleData: [Exercise] = [
        Exercise(
            id: UUID(), name: "Bench Press", category: .strength,
            primaryMuscles: [.chest], secondaryMuscles: [.triceps, .shoulders],
            equipment: .barbell,
            instructions: "Lie flat on bench. Grip bar slightly wider than shoulders. Lower bar to mid-chest, then press up to lockout."
        ),
        Exercise(
            id: UUID(), name: "Squat", category: .strength,
            primaryMuscles: [.quadriceps, .glutes], secondaryMuscles: [.hamstrings, .core],
            equipment: .barbell,
            instructions: "Bar on traps, feet shoulder-width. Sit back and down until thighs are parallel, drive through heels to stand."
        ),
        Exercise(
            id: UUID(), name: "Deadlift", category: .strength,
            primaryMuscles: [.back, .glutes], secondaryMuscles: [.hamstrings, .core],
            equipment: .barbell,
            instructions: "Hip-width stance over bar. Hinge at hips, grip bar. Drive through floor, keep bar close, lockout hips and knees."
        ),
        Exercise(
            id: UUID(), name: "Pull-Up", category: .strength,
            primaryMuscles: [.back], secondaryMuscles: [.biceps],
            equipment: .bodyweight,
            instructions: "Hang from bar, shoulder-width grip. Pull chest to bar, lower with control."
        ),
        Exercise(
            id: UUID(), name: "Overhead Press", category: .strength,
            primaryMuscles: [.shoulders], secondaryMuscles: [.triceps, .core],
            equipment: .barbell,
            instructions: "Bar at shoulder height, grip just outside shoulders. Press overhead to lockout, lower with control."
        ),
        Exercise(
            id: UUID(), name: "Romanian Deadlift", category: .strength,
            primaryMuscles: [.hamstrings, .glutes], secondaryMuscles: [.back],
            equipment: .barbell,
            instructions: "Hold bar at hips. Hinge forward keeping back straight, feel stretch in hamstrings, drive hips forward to return."
        ),
        Exercise(
            id: UUID(), name: "Incline Dumbbell Press", category: .strength,
            primaryMuscles: [.chest], secondaryMuscles: [.triceps, .shoulders],
            equipment: .dumbbell,
            instructions: "Set bench to 30–45 degrees. Press dumbbells up and slightly in, lower with control."
        ),
        Exercise(
            id: UUID(), name: "Cable Row", category: .strength,
            primaryMuscles: [.back], secondaryMuscles: [.biceps],
            equipment: .cable,
            instructions: "Sit at cable row station. Pull handle to lower chest, squeeze shoulder blades, return with control."
        ),
        Exercise(
            id: UUID(), name: "Lat Pulldown", category: .strength,
            primaryMuscles: [.back], secondaryMuscles: [.biceps],
            equipment: .machine,
            instructions: "Grip bar wide. Pull bar to upper chest, lean back slightly, return with control."
        ),
        Exercise(
            id: UUID(), name: "Tricep Pushdown", category: .strength,
            primaryMuscles: [.triceps], secondaryMuscles: [],
            equipment: .cable,
            instructions: "Set cable high. Push handle down until arms fully extended, squeeze triceps, return with control."
        ),
    ]
}
