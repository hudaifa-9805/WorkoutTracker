// ContentView.swift
// Root auth gate and entry point for the entire view hierarchy.
//
// Startup routing logic (three states, evaluated in order):
//
//   1. isCheckingAuth == true
//      The Keychain / Supabase session check is still in flight.
//      Show a neutral splash so neither the login page nor the home screen
//      renders before we know which one to show.  This is the fix for the
//      login-page flash: the app never defaults to AuthView — it waits.
//
//   2. isAuthenticated == true
//      Session is valid. Route directly to the main tab view.
//      AuthView is not in the hierarchy at all.
//
//   3. isAuthenticated == false  (and check is complete)
//      No valid session. Show the login / sign-up screen.
//
// Auth guard: MainTabView (and every tab inside it) is only reachable via
// branch 2. Navigating to a tab URL or deep-link without a valid session
// is impossible because the entire MainTabView is conditionally excluded
// from the view tree when isAuthenticated is false.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isCheckingAuth {
                // Splash state — shown while the async session check runs on app launch.
                // Resolves in milliseconds (Keychain read) or up to ~1 s on a cold
                // token-refresh network call.  Cleared by the defer in checkAuthState().
                SplashView()
            } else if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        // Fade between splash → destination and between login ↔ main on sign-in/out.
        .animation(.easeInOut(duration: 0.25), value: authViewModel.isCheckingAuth)
        .animation(.easeInOut(duration: 0.25), value: authViewModel.isAuthenticated)
    }
}

// MARK: - Splash View

/// Shown while `checkAuthState()` runs on app launch.
/// Resolves in milliseconds (Keychain read) to at most ~1 s on a cold token-refresh network call.
/// Cleared by the `defer` in `checkAuthState()`, transitioning via `.easeInOut` animation.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 88, height: 88)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                }
                .shadow(color: .orange.opacity(0.4), radius: 20)

                Text("WorkoutTracker")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Main Tab View with floating AI button

struct MainTabView: View {
    @EnvironmentObject var aiChatVM: AIChatViewModel
    @AppStorage("ai_chat_enabled") var aiChatEnabled = true

    @State private var showAIChat = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                HomeView()
                    .tabItem { Label("Today", systemImage: "flame.fill") }

                LogDashboardView()
                    .tabItem { Label("Log", systemImage: "plus.circle.fill") }

                ProgressDashboardView()
                    .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

                AccountView()
                    .tabItem { Label("Account", systemImage: "person.fill") }
            }
            .tint(.orange)

            // Floating AI Coach button
            if aiChatEnabled {
                FloatingAIButton(isPresented: $showAIChat)
                    .padding(.trailing, 20)
                    .padding(.bottom, 90) // sit above tab bar
            }
        }
        .sheet(isPresented: $showAIChat) {
            AIChatView()
                .environmentObject(aiChatVM)
        }
    }
}
