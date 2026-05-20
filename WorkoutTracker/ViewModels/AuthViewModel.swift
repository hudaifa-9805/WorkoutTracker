// AuthViewModel.swift
// Manages authentication state and user identity via Supabase Auth.
// Publishes isAuthenticated so the root ContentView can gate access.
//
// AppUser is defined at the bottom of this file — it is tightly coupled to
// auth and small enough that a dedicated file is not warranted.

import Foundation
import SwiftUI
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading       = false
    @Published var errorMessage: String?
    @Published var currentUser: AppUser?

    // Startup auth gate — true from init until checkAuthState() resolves on first launch.
    // ContentView renders a neutral splash while this is true so the login page never
    // flashes before the Keychain/session check completes.
    @Published var isCheckingAuth: Bool = true

    // MARK: - Auth Actions

    /// Signs the user in with email/password credentials.
    /// Sets `errorMessage` on validation failure or network error.
    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        isLoading     = true
        errorMessage  = nil
        do {
            let session = try await SupabaseService.shared.client.auth.signIn(
                email: email, password: password
            )
            currentUser     = AppUser(from: session.user)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Creates a new account with the given credentials and full name.
    /// On success, the session is created immediately if email confirmation is
    /// disabled in Supabase; otherwise prompts the user to confirm their email.
    func signUp(email: String, password: String, fullName: String) async {
        guard !email.isEmpty, !password.isEmpty, !fullName.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        isLoading     = true
        errorMessage  = nil
        do {
            let response = try await SupabaseService.shared.client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            if response.session != nil {
                currentUser     = AppUser(from: response.user)
                isAuthenticated = true
            } else {
                errorMessage = "Check your email to confirm your account, then log in."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Signs the current user out. Fires-and-forgets the Supabase call; the local
    /// state is cleared immediately so the UI reacts without waiting for the network.
    func signOut() {
        Task { try? await SupabaseService.shared.client.auth.signOut() }
        isAuthenticated = false
        currentUser     = nil
    }

    /// Called once on app launch via .task in WorkoutTrackerApp.
    /// Restores an existing Supabase session from the iOS Keychain.
    /// `isCheckingAuth` is cleared in a defer block so ContentView always
    /// transitions out of the splash state — even if the call throws.
    func checkAuthState() async {
        defer { isCheckingAuth = false }
        do {
            let session     = try await SupabaseService.shared.client.auth.session
            currentUser     = AppUser(from: session.user)
            isAuthenticated = true
        } catch {
            // No valid session — user will be routed to the login screen.
            isAuthenticated = false
        }
    }
}

// MARK: - AppUser

/// Lightweight value type representing the authenticated user in the UI layer.
/// Deliberately separate from Supabase's User type to decouple views from the SDK.
struct AppUser: Codable {
    let id: String
    let email: String
    let fullName: String

    /// Convenience initialiser that maps a Supabase `User` to our local type.
    init(from user: Supabase.User) {
        self.id       = user.id.uuidString
        self.email    = user.email ?? ""
        self.fullName = user.userMetadata["full_name"]?.stringValue ?? ""
    }

    init(id: String, email: String, fullName: String) {
        self.id       = id
        self.email    = email
        self.fullName = fullName
    }
}
