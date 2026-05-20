// RoutineViewModel.swift
// Owns the list of WorkoutSplits and the "active split" selection.
// Persists splits to UserDefaults (JSON-encoded) and coordinates AI hint
// fetching via AIRoutineService.

import Foundation
import Combine

@MainActor
final class RoutineViewModel: ObservableObject {
    @Published var splits:       [WorkoutSplit] = []
    @Published var activeSplit:  WorkoutSplit?
    @Published var isFetchingAI: Bool = false

    /// Whether AI routine suggestions are enabled. Mirrored to UserDefaults
    /// so the preference survives app restarts.
    @Published var aiEnabled: Bool {
        didSet { UserDefaults.standard.set(aiEnabled, forKey: StorageKey.aiRoutinesEnabled) }
    }

    // MARK: - Storage Keys

    private enum StorageKey {
        static let splits           = "workout_splits_v1"
        static let aiRoutinesEnabled = "ai_routines_enabled"
    }

    // MARK: - Init

    init() {
        aiEnabled = UserDefaults.standard.bool(forKey: StorageKey.aiRoutinesEnabled)
        load()
    }

    // MARK: - Persistence

    /// Loads splits from UserDefaults. Falls back to sample data on first launch.
    func load() {
        if let data    = UserDefaults.standard.data(forKey: StorageKey.splits),
           let decoded = try? JSONDecoder().decode([WorkoutSplit].self, from: data) {
            splits = decoded
        } else {
            splits = WorkoutSplit.sampleSplits
            save()
        }
        activeSplit = splits.first { $0.isActive }
    }

    /// Encodes and writes all splits to UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(splits) {
            UserDefaults.standard.set(data, forKey: StorageKey.splits)
        }
    }

    // MARK: - CRUD

    /// Appends a new split to the list and persists.
    func addSplit(_ split: WorkoutSplit) {
        splits.append(split)
        save()
    }

    /// Replaces the split with a matching ID and persists.
    func updateSplit(_ split: WorkoutSplit) {
        guard let idx = splits.firstIndex(where: { $0.id == split.id }) else { return }
        splits[idx] = split
        if split.isActive { activeSplit = split }
        save()
    }

    /// Removes splits at the given index set and updates the active split reference.
    func deleteSplit(at offsets: IndexSet) {
        splits.remove(atOffsets: offsets)
        activeSplit = splits.first { $0.isActive }
        save()
    }

    /// Marks the given split as active, deactivates all others, and triggers an AI hint refresh.
    func setActive(_ split: WorkoutSplit) {
        for i in splits.indices { splits[i].isActive = false }
        guard let idx = splits.firstIndex(where: { $0.id == split.id }) else { return }
        splits[idx].isActive = true
        activeSplit          = splits[idx]
        save()

        if aiEnabled {
            Task { await refreshAISuggestions(for: splits[idx]) }
        }
    }

    /// Deactivates all splits, leaving no active programme selected.
    func deactivateAll() {
        for i in splits.indices { splits[i].isActive = false }
        activeSplit = nil
        save()
    }

    // MARK: - AI

    /// Toggles the AI feature flag and immediately fetches hints if turned on.
    func toggleAI() {
        aiEnabled.toggle()
        if aiEnabled, let split = activeSplit {
            Task { await refreshAISuggestions(for: split) }
        }
    }

    /// Fetches AI hints for every exercise in `split` and writes them back.
    /// Safe to call multiple times — duplicate hint writes are idempotent.
    func refreshAISuggestions(for split: WorkoutSplit) async {
        guard aiEnabled else { return }
        isFetchingAI = true
        let hints    = await AIRoutineService.shared.suggest(for: split)
        applyHints(hints, to: split.id)
        isFetchingAI = false
    }

    // MARK: - Private

    /// Writes AI hints back to the in-memory split and persists.
    /// Only writes — never clears an existing hint when no new hint is returned,
    /// so older useful hints survive partial refreshes.
    private func applyHints(_ hints: [UUID: String], to splitId: UUID) {
        guard let splitIdx = splits.firstIndex(where: { $0.id == splitId }) else { return }
        for dayIdx in splits[splitIdx].days.indices {
            for exIdx in splits[splitIdx].days[dayIdx].exercises.indices {
                let exId = splits[splitIdx].days[dayIdx].exercises[exIdx].id
                if let hint = hints[exId] {
                    splits[splitIdx].days[dayIdx].exercises[exIdx].aiHint = hint
                }
            }
        }
        if splits[splitIdx].isActive { activeSplit = splits[splitIdx] }
        save()
    }
}
