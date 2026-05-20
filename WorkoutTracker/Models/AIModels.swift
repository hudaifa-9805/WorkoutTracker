// AIModels.swift
// Data types shared between the AI chat feature (AIChatViewModel) and the
// AI preferences screen (AIPreferencesView):
//   AIMessage   — a single message in the coach chat thread
//   ChatContext — a snapshot of the user's stats passed to the AI engine
//   AIPreferences — the user's persistent goal / experience / dietary settings

import Foundation

// MARK: - Chat Message

enum AIRole: String, Codable { case user, assistant }

/// A single message in the AI coach chat thread.
struct AIMessage: Identifiable, Codable {
    let id: UUID
    let role: AIRole
    var content: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: AIRole,
        content: String,
        timestamp: Date = .now
    ) {
        self.id        = id
        self.role      = role
        self.content   = content
        self.timestamp = timestamp
    }
}

// MARK: - Chat Context

/// A lightweight snapshot of the user's current stats injected into every AI
/// request so responses stay personalised without requiring a database query.
struct ChatContext {
    var todayCalories: Double   = 0
    var targetCalories: Double  = 2000
    var targetProtein: Double   = 150
    var latestWeightKg: Double? = nil
    var recentWorkouts: Int     = 0
    var fitnessGoal: String     = "Build Muscle"
    var experienceLevel: String = "Intermediate"
    var dietaryStyle: String    = "Standard"
}

// MARK: - AI Preferences

/// Persistent user preferences that shape AI coaching responses.
struct AIPreferences: Codable {
    var fitnessGoal:     FitnessGoal     = .buildMuscle
    var dietaryStyle:    DietaryStyle    = .standard
    var experienceLevel: ExperienceLevel = .intermediate
    var targetCalories:  Double          = 2000
    var targetProteinG:  Double          = 150
    var targetWeightKg:  Double?         = nil

    // MARK: Fitness Goal

    enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
        case buildMuscle      = "Build Muscle"
        case loseWeight       = "Lose Weight"
        case improveStrength  = "Improve Strength"
        case maintainFitness  = "Maintain Fitness"
        case improveEndurance = "Improve Endurance"

        var id: String { rawValue }

        /// SF Symbol representing this goal.
        var icon: String {
            switch self {
            case .buildMuscle:      return "figure.strengthtraining.traditional"
            case .loseWeight:       return "flame.fill"
            case .improveStrength:  return "bolt.fill"
            case .maintainFitness:  return "heart.fill"
            case .improveEndurance: return "figure.run"
            }
        }
    }

    // MARK: Dietary Style

    enum DietaryStyle: String, Codable, CaseIterable, Identifiable {
        case standard    = "Standard"
        case highProtein = "High Protein"
        case vegetarian  = "Vegetarian"
        case vegan       = "Vegan"
        case keto        = "Keto"
        case paleo       = "Paleo"

        var id: String { rawValue }
    }

    // MARK: Experience Level

    enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
        case beginner     = "Beginner"
        case intermediate = "Intermediate"
        case advanced     = "Advanced"

        var id: String { rawValue }
    }
}
