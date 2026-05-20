// RoutinesView.swift
// Routine management: lists all workout splits, shows the active split banner,
// and provides AI suggestions toggle. Navigates to SplitDetailView per split.
// Sub-components: ActiveSplitCard, SplitRow, SplitDetailView, AIHintBanner.

import SwiftUI

// MARK: - Routines View (entry point from Account tab)

struct RoutinesView: View {
    @EnvironmentObject var routineVM: RoutineViewModel
    @State private var showCreateSplit = false
    @State private var editingSplit: WorkoutSplit?

    var body: some View {
        List {
            // Active split banner
            if let active = routineVM.activeSplit {
                Section {
                    ActiveSplitCard(split: active)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            // AI toggle
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(.purple)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Suggestions")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                        Text("Smart hints on sets, reps & volume")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    Spacer()
                    if routineVM.isFetchingAI {
                        ProgressView().tint(.purple).scaleEffect(0.8)
                    } else {
                        Toggle("", isOn: .init(
                            get: { routineVM.aiEnabled },
                            set: { _ in routineVM.toggleAI() }
                        ))
                        .labelsHidden()
                        .tint(.purple)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("AI Features")
            }
            .listRowBackground(Color.white.opacity(0.05))

            // All splits
            Section {
                if routineVM.splits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(Color.white.opacity(0.15))
                        Text("No routines yet")
                            .foregroundColor(Color.white.opacity(0.4))
                        Text("Tap + to build your first split")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.25))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(routineVM.splits) { split in
                        NavigationLink {
                            SplitDetailView(split: split)
                                .environmentObject(routineVM)
                        } label: {
                            SplitRow(split: split)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        .listRowSeparatorTint(Color.white.opacity(0.07))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                if let idx = routineVM.splits.firstIndex(where: { $0.id == split.id }) {
                                    routineVM.deleteSplit(at: IndexSet(integer: idx))
                                }
                            } label: { Label("Delete", systemImage: "trash") }

                            Button {
                                editingSplit = split
                            } label: { Label("Edit", systemImage: "pencil") }
                                .tint(.orange)
                        }
                        .swipeActions(edge: .leading) {
                            if !split.isActive {
                                Button {
                                    routineVM.setActive(split)
                                } label: { Label("Set Active", systemImage: "checkmark.circle") }
                                    .tint(.green)
                            }
                        }
                    }
                    .onDelete { routineVM.deleteSplit(at: $0) }
                }
            } header: {
                Text("My Routines")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateSplit = true }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showCreateSplit) {
            SplitEditorView(mode: .create)
                .environmentObject(routineVM)
        }
        .sheet(item: $editingSplit) { split in
            SplitEditorView(mode: .edit(split))
                .environmentObject(routineVM)
        }
    }
}

// MARK: - Active Split Card

struct ActiveSplitCard: View {
    let split: WorkoutSplit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Active Routine", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                Spacer()
                Text(split.frequency)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.45))
            }
            Text(split.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            if !split.description.isEmpty {
                Text(split.description)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.4))
            }
            // Day pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(split.days.sorted { $0.order < $1.order }) { day in
                        Text(day.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(20)
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.12), Color.orange.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

// MARK: - Split Row

struct SplitRow: View {
    let split: WorkoutSplit

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(split.isActive ? Color.orange.opacity(0.15) : Color.white.opacity(0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: split.isActive ? "checkmark.circle.fill" : "rectangle.stack")
                    .font(.system(size: 18))
                    .foregroundColor(split.isActive ? .orange : Color.white.opacity(0.4))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(split.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if split.isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                Text("\(split.frequency)  ·  \(split.totalExercises) exercises")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Split Detail View

struct SplitDetailView: View {
    @EnvironmentObject var routineVM: RoutineViewModel
    let split: WorkoutSplit
    @State private var showEditor = false

    var currentSplit: WorkoutSplit {
        routineVM.splits.first { $0.id == split.id } ?? split
    }

    var body: some View {
        List {
            // Info header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if !currentSplit.description.isEmpty {
                        Text(currentSplit.description)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    HStack(spacing: 16) {
                        Label(currentSplit.frequency, systemImage: "calendar")
                        Label("\(currentSplit.totalExercises) exercises", systemImage: "dumbbell.fill")
                    }
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.white.opacity(0.04))

            // Days
            ForEach(currentSplit.days.sorted { $0.order < $1.order }) { day in
                Section(header: Text(day.name).foregroundColor(.orange)) {
                    ForEach(day.exercises.sorted { $0.order < $1.order }) { ex in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(ex.exerciseName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(ex.summaryText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.45))
                            }
                            // AI hint — non-blocking, optional
                            if routineVM.aiEnabled, let hint = ex.aiHint {
                                AIHintBanner(text: hint)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                .listRowSeparatorTint(Color.white.opacity(0.07))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(currentSplit.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showEditor = true }) {
                        Label("Edit Split", systemImage: "pencil")
                    }
                    if !currentSplit.isActive {
                        Button(action: { routineVM.setActive(currentSplit) }) {
                            Label("Set as Active", systemImage: "checkmark.circle")
                        }
                    }
                    if routineVM.aiEnabled {
                        Button(action: {
                            Task { await routineVM.refreshAISuggestions(for: currentSplit) }
                        }) {
                            Label("Refresh AI Hints", systemImage: "sparkles")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            SplitEditorView(mode: .edit(currentSplit))
                .environmentObject(routineVM)
        }
    }
}

// MARK: - AI Hint Banner

struct AIHintBanner: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { expanded.toggle() } }) {
            HStack(alignment: expanded ? .top : .center, spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(.purple)
                Text(expanded ? text : (text.count > 50 ? String(text.prefix(50)) + "…" : text))
                    .font(.system(size: 12))
                    .foregroundColor(Color.purple.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .lineLimit(expanded ? nil : 1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.purple.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
