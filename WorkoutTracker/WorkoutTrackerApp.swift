// WorkoutTrackerApp.swift
// App entry point. Creates every @StateObject ViewModel, injects them as
// EnvironmentObjects, and resolves the user's preferred color scheme.

import SwiftUI

@main
struct WorkoutTrackerApp: App {
    @StateObject private var authViewModel   = AuthViewModel()
    @StateObject private var routineVM       = RoutineViewModel()
    @StateObject private var workoutVM       = WorkoutViewModel()
    @StateObject private var nutritionVM     = NutritionViewModel()
    @StateObject private var bodyWeightVM    = BodyWeightViewModel()
    @StateObject private var aiChatVM        = AIChatViewModel()
    @AppStorage("appearanceMode") var appearanceMode = "dark"

    /// Maps the persisted appearance string to a SwiftUI ColorScheme.
    /// Returns `nil` for "system", which lets iOS decide.
    var preferredScheme: ColorScheme? {
        switch appearanceMode {
        case "light":  return .light
        case "system": return nil
        default:       return .dark
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(routineVM)
                .environmentObject(workoutVM)
                .environmentObject(nutritionVM)
                .environmentObject(bodyWeightVM)
                .environmentObject(aiChatVM)
                .preferredColorScheme(preferredScheme)
                .task { await authViewModel.checkAuthState() }
        }
    }
}

// MARK: - App-wide Color Constants

extension Color {
    /// Primary background used on every screen — near-black with a slight blue tint.
    static let appBackground = Color(red: 0.06, green: 0.06, blue: 0.08)

    /// Trailing stop of the app's main orange gradient (slightly red-shifted).
    static let orangeGradientEnd = Color(red: 1, green: 0.3, blue: 0.1)
}
