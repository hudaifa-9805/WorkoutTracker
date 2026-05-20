// AccountView.swift
// User profile, feature flags, preferences, data export, and sign-out.
// Settings components (SettingsSection, SettingsToggleRow, etc.) and modal sheets
// (EditProfileSheet, UnitsPickerSheet, etc.) are defined at the bottom of this file.

import SwiftUI
import PhotosUI
import UserNotifications

struct AccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var routineVM:    RoutineViewModel
    @EnvironmentObject var aiChatVM:     AIChatViewModel

    // Profile photo
    @State private var profileImage: UIImage? = {
        guard let data = UserDefaults.standard.data(forKey: "profileImageData") else { return nil }
        return UIImage(data: data)
    }()
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    // Preferences (persisted)
    @AppStorage("weightUnit") var weightUnit = "kg"
    @AppStorage("appearanceMode") var appearanceMode = "dark"
    @AppStorage("notificationsEnabled") var notificationsEnabled = false

    // Feature flags
    @AppStorage("ai_chat_enabled")                var aiChatEnabled        = true
    @AppStorage("nutrition_tracking_enabled")     var nutritionEnabled     = false
    @AppStorage("bodyweight_tracking_enabled")    var bodyweightEnabled    = false

    // Sheet toggles
    @State private var showSignOutAlert    = false
    @State private var showEditProfile     = false
    @State private var showUnitsPicker     = false
    @State private var showAppearancePicker = false
    @State private var showHelp            = false
    @State private var showPrivacy         = false
    @State private var showRoutines        = false
    @State private var showAIPrefs         = false
    @State private var exportItem: ExportItem?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    profileHeader
                    trainingSection
                    featuresSection
                    preferencesSection
                    dataSection
                    supportSection
                    signOutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 44)
            }
            .background(Color.appBackground)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(isPresented: $showRoutines) {
                RoutinesView()
                    .environmentObject(routineVM)
            }
            .navigationDestination(isPresented: $showAIPrefs) {
                AIPreferencesView()
                    .environmentObject(aiChatVM)
            }
        }

        // Photo picker
        .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }

        // Sheets
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showUnitsPicker) {
            UnitsPickerSheet(selected: $weightUnit)
        }
        .sheet(isPresented: $showAppearancePicker) {
            AppearancePickerSheet(selected: $appearanceMode)
        }
        .sheet(isPresented: $showHelp) {
            HelpSheet()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacySheet()
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(text: item.text)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) { authViewModel.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let img = profileImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color.orange.opacity(0.15)
                            Text(initials)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))

                Button(action: { showPhotoPicker = true }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
                .offset(x: 2, y: 2)
            }

            // Name & email
            VStack(spacing: 4) {
                Text(authViewModel.currentUser?.fullName ?? "Athlete")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text(authViewModel.currentUser?.email ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.4))
            }

            // Edit button
            Button(action: { showEditProfile = true }) {
                Text("Edit Profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
    }

    // MARK: - Training Section

    private var trainingSection: some View {
        SettingsSection(title: "Training") {
            SettingsNavigationRow(
                icon: "rectangle.stack.fill", iconColor: .orange,
                label: "Routines",
                value: routineVM.activeSplit.map { $0.name }
            ) { showRoutines = true }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        SettingsSection(title: "Features") {
            // AI Chat
            SettingsToggleRow(icon: "sparkles", iconColor: .purple, label: "AI Coach Chat",
                              isOn: $aiChatEnabled) {}
            SettingsDivider()

            // AI Preferences (only if AI enabled)
            if aiChatEnabled {
                SettingsNavigationRow(
                    icon: "slider.horizontal.3", iconColor: .purple,
                    label: "AI Preferences", value: aiChatVM.preferences.fitnessGoal.rawValue
                ) { showAIPrefs = true }
                SettingsDivider()
            }

            // Nutrition tracking
            SettingsToggleRow(icon: "fork.knife", iconColor: .green, label: "Nutrition Tracking",
                              isOn: $nutritionEnabled) {}
            SettingsDivider()

            // Body weight tracking
            SettingsToggleRow(icon: "scalemass.fill", iconColor: .blue, label: "Body Weight Tracking",
                              isOn: $bodyweightEnabled) {}
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        SettingsSection(title: "Preferences") {
            // Notifications
            SettingsToggleRow(
                icon: "bell.fill", iconColor: .orange, label: "Workout Reminders",
                isOn: $notificationsEnabled
            ) {
                handleNotificationToggle()
            }

            SettingsDivider()

            // Units
            SettingsNavigationRow(
                icon: "scalemass.fill", iconColor: .blue,
                label: "Weight Unit", value: weightUnit.uppercased()
            ) { showUnitsPicker = true }

            SettingsDivider()

            // Appearance
            SettingsNavigationRow(
                icon: "moon.fill", iconColor: .purple,
                label: "Appearance", value: appearanceLabel
            ) { showAppearancePicker = true }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        SettingsSection(title: "Data") {
            SettingsNavigationRow(
                icon: "square.and.arrow.up.fill", iconColor: .green,
                label: "Export Workouts", value: nil
            ) { buildExport() }

            SettingsDivider()

            SettingsInfoRow(
                icon: "icloud.fill", iconColor: .cyan,
                label: "Sync Status", value: "Connected"
            )
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        SettingsSection(title: "Support") {
            SettingsNavigationRow(
                icon: "questionmark.circle.fill", iconColor: .yellow,
                label: "Help & FAQ", value: nil
            ) { showHelp = true }

            SettingsDivider()

            SettingsNavigationRow(
                icon: "envelope.fill", iconColor: .orange,
                label: "Contact Us", value: nil
            ) { openContact() }

            SettingsDivider()

            SettingsNavigationRow(
                icon: "doc.text.fill", iconColor: Color.white.opacity(0.4),
                label: "Privacy Policy", value: nil
            ) { showPrivacy = true }
        }
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button(action: { showSignOutAlert = true }) {
            Text("Sign Out")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.red.opacity(0.08))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.18), lineWidth: 1))
        }
    }

    // MARK: - Helpers

    private var initials: String {
        let parts   = (authViewModel.currentUser?.fullName ?? "").split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "A" : letters
    }

    private var appearanceLabel: String {
        switch appearanceMode {
        case "light": return "Light"
        case "system": return "System"
        default: return "Dark"
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let compressed = image.jpegData(compressionQuality: 0.4) {
            UserDefaults.standard.set(compressed, forKey: "profileImageData")
            await MainActor.run { profileImage = UIImage(data: compressed) }
        }
    }

    private func handleNotificationToggle() {
        if notificationsEnabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    notificationsEnabled = granted
                }
            }
        }
    }

    private func buildExport() {
        exportItem = ExportItem(text: "WorkoutTracker Export\n\nNo workouts logged yet.")
    }

    private func openContact() {
        if let url = URL(string: "mailto:support@workouttracker.app") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.35))
                .kerning(0.8)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
        }
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(Color.white.opacity(0.07))
            .padding(.leading, 52)
    }
}

struct SettingsNavigationRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SettingsIcon(name: icon, color: iconColor)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                Spacer()
                if let value {
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.2))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    @Binding var isOn: Bool
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(name: icon, color: iconColor)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.orange)
                .onChange(of: isOn) { _, _ in onChange() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(name: icon, color: iconColor)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

struct SettingsIcon: View {
    let name: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: name)
                .font(.system(size: 14))
                .foregroundColor(color)
        }
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                Section("Display Name") {
                    TextField("Full Name", text: $name)
                        .foregroundColor(.white)
                        .tint(.orange)
                        .listRowBackground(Color.white.opacity(0.05))
                }
                Section("Email") {
                    Text(authViewModel.currentUser?.email ?? "")
                        .foregroundColor(Color.white.opacity(0.4))
                        .listRowBackground(Color.white.opacity(0.05))
                }
                Section {
                    Text("To change your email, use Forgot Password from the login screen.")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.3))
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: update via SupabaseService.shared.client.auth.update(user:)
                        authViewModel.currentUser = AppUser(
                            id: authViewModel.currentUser?.id ?? "",
                            email: authViewModel.currentUser?.email ?? "",
                            fullName: name
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = authViewModel.currentUser?.fullName ?? ""
            }
        }
    }
}

// MARK: - Units Picker Sheet

struct UnitsPickerSheet: View {
    @Binding var selected: String
    @Environment(\.dismiss) var dismiss

    private let options = [("kg", "Kilograms"), ("lbs", "Pounds")]

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.0) { value, label in
                    Button(action: { selected = value; dismiss() }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label)
                                    .foregroundColor(.white)
                                Text(value)
                                    .font(.caption)
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            Spacer()
                            if selected == value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Weight Unit")
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

// MARK: - Appearance Picker Sheet

struct AppearancePickerSheet: View {
    @Binding var selected: String
    @Environment(\.dismiss) var dismiss

    private let options: [(String, String, String)] = [
        ("dark", "Dark", "moon.fill"),
        ("light", "Light", "sun.max.fill"),
        ("system", "System", "circle.lefthalf.filled"),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.0) { value, label, icon in
                    Button(action: { selected = value; dismiss() }) {
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text(label)
                                .foregroundColor(.white)
                            Spacer()
                            if selected == value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Appearance")
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

// MARK: - Help Sheet

struct HelpSheet: View {
    @Environment(\.dismiss) var dismiss

    private let faqs: [(String, String)] = [
        ("What is RIR?", "Reps in Reserve — how many more reps you could have done before failure. RIR 0 = failure, RIR 3 = 3 reps left in the tank."),
        ("How do I log a workout?", "Go to the Log tab and tap Start Workout. Add exercises, fill in your sets with weight, reps, and RIR, then tap the circle to mark each set complete."),
        ("Can I edit past workouts?", "Tap any past workout on the Home screen to review it. Full editing coming in a future update."),
        ("How is volume calculated?", "Total volume = weight × reps, summed across all completed sets in a session."),
        ("What does the Progress chart show?", "It shows your total training volume over the selected time period. More metrics and exercise-specific charts are coming soon."),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(faqs, id: \.0) { question, answer in
                    Section(question) {
                        Text(answer)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.65))
                            .padding(.vertical, 4)
                            .listRowBackground(Color.white.opacity(0.04))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Help & FAQ")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - Privacy Sheet

struct PrivacySheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PrivacyBlock(title: "Data We Collect",
                                 content: "We collect your name, email, and workout data. This is stored securely in Supabase and is never sold or shared with third parties.")
                    PrivacyBlock(title: "Profile Photos",
                                 content: "Profile photos are stored locally on your device only and are never uploaded to our servers.")
                    PrivacyBlock(title: "Your Rights",
                                 content: "You can export or delete your data at any time from the Account screen. Deleting your account removes all data from our servers permanently.")
                    PrivacyBlock(title: "Contact",
                                 content: "Questions about your data? Email us at privacy@workouttracker.app")
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

struct PrivacyBlock: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.55))
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

struct ShareSheet: View {
    let text: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ShareLink(item: text) {
            Label("Share Export", systemImage: "square.and.arrow.up")
        }
    }
}

struct ExportItem: Identifiable {
    let id = UUID()
    let text: String
}

#Preview {
    AccountView()
        .environmentObject(AuthViewModel())
        .environmentObject(RoutineViewModel())
        .environmentObject(AIChatViewModel())
}
