// HomeView.swift
// Today dashboard — greeting, quick stats, active workout banner, and recent session history.
// Shared sub-components (StatCard, SectionHeader, etc.) live at the bottom of this file.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var workoutVM: WorkoutViewModel
    @State private var showStartWorkout = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    quickStatsSection
                    todaySection
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Color.appBackground)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showStartWorkout) {
            WorkoutLogView()
                .environmentObject(workoutVM)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                Text(authViewModel.currentUser?.fullName.components(separatedBy: " ").first ?? "Athlete")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            Button(action: { authViewModel.signOut() }) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color.white.opacity(0.3))
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "This Week", value: "3", unit: "workouts", icon: "calendar", color: .orange)
            StatCard(title: "Total Volume", value: "12.4k", unit: "kg", icon: "scalemass.fill", color: .blue)
            StatCard(title: "Streak", value: "7", unit: "days", icon: "flame.fill", color: .red)
        }
    }

    // MARK: - Today's Workout

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Today's Plan")

            if workoutVM.isSessionActive {
                ActiveWorkoutBanner(viewModel: workoutVM)
            } else {
                StartWorkoutCard(action: { showStartWorkout = true })
            }
        }
    }

    // MARK: - Recent Sessions

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent Workouts")

            ForEach(workoutVM.pastSessions.prefix(3)) { session in
                RecentWorkoutRow(session: session)
            }

            if workoutVM.pastSessions.isEmpty {
                EmptyStateCard(
                    icon: "dumbbell.fill",
                    title: "No workouts yet",
                    subtitle: "Start your first workout to see your history here."
                )
            }
        }
    }
}

// MARK: - Sub-components

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(unit)
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
    }
}

struct StartWorkoutCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to train?")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Start an empty workout or choose a template")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                    .padding(12)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(18)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct ActiveWorkoutBanner: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout in progress")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(viewModel.formattedElapsed)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.orange)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color.white.opacity(0.4))
        }
        .padding(18)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.4), lineWidth: 1))
    }
}

struct RecentWorkoutRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.4))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f kg", session.totalVolume))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                Text("\(session.totalSets) sets")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Color.white.opacity(0.2))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
            Text(subtitle)
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(WorkoutViewModel())
}
