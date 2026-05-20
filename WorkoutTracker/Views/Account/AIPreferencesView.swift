// AIPreferencesView.swift
// Lets the user configure AI coaching context: fitness goal, experience level,
// dietary style, and numeric nutrition / body weight targets.
// Changes are written back to AIChatViewModel.preferences and persisted to UserDefaults.

import SwiftUI

// MARK: - AI Preferences View

struct AIPreferencesView: View {
    @EnvironmentObject var aiChatVM: AIChatViewModel
    @Environment(\.dismiss) var dismiss

    @State private var prefs: AIPreferences = .init()
    @State private var targetCalText  = ""
    @State private var targetProtText = ""
    @State private var targetWtText   = ""

    var body: some View {
        NavigationStack {
            List {
                // Fitness goal
                Section("Fitness Goal") {
                    ForEach(AIPreferences.FitnessGoal.allCases) { goal in
                        Button(action: { prefs.fitnessGoal = goal }) {
                            HStack(spacing: 14) {
                                Image(systemName: goal.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                Text(goal.rawValue).foregroundColor(.white)
                                Spacer()
                                if prefs.fitnessGoal == goal {
                                    Image(systemName: "checkmark").foregroundColor(.orange).fontWeight(.semibold)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }

                // Experience level
                Section("Experience Level") {
                    ForEach(AIPreferences.ExperienceLevel.allCases) { level in
                        Button(action: { prefs.experienceLevel = level }) {
                            HStack {
                                Text(level.rawValue).foregroundColor(.white)
                                Spacer()
                                if prefs.experienceLevel == level {
                                    Image(systemName: "checkmark").foregroundColor(.orange).fontWeight(.semibold)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }

                // Dietary style
                Section("Dietary Style") {
                    ForEach(AIPreferences.DietaryStyle.allCases) { style in
                        Button(action: { prefs.dietaryStyle = style }) {
                            HStack {
                                Text(style.rawValue).foregroundColor(.white)
                                Spacer()
                                if prefs.dietaryStyle == style {
                                    Image(systemName: "checkmark").foregroundColor(.orange).fontWeight(.semibold)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }

                // Nutrition targets
                Section("Nutrition Targets") {
                    HStack {
                        Text("Daily Calories").foregroundColor(.white)
                        Spacer()
                        TextField("2000", text: $targetCalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.orange).tint(.orange)
                            .frame(width: 80)
                        Text("kcal").foregroundColor(Color.white.opacity(0.4)).font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    HStack {
                        Text("Protein Target").foregroundColor(.white)
                        Spacer()
                        TextField("150", text: $targetProtText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.orange).tint(.orange)
                            .frame(width: 80)
                        Text("g").foregroundColor(Color.white.opacity(0.4)).font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }

                // Body weight target
                Section("Body Weight Goal (optional)") {
                    HStack {
                        Text("Target Weight").foregroundColor(.white)
                        Spacer()
                        TextField("—", text: $targetWtText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.orange).tint(.orange)
                            .frame(width: 80)
                        Text("kg").foregroundColor(Color.white.opacity(0.4)).font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("AI Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold).foregroundColor(.orange)
                }
            }
            .onAppear { populate() }
        }
    }

    private func populate() {
        prefs = aiChatVM.preferences
        targetCalText  = "\(Int(prefs.targetCalories))"
        targetProtText = "\(Int(prefs.targetProteinG))"
        targetWtText   = prefs.targetWeightKg.map { String(format: "%.1f", $0) } ?? ""
    }

    private func save() {
        prefs.targetCalories  = Double(targetCalText)  ?? prefs.targetCalories
        prefs.targetProteinG  = Double(targetProtText) ?? prefs.targetProteinG
        prefs.targetWeightKg  = targetWtText.isEmpty ? nil : Double(targetWtText)
        aiChatVM.preferences  = prefs
        aiChatVM.savePreferences()
        dismiss()
    }
}
