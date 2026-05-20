// BodyWeightEntry.swift
// A single body weight measurement. Stores weight in kg (SI unit) and provides
// a conversion helper and a formatted display string for the user's chosen unit.

import Foundation

/// One body weight measurement taken at a specific date and time.
struct BodyWeightEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    /// Weight stored in kilograms regardless of the user's display preference.
    var weightKg: Double
    var notes: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        weightKg: Double,
        notes: String = ""
    ) {
        self.id       = id
        self.date     = date
        self.weightKg = weightKg
        self.notes    = notes
    }

    /// Weight in pounds, derived from the canonical kg value.
    var weightLbs: Double { weightKg * 2.20462 }

    /// Returns a formatted string in the user-chosen unit.
    /// - Parameter unit: Either "kg" or "lbs" (string comparison — fragile if
    ///   extended; consider a WeightUnit enum if additional units are added).
    func displayWeight(unit: String) -> String {
        unit == "lbs"
            ? String(format: "%.1f lbs", weightLbs)
            : String(format: "%.1f kg", weightKg)
    }
}
