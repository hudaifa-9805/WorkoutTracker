// AIChatViewModel.swift
// Powers the AI Coach chat experience. Manages the message history, builds
// context snapshots from sibling ViewModels, and routes messages through the
// response engine.
//
// The response engine is currently rule-based (generateReply). Swap its body
// for an Anthropic API call when a live LLM integration is ready.

import Foundation

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages:     [AIMessage]    = []
    @Published var isLoading:    Bool           = false
    @Published var preferences:  AIPreferences  = .init()

    // MARK: - Storage Key

    private enum StorageKey {
        static let preferences = "ai_preferences_v1"
    }

    // MARK: - Init

    init() { loadPreferences() }

    // MARK: - Chat

    /// Sends a user message, appends it to history, and generates an AI reply.
    /// Sets `isLoading` during the async reply so the UI can show a typing indicator.
    ///
    /// - Parameters:
    ///   - message: The user's raw input text.
    ///   - context: A snapshot of the user's current stats injected into the reply.
    func send(message: String, context: ChatContext = .init()) async {
        messages.append(AIMessage(role: .user, content: message))
        isLoading = true
        let reply = await generateReply(to: message, context: context)
        messages.append(AIMessage(role: .assistant, content: reply))
        isLoading = false
    }

    /// Erases all chat history.
    func clearHistory() { messages = [] }

    // MARK: - Context Builder

    /// Assembles a ChatContext from sibling ViewModels so AIChatView doesn't
    /// need direct access to every ViewModel.
    ///
    /// - Parameters:
    ///   - nutritionVM: Source for today's calories and macro targets.
    ///   - bodyWeightVM: Source for the latest logged body weight.
    ///   - recentWorkouts: Count of workouts in the last 7 days — callers should
    ///     derive this from WorkoutViewModel.pastSessions.
    ///     TODO: Pass WorkoutViewModel here and compute the count internally.
    func buildContext(
        nutritionVM: NutritionViewModel,
        bodyWeightVM: BodyWeightViewModel,
        recentWorkouts: Int
    ) -> ChatContext {
        ChatContext(
            todayCalories:   nutritionVM.todayCalories,
            targetCalories:  nutritionVM.macroTarget.calories,
            targetProtein:   nutritionVM.macroTarget.protein,
            latestWeightKg:  bodyWeightVM.latest?.weightKg,
            recentWorkouts:  recentWorkouts,
            fitnessGoal:     preferences.fitnessGoal.rawValue,
            experienceLevel: preferences.experienceLevel.rawValue,
            dietaryStyle:    preferences.dietaryStyle.rawValue
        )
    }

    // MARK: - Preferences Persistence

    /// Encodes and writes AI preferences to UserDefaults.
    func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: StorageKey.preferences)
        }
    }

    private func loadPreferences() {
        if let data    = UserDefaults.standard.data(forKey: StorageKey.preferences),
           let decoded = try? JSONDecoder().decode(AIPreferences.self, from: data) {
            preferences = decoded
        }
    }

    // MARK: - Rule-based Response Engine (replace with LLM call)

    /// Generates a personalised text reply based on keyword matching.
    /// Simulates ~900 ms network latency. Swap for an Anthropic API call.
    ///
    /// - Parameters:
    ///   - message: The raw user message.
    ///   - context: Snapshot of the user's current stats.
    /// - Returns: A reply string to append to the chat thread.
    private func generateReply(to message: String, context: ChatContext) async -> String {
        try? await Task.sleep(for: .milliseconds(900))
        let lower = message.lowercased()
        let goal  = context.fitnessGoal
        let level = context.experienceLevel

        if lower.contains("calorie") || lower.contains("eat") || lower.contains("food")
           || lower.contains("diet") || lower.contains("nutrition") {
            let remaining = max(0, context.targetCalories - context.todayCalories)
            if context.todayCalories > 0 {
                return "You've logged \(Int(context.todayCalories)) kcal today with \(Int(remaining)) remaining toward your \(Int(context.targetCalories)) kcal target. For \(goal.lowercased()), prioritise getting \(Int(context.targetProtein))g protein before filling carbs and fats."
            }
            return "I don't see any meals logged today yet. Consistent tracking is the #1 driver of nutrition success — even rough estimates beat nothing. Aim for \(Int(context.targetCalories)) kcal and \(Int(context.targetProtein))g protein for your \(goal.lowercased()) goal."
        }

        if lower.contains("weight") || lower.contains("scale") || lower.contains("bodyweight") {
            if let bw = context.latestWeightKg {
                return "Your most recent logged weight is \(String(format: "%.1f", bw)) kg. For reliable trends, weigh yourself first thing in the morning after using the bathroom. A 7-day rolling average smooths out daily fluctuations."
            }
            return "You haven't logged a body weight yet. Start tracking now — even a single reading gives you a baseline to measure \(goal.lowercased()) progress against."
        }

        if lower.contains("workout") || lower.contains("train") || lower.contains("exercise")
           || lower.contains("program") {
            if context.recentWorkouts > 0 {
                return "Nice — \(context.recentWorkouts) workout\(context.recentWorkouts == 1 ? "" : "s") logged recently. As a \(level.lowercased()) trainee aiming to \(goal.lowercased()), focus on progressive overload: add a small amount of weight or one extra rep each session."
            }
            return "No workouts logged recently. For \(goal.lowercased()), consistency beats intensity — even two sessions a week beats zero. Start your active split from the Log tab."
        }

        if lower.contains("sleep") || lower.contains("recover") || lower.contains("rest") {
            return "Recovery is where adaptation happens. Aim for 7–9 hours of sleep; muscle protein synthesis peaks during deep sleep. Keep rest days active with walking or light mobility work rather than full rest."
        }

        if lower.contains("creatine") || lower.contains("supplement") || lower.contains("protein powder") {
            return "Creatine monohydrate (3–5 g/day) and whey protein are the two supplements with the strongest evidence base. Everything else is secondary — nail your total protein intake (\(Int(context.targetProtein))g) and training first."
        }

        if lower.contains("plateau") || lower.contains("stuck") || lower.contains("progress") {
            return "Plateaus usually signal one of three things: insufficient progressive overload, under-eating protein, or accumulated fatigue. Try a 1-week deload, then return with fresh PRs. Also check your 30-day weight trend in the Progress tab."
        }

        return "Happy to help with your \(goal.lowercased()) journey! Ask me anything about nutrition, training programming, recovery, or supplement strategy."
    }
}
