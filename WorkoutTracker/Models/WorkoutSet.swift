// WorkoutSet.swift
// Represents a single set within a workout exercise — weight, reps, RIR,
// completion state, and set type (warmup / working / drop-set).

import Foundation

/// One set performed during a workout.
struct WorkoutSet: Identifiable, Codable {
    let id: UUID
    var setNumber: Int
    var weight: Double
    var reps: Int
    /// Reps In Reserve: how many reps the athlete could still do before failure.
    var rir: Int
    var isCompleted: Bool
    var setType: SetType

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weight: Double = 0,
        reps: Int = 0,
        rir: Int = 2,
        isCompleted: Bool = false,
        setType: SetType = .working
    ) {
        self.id          = id
        self.setNumber   = setNumber
        self.weight      = weight
        self.reps        = reps
        self.rir         = rir
        self.isCompleted = isCompleted
        self.setType     = setType
    }

    /// Weight × reps — used to sum total session volume.
    var volume: Double { weight * Double(reps) }

    // MARK: - Set Type

    enum SetType: String, Codable, CaseIterable {
        case warmup  = "W"
        case working = "S"
        case dropSet = "D"

        /// Color name (mapped to SwiftUI Color by name in views).
        var color: String {
            switch self {
            case .warmup:  return "yellow"
            case .working: return "blue"
            case .dropSet: return "purple"
            }
        }
    }
}
