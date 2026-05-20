// LogDashboardView.swift
// Central tracking hub embedded in the main tab bar under the "Log" tab.
// Hosts a segmented tab picker that conditionally shows Nutrition and Body Weight
// tabs when the corresponding feature flags are enabled in Account settings.
// Workout UI components are imported from WorkoutLogView.swift (same module).

import SwiftUI

// MARK: - LogTab

/// The segments available inside the Log dashboard.
enum LogTab: String, CaseIterable {
    case workout   = "Workout"
    case nutrition = "Nutrition"
    case body      = "Body"

    /// SF Symbol name for the tab's icon in the segment picker.
    var icon: String {
        switch self {
        case .workout:   return "dumbbell.fill"
        case .nutrition: return "fork.knife"
        case .body:      return "scalemass.fill"
        }
    }
}

// MARK: - LogDashboardView

struct LogDashboardView: View {
    @EnvironmentObject var routineVM:    RoutineViewModel
    @EnvironmentObject var nutritionVM:  NutritionViewModel
    @EnvironmentObject var bodyWeightVM: BodyWeightViewModel
    @EnvironmentObject var workoutVM:    WorkoutViewModel

    @AppStorage("nutrition_tracking_enabled")  var nutritionEnabled  = false
    @AppStorage("bodyweight_tracking_enabled") var bodyweightEnabled = false

    @State private var selectedTab:      LogTab = .workout
    @State private var showExercisePicker = false
    @State private var showDiscardAlert   = false

    /// Tabs visible in the picker — workout is always shown; others are gated by feature flags.
    private var visibleTabs: [LogTab] {
        var tabs: [LogTab] = [.workout]
        if nutritionEnabled  { tabs.append(.nutrition) }
        if bodyweightEnabled { tabs.append(.body) }
        return tabs
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment picker — only shown when extra tabs are unlocked
                if visibleTabs.count > 1 {
                    logTabPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }

                ZStack {
                    workoutContent.opacity(selectedTab == .workout ? 1 : 0)
                    if nutritionEnabled  { NutritionLogView().opacity(selectedTab == .nutrition ? 1 : 0) }
                    if bodyweightEnabled { BodyWeightLogView().opacity(selectedTab == .body ? 1 : 0) }
                }
            }
            .background(Color.appBackground)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { workoutToolbar }
            .alert("Discard Workout?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { workoutVM.discardWorkout() }
                Button("Continue", role: .cancel) {}
            } message: {
                Text("Your progress will be lost.")
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { exercise in workoutVM.addExercise(exercise) }
            }
        }
    }

    // MARK: - Tab Picker

    private var logTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.25)) { selectedTab = tab }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == tab ? .black : Color.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(selectedTab == tab ? Color.orange : Color.clear)
                }
            }
        }
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }

    // MARK: - Nav / Toolbar

    /// Navigation title that updates when the active tab or session state changes.
    private var navTitle: String {
        switch selectedTab {
        case .workout:   return workoutVM.isSessionActive
                             ? (workoutVM.activeSession?.name ?? "Workout")
                             : "Log"
        case .nutrition: return "Nutrition"
        case .body:      return "Body Weight"
        }
    }

    /// Discard / Finish buttons — only visible on the workout tab during an active session.
    @ToolbarContentBuilder
    private var workoutToolbar: some ToolbarContent {
        if selectedTab == .workout && workoutVM.isSessionActive {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Discard") { showDiscardAlert = true }
                    .foregroundColor(.red)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Finish") { workoutVM.finishWorkout() }
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Workout Content

    private var workoutContent: some View {
        Group {
            if workoutVM.isSessionActive {
                ActiveWorkoutScrollContent(
                    viewModel: workoutVM,
                    showExercisePicker: $showExercisePicker
                )
            } else {
                startPromptContent
            }
        }
    }

    private var startPromptContent: some View {
        Group {
            if let active = routineVM.activeSplit {
                SplitDayPickerView(split: active, viewModel: workoutVM)
            } else {
                EmptyWorkoutStartView(
                    viewModel: workoutVM,
                    subtitle: "Start a session or pick a routine day below"
                )
            }
        }
    }
}
