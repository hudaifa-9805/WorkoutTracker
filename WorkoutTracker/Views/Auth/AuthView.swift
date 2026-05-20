// AuthView.swift
// Login and sign-up screen. Animates between modes and delegates to AuthViewModel.
// Sub-components AuthTextField and AuthPasswordField are defined at the bottom of this file.

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var showPassword = false
    @FocusState private var focusedField: AuthField?

    enum AuthField { case name, email, password }

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)
                    logoSection
                    Spacer().frame(height: 48)
                    formSection
                    Spacer().frame(height: 24)
                    primaryButton
                    Spacer().frame(height: 20)
                    toggleModeButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }

            if authViewModel.isLoading {
                loadingOverlay
            }
        }
        .ignoresSafeArea()
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            GeometryReader { geo in
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 350, height: 350)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.5, y: -60)
            }
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                Image(systemName: "flame.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: .orange.opacity(0.4), radius: 20)

            Text("WorkoutTracker")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(isLoginMode ? "Welcome back, keep grinding." : "Build your best self.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.white.opacity(0.5))
                .animation(.easeInOut, value: isLoginMode)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 14) {
            if !isLoginMode {
                AuthTextField(
                    icon: "person.fill",
                    placeholder: "Full Name",
                    text: $fullName
                )
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            AuthPasswordField(
                placeholder: "Password",
                text: $password,
                showPassword: $showPassword
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit { submitAction() }

            if let error = authViewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoginMode)
        .animation(.easeInOut, value: authViewModel.errorMessage)
    }

    // MARK: - Buttons

    private var primaryButton: some View {
        Button(action: submitAction) {
            HStack {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Text(isLoginMode ? "Log In" : "Create Account")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [.orange, Color.orangeGradientEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(14)
            .shadow(color: .orange.opacity(0.4), radius: 12, y: 6)
        }
        .disabled(authViewModel.isLoading || authViewModel.isAuthenticated)
        .scaleEffect(authViewModel.isLoading ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: authViewModel.isLoading)
    }

    private var toggleModeButton: some View {
        Button(action: toggleMode) {
            HStack(spacing: 4) {
                Text(isLoginMode ? "Don't have an account?" : "Already have an account?")
                    .foregroundColor(Color.white.opacity(0.5))
                Text(isLoginMode ? "Sign Up" : "Log In")
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 14))
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .overlay(
                ProgressView()
                    .tint(.orange)
                    .scaleEffect(1.4)
            )
    }

    // MARK: - Actions

    private func submitAction() {
        guard !authViewModel.isAuthenticated, !authViewModel.isLoading else { return }
        focusedField = nil
        Task {
            if isLoginMode {
                await authViewModel.signIn(email: email, password: password)
            } else {
                await authViewModel.signUp(email: email, password: password, fullName: fullName)
            }
        }
    }

    private func toggleMode() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isLoginMode.toggle()
            authViewModel.errorMessage = nil
        }
    }
}

// MARK: - Reusable Components

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .tint(.orange)
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(text.isEmpty ? 0.08 : 0.2), lineWidth: 1)
        )
    }
}

struct AuthPasswordField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 20)

            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.white)
            .tint(.orange)

            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(text.isEmpty ? 0.08 : 0.2), lineWidth: 1)
        )
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
