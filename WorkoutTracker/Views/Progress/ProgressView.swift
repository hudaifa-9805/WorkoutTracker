// ProgressView.swift
// Progress dashboard with metric/range pickers, Swift Charts visualisations,
// placeholder personal records, and aggregated all-time stats.
// Body weight and nutrition sections are feature-flagged.

import SwiftUI
import Charts

struct ProgressDashboardView: View {
    @EnvironmentObject var workoutVM:    WorkoutViewModel
    @EnvironmentObject var bodyWeightVM: BodyWeightViewModel
    @EnvironmentObject var nutritionVM:  NutritionViewModel
    @AppStorage("bodyweight_tracking_enabled") var bodyweightEnabled  = false
    @AppStorage("nutrition_tracking_enabled")  var nutritionEnabled   = false
    @State private var selectedRange: TimeRange = .month
    @State private var selectedMetric: ProgressMetric = .volume

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    metricPicker
                    rangePicker
                    chartSection
                    personalRecordsSection
                    statsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Color.appBackground)
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var visibleMetrics: [ProgressMetric] {
        var m: [ProgressMetric] = [.volume, .workouts, .sets]
        if bodyweightEnabled { m.append(.bodyWeight) }
        if nutritionEnabled  { m.append(.calories) }
        return m
    }

    // MARK: - Pickers

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(visibleMetrics, id: \.self) { metric in
                    Button(action: { withAnimation { selectedMetric = metric } }) {
                        Text(metric.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selectedMetric == metric ? .black : Color.white.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(selectedMetric == metric ? Color.orange : Color.clear)
                    }
                }
            }
        }
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: { withAnimation { selectedRange = range } }) {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: selectedRange == range ? .semibold : .regular))
                        .foregroundColor(selectedRange == range ? .orange : Color.white.opacity(0.4))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedRange == range ? Color.orange.opacity(0.12) : Color.clear)
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedMetric.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.4))
                Text(chartSummaryValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            if chartData.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(chartData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(selectedMetric.rawValue, point.value)
                        )
                        .foregroundStyle(Color.orange)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value(selectedMetric.rawValue, point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.orange.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: strideCount)) { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(Color.white.opacity(0.15))
            Text("Complete workouts to see your progress")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Personal Records")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(mockPRs) { pr in
                    PRCard(pr: pr)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("All Time")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                BigStatCard(value: "\(workoutVM.pastSessions.count)", label: "Workouts", icon: "dumbbell.fill")
                BigStatCard(value: "0 kg", label: "Total Volume", icon: "scalemass.fill")
                BigStatCard(value: "0h", label: "Training Time", icon: "clock.fill")
            }

            // Body weight summary (feature-flagged)
            if bodyweightEnabled {
                bodyWeightSummaryCard
            }

            // Nutrition summary (feature-flagged)
            if nutritionEnabled {
                nutritionSummaryCard
            }
        }
    }

    private var bodyWeightSummaryCard: some View {
        HStack(spacing: 12) {
            BigStatCard(
                value: bodyWeightVM.latest.map { String(format: "%.1f kg", $0.weightKg) } ?? "—",
                label: "Current Weight", icon: "scalemass.fill"
            )
            BigStatCard(
                value: bodyWeightVM.weeklyAverage.map { String(format: "%.1f kg", $0) } ?? "—",
                label: "7-Day Avg", icon: "chart.bar.fill"
            )
            BigStatCard(
                value: bodyWeightVM.monthlyChange.map { String(format: "%+.1f kg", $0) } ?? "—",
                label: "30-Day Δ", icon: "arrow.up.arrow.down"
            )
        }
    }

    private var nutritionSummaryCard: some View {
        HStack(spacing: 12) {
            BigStatCard(
                value: "\(Int(nutritionVM.todayCalories)) kcal",
                label: "Today", icon: "fork.knife"
            )
            BigStatCard(
                value: "\(Int(nutritionVM.todayProtein))g",
                label: "Protein Today", icon: "flame.fill"
            )
            BigStatCard(
                value: "\(Int(nutritionVM.macroTarget.calories)) kcal",
                label: "Daily Target", icon: "target"
            )
        }
    }

    // MARK: - Helpers

    private var chartData: [ChartPoint] {
        switch selectedMetric {
        case .bodyWeight:
            let entries = selectedRange == .week ? bodyWeightVM.entries7d : bodyWeightVM.entries30d
            return entries.map { ChartPoint(date: $0.date, value: $0.weightKg) }
        case .calories:
            let days = selectedRange == .week ? 7 : selectedRange == .month ? 30 : selectedRange == .threeMonths ? 90 : 365
            return nutritionVM.caloriesPerDay(days: days).map { ChartPoint(date: $0.date, value: $0.calories) }
        default:
            return []
        }
    }

    private var chartSummaryValue: String {
        switch selectedMetric {
        case .volume:     return "0 kg"
        case .workouts:   return "0"
        case .sets:       return "0"
        case .bodyWeight: return bodyWeightVM.latest.map { String(format: "%.1f kg", $0.weightKg) } ?? "—"
        case .calories:   return "\(Int(nutritionVM.todayCalories)) kcal"
        }
    }

    private var strideCount: Int {
        switch selectedRange {
        case .week: return 1
        case .month: return 7
        case .threeMonths: return 14
        case .year: return 30
        }
    }

    // Static placeholder PRs — replace with data derived from pastSessions once PR tracking lands.
    private var mockPRs: [PersonalRecord] {
        let weights: [Double] = [100, 80, 120, 60]
        let reps:    [Int]    = [5, 8, 3, 10]
        return Exercise.sampleData.prefix(4).enumerated().map { i, ex in
            PersonalRecord(id: ex.id, exerciseName: ex.name,
                           weight: weights[i], reps: reps[i], date: .now)
        }
    }

    enum ProgressMetric: String, CaseIterable {
        case volume     = "Volume"
        case workouts   = "Workouts"
        case sets       = "Sets"
        case bodyWeight = "Weight"
        case calories   = "Calories"
    }

    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case year = "1Y"
    }
}

// MARK: - Supporting Types

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct PersonalRecord: Identifiable {
    let id: UUID
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: Date
}

// MARK: - Sub-components

struct PRCard: View {
    let pr: PersonalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pr.exerciseName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
                .lineLimit(1)
            Text(String(format: "%.1f kg", pr.weight))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("× \(pr.reps) reps")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }
}

struct BigStatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.orange)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }
}

#Preview {
    ProgressDashboardView()
        .environmentObject(WorkoutViewModel())
        .environmentObject(BodyWeightViewModel())
        .environmentObject(NutritionViewModel())
}
