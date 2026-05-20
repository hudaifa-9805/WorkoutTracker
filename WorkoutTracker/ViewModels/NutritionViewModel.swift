// NutritionViewModel.swift
// Manages the user's meal log and daily macro targets.
// Meal entries and macro targets are persisted separately to UserDefaults so
// that changing the target doesn't require re-serialising the entire history.

import Foundation

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var entries:      [MealEntry]  = []
    @Published var macroTarget:  MacroTarget  = .default

    // MARK: - Storage Keys

    private enum StorageKey {
        static let entries = "nutrition_entries_v1"
        static let target  = "nutrition_target_v1"
    }

    // MARK: - Init

    init() { load() }

    // MARK: - Today's Summary

    /// All meals logged today, sorted chronologically.
    var todayEntries: [MealEntry] {
        entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
    }

    var todayCalories: Double { todayEntries.reduce(0) { $0 + $1.totalCalories } }
    var todayProtein:  Double { todayEntries.reduce(0) { $0 + $1.totalProtein  } }
    var todayCarbs:    Double { todayEntries.reduce(0) { $0 + $1.totalCarbs    } }
    var todayFat:      Double { todayEntries.reduce(0) { $0 + $1.totalFat      } }

    /// Fractional calorie progress toward today's target, clamped 0…1.
    var calorieProgress: Double {
        guard macroTarget.calories > 0 else { return 0 }
        return min(todayCalories / macroTarget.calories, 1)
    }

    /// Fractional protein progress toward today's target, clamped 0…1.
    var proteinProgress: Double {
        guard macroTarget.protein > 0 else { return 0 }
        return min(todayProtein / macroTarget.protein, 1)
    }

    // MARK: - CRUD

    /// Prepends a meal to the list and persists entries.
    func addMeal(_ meal: MealEntry) {
        entries.insert(meal, at: 0)
        save()
    }

    /// Replaces the matching meal in-place and persists entries.
    func updateMeal(_ meal: MealEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == meal.id }) else { return }
        entries[idx] = meal
        save()
    }

    /// Removes all entries with the matching ID and persists.
    func deleteMeal(_ meal: MealEntry) {
        entries.removeAll { $0.id == meal.id }
        save()
    }

    // MARK: - Analytics

    /// Returns (date, totalCalories) pairs for the last `days` days, oldest first.
    /// Days with no entries are included with a value of 0 so charts have a
    /// continuous x-axis.
    ///
    /// - Parameter days: How many days of history to return (e.g. 7 or 30).
    func caloriesPerDay(days: Int) -> [(date: Date, calories: Double)] {
        let cal = Calendar.current
        return (0..<days).compactMap { offset -> (Date, Double)? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            let total = entries
                .filter { cal.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.totalCalories }
            return (date, total)
        }.reversed()
    }

    // MARK: - Persistence

    /// Loads meal entries and macro target from UserDefaults.
    func load() {
        if let data    = UserDefaults.standard.data(forKey: StorageKey.entries),
           let decoded = try? JSONDecoder().decode([MealEntry].self, from: data) {
            entries = decoded
        }
        if let data    = UserDefaults.standard.data(forKey: StorageKey.target),
           let decoded = try? JSONDecoder().decode(MacroTarget.self, from: data) {
            macroTarget = decoded
        }
    }

    /// Persists meal entries. Call after any CRUD mutation on `entries`.
    func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: StorageKey.entries)
        }
    }

    /// Persists the macro target separately from entries.
    /// Must be called explicitly after editing `macroTarget`.
    func saveTarget() {
        if let data = try? JSONEncoder().encode(macroTarget) {
            UserDefaults.standard.set(data, forKey: StorageKey.target)
        }
    }
}
