// BodyWeightViewModel.swift
// Manages the user's body weight log and exposes aggregated statistics used by
// BodyWeightLogView and the Progress dashboard.

import Foundation

@MainActor
final class BodyWeightViewModel: ObservableObject {
    @Published var entries: [BodyWeightEntry] = []

    // MARK: - Storage Key

    private enum StorageKey {
        static let entries = "bodyweight_entries_v1"
    }

    // MARK: - Init

    init() { load() }

    // MARK: - Computed

    /// All entries sorted newest-first, used for the history list.
    var sorted: [BodyWeightEntry] { entries.sorted { $0.date > $1.date } }

    /// The most recent entry, or nil if no entries exist.
    var latest: BodyWeightEntry? { sorted.first }

    /// Entries from the last 7 days, sorted oldest-first for charting.
    var entries7d: [BodyWeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return entries.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    /// Entries from the last 30 days, sorted oldest-first for charting.
    var entries30d: [BodyWeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        return entries.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    /// Mean weight over the last 7 days, or nil if there are no entries.
    var weeklyAverage: Double? {
        let week = entries7d
        guard !week.isEmpty else { return nil }
        return week.reduce(0) { $0 + $1.weightKg } / Double(week.count)
    }

    /// Net weight change over the last 30 days (positive = gained).
    /// Returns nil if fewer than 2 entries exist in the window.
    var monthlyChange: Double? {
        let month = entries30d
        guard month.count >= 2 else { return nil }
        return month.last!.weightKg - month.first!.weightKg
    }

    // MARK: - CRUD

    /// Prepends an entry to the list and persists.
    func addEntry(_ entry: BodyWeightEntry) {
        entries.insert(entry, at: 0)
        save()
    }

    /// Removes the entry with the matching ID and persists.
    func deleteEntry(_ entry: BodyWeightEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    // MARK: - Persistence

    /// Loads entries from UserDefaults.
    func load() {
        if let data    = UserDefaults.standard.data(forKey: StorageKey.entries),
           let decoded = try? JSONDecoder().decode([BodyWeightEntry].self, from: data) {
            entries = decoded
        }
    }

    /// Encodes and writes all entries to UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: StorageKey.entries)
        }
    }
}
