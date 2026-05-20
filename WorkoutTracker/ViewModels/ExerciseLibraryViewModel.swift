// ExerciseLibraryViewModel.swift
// Drives the Exercise Library screen. Provides filtered and alphabetically
// grouped exercise lists derived from the in-memory sample data, and tracks
// the current search text and filter selections.

import Foundation
import Combine

@MainActor
final class ExerciseLibraryViewModel: ObservableObject {
    @Published var searchText:         String                     = ""
    @Published var selectedCategory:   Exercise.ExerciseCategory? = nil
    @Published var selectedMuscle:     Exercise.MuscleGroup?      = nil
    @Published var selectedEquipment:  Exercise.Equipment?        = nil

    // All available exercises — swap for a Supabase fetch when the library is remote.
    private let allExercises = Exercise.sampleData

    // MARK: - Filtered Results

    /// Exercises matching all active filters and the current search text.
    var filteredExercises: [Exercise] {
        allExercises.filter { exercise in
            let matchesSearch    = searchText.isEmpty
                                   || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory  = selectedCategory  == nil || exercise.category  == selectedCategory
            let matchesMuscle    = selectedMuscle    == nil
                                   || exercise.primaryMuscles.contains(selectedMuscle!)
                                   || exercise.secondaryMuscles.contains(selectedMuscle!)
            let matchesEquipment = selectedEquipment == nil || exercise.equipment == selectedEquipment
            return matchesSearch && matchesCategory && matchesMuscle && matchesEquipment
        }
    }

    /// Filtered exercises grouped by first letter and sorted alphabetically.
    var groupedExercises: [(key: String, exercises: [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) {
            String($0.name.prefix(1)).uppercased()
        }
        return grouped.map { (key: $0.key, exercises: $0.value) }
            .sorted { $0.key < $1.key }
    }

    // MARK: - Filter Management

    /// Whether any filter other than free text is currently active.
    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedMuscle != nil || selectedEquipment != nil
    }

    /// Clears all filters and the search text.
    func clearFilters() {
        selectedCategory  = nil
        selectedMuscle    = nil
        selectedEquipment = nil
        searchText        = ""
    }
}
