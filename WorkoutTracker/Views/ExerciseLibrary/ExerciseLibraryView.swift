// ExerciseLibraryView.swift
// Searchable, filterable exercise library driven by ExerciseLibraryViewModel.
// Sub-components: ExerciseRow, FilterChip, ExerciseDetailView, ExerciseFiltersView,
//                 InfoSection, MuscleTagList, FlowLayout, FilterRow.

import SwiftUI

struct ExerciseLibraryView: View {
    @StateObject private var viewModel = ExerciseLibraryViewModel()
    @State private var selectedExercise: Exercise?
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                if viewModel.hasActiveFilters {
                    activeFiltersBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                exerciseList
            }
            .background(Color.appBackground)
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilters = true }) {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(viewModel.hasActiveFilters ? .orange : .white)
                    }
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            .sheet(isPresented: $showFilters) {
                ExerciseFiltersView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.white.opacity(0.4))
            TextField("Search exercises...", text: $viewModel.searchText)
                .foregroundColor(.white)
                .tint(.orange)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }

    // MARK: - Active Filters Bar

    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let cat = viewModel.selectedCategory {
                    FilterChip(label: cat.rawValue, color: .orange) {
                        viewModel.selectedCategory = nil
                    }
                }
                if let muscle = viewModel.selectedMuscle {
                    FilterChip(label: muscle.rawValue, color: .blue) {
                        viewModel.selectedMuscle = nil
                    }
                }
                if let equip = viewModel.selectedEquipment {
                    FilterChip(label: equip.rawValue, color: .purple) {
                        viewModel.selectedEquipment = nil
                    }
                }
                Button("Clear all") {
                    viewModel.clearFilters()
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        List {
            ForEach(viewModel.groupedExercises, id: \.key) { group in
                Section(header:
                    Text(group.key)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.4))
                        .textCase(nil)
                ) {
                    ForEach(group.exercises) { exercise in
                        ExerciseRow(exercise: exercise)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedExercise = exercise }
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                    .listRowSeparatorTint(Color.white.opacity(0.08))
                }
            }

            if viewModel.filteredExercises.isEmpty {
                Section {
                    Text("No exercises found")
                        .foregroundColor(Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Sub-components

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text(exercise.primaryMuscles.map(\.rawValue).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.45))
                    Text("·")
                        .foregroundColor(Color.white.opacity(0.25))
                        .font(.caption)
                    Text(exercise.equipment.rawValue)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.2))
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let label: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(20)
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text(exercise.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    InfoSection(title: "Primary Muscles") {
                        MuscleTagList(muscles: exercise.primaryMuscles, color: .orange)
                    }

                    if !exercise.secondaryMuscles.isEmpty {
                        InfoSection(title: "Secondary Muscles") {
                            MuscleTagList(muscles: exercise.secondaryMuscles, color: Color.white.opacity(0.5))
                        }
                    }

                    InfoSection(title: "Equipment") {
                        Text(exercise.equipment.rawValue)
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.8))
                    }

                    InfoSection(title: "Instructions") {
                        Text(exercise.instructions)
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.7))
                            .lineSpacing(4)
                    }
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.4))
                .textCase(.uppercase)
                .kerning(0.8)
            content
        }
    }
}

struct MuscleTagList: View {
    let muscles: [Exercise.MuscleGroup]
    let color: Color

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(muscles, id: \.self) { muscle in
                Text(muscle.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12))
                    .cornerRadius(20)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct ExerciseFiltersView: View {
    @ObservedObject var viewModel: ExerciseLibraryViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Category") {
                    ForEach(Exercise.ExerciseCategory.allCases, id: \.self) { cat in
                        FilterRow(label: cat.rawValue, isSelected: viewModel.selectedCategory == cat) {
                            viewModel.selectedCategory = viewModel.selectedCategory == cat ? nil : cat
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                Section("Equipment") {
                    ForEach(Exercise.Equipment.allCases, id: \.self) { equip in
                        FilterRow(label: equip.rawValue, isSelected: viewModel.selectedEquipment == equip) {
                            viewModel.selectedEquipment = viewModel.selectedEquipment == equip ? nil : equip
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                Section("Muscle Group") {
                    ForEach(Exercise.MuscleGroup.allCases, id: \.self) { muscle in
                        FilterRow(label: muscle.rawValue, isSelected: viewModel.selectedMuscle == muscle) {
                            viewModel.selectedMuscle = viewModel.selectedMuscle == muscle ? nil : muscle
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") { viewModel.clearFilters() }
                        .foregroundColor(.orange)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

struct FilterRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .foregroundColor(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ExerciseLibraryView()
}
