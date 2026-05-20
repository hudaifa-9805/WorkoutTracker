// BodyWeightLogView.swift
// Body weight tracking: stat cards, a Swift Charts trend chart with a 7/30-day toggle,
// and a swipeable history list. LogWeightSheet is defined at the bottom of this file.

import SwiftUI
import Charts

// MARK: - Body Weight Log View

struct BodyWeightLogView: View {
    @EnvironmentObject var bodyWeightVM: BodyWeightViewModel
    @AppStorage("weightUnit") var weightUnit = "kg"
    @State private var showLogSheet = false
    @State private var selectedRange: BWRange = .month

    enum BWRange: String, CaseIterable { case week = "7D"; case month = "30D" }

    private var chartEntries: [BodyWeightEntry] {
        selectedRange == .week ? bodyWeightVM.entries7d : bodyWeightVM.entries30d
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                statsRow
                chartCard
                historySection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom) {
            Button(action: { showLogSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Log Weight").font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(LinearGradient(colors: [.orange, Color.orangeGradientEnd],
                                           startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16)
                .shadow(color: .orange.opacity(0.35), radius: 10, y: 4)
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogWeightSheet().environmentObject(bodyWeightVM)
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            BWStatCard(
                title: "Current",
                value: bodyWeightVM.latest.map { $0.displayWeight(unit: weightUnit) } ?? "—",
                icon: "scalemass.fill", color: .orange
            )
            BWStatCard(
                title: "7-Day Avg",
                value: bodyWeightVM.weeklyAverage.map {
                    weightUnit == "lbs"
                        ? String(format: "%.1f lbs", $0 * 2.20462)
                        : String(format: "%.1f kg", $0)
                } ?? "—",
                icon: "chart.bar.fill", color: .blue
            )
            BWStatCard(
                title: "30-Day Δ",
                value: bodyWeightVM.monthlyChange.map {
                    let v = weightUnit == "lbs" ? $0 * 2.20462 : $0
                    return String(format: "%+.1f %@", v, weightUnit)
                } ?? "—",
                icon: "arrow.up.arrow.down", color: .purple
            )
        }
    }

    // MARK: - Chart card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weight Trend")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(BWRange.allCases, id: \.self) { r in
                        Button(action: { withAnimation { selectedRange = r } }) {
                            Text(r.rawValue)
                                .font(.system(size: 12, weight: selectedRange == r ? .semibold : .regular))
                                .foregroundColor(selectedRange == r ? .orange : Color.white.opacity(0.4))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(selectedRange == r ? Color.orange.opacity(0.12) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            if chartEntries.count < 2 {
                VStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28)).foregroundColor(Color.white.opacity(0.15))
                    Text("Log at least 2 entries to see your trend")
                        .font(.caption).foregroundColor(Color.white.opacity(0.3)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).frame(height: 160)
            } else {
                Chart(chartEntries) { entry in
                    let y = weightUnit == "lbs" ? entry.weightLbs : entry.weightKg
                    LineMark(x: .value("Date", entry.date), y: .value("Weight", y))
                        .foregroundStyle(Color.orange).interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", entry.date), y: .value("Weight", y))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.orange.opacity(0.25), .clear],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", entry.date), y: .value("Weight", y))
                        .foregroundStyle(Color.orange).symbolSize(30)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: selectedRange == .week ? .day : .weekOfYear)) { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)

            if bodyWeightVM.sorted.isEmpty {
                EmptyStateCard(icon: "scalemass.fill",
                               title: "No entries yet",
                               subtitle: "Tap 'Log Weight' to record your first measurement")
            } else {
                ForEach(bodyWeightVM.sorted.prefix(20)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.displayWeight(unit: weightUnit))
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            if !entry.notes.isEmpty {
                                Text(entry.notes).font(.caption).foregroundColor(Color.white.opacity(0.4))
                            }
                        }
                        Spacer()
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundColor(Color.white.opacity(0.35))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.white.opacity(0.05)).cornerRadius(12)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { bodyWeightVM.deleteEntry(entry) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting

struct BWStatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(title).font(.caption).foregroundColor(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}

struct LogWeightSheet: View {
    @EnvironmentObject var bodyWeightVM: BodyWeightViewModel
    @Environment(\.dismiss) var dismiss
    @AppStorage("weightUnit") var weightUnit = "kg"

    @State private var weightText = ""
    @State private var notes      = ""
    @State private var date       = Date()

    var body: some View {
        NavigationStack {
            List {
                Section("Weight") {
                    HStack {
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .tint(.orange)
                        Text(weightUnit)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }

                Section("Date & Time") {
                    DatePicker("", selection: $date)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(.orange)
                        .listRowBackground(Color.white.opacity(0.05))
                }

                Section("Notes (optional)") {
                    TextField("e.g. Morning weigh-in", text: $notes)
                        .foregroundColor(.white).tint(.orange)
                        .listRowBackground(Color.white.opacity(0.05))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundColor(weightText.isEmpty ? Color.white.opacity(0.3) : .orange)
                        .disabled(weightText.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let raw = Double(weightText) else { return }
        let kg = weightUnit == "lbs" ? raw / 2.20462 : raw
        bodyWeightVM.addEntry(BodyWeightEntry(date: date, weightKg: kg, notes: notes))
        dismiss()
    }
}
