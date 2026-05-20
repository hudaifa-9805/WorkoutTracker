// AIChatView.swift
// AI Coach chat interface. Renders the message history, a typing indicator,
// and a floating input bar. FloatingAIButton (used in MainTabView) is also defined here.
//
// Note: recentWorkouts is currently hard-coded to 0 in sendMessage — pass
// WorkoutViewModel and compute it once that integration is ready.

import SwiftUI

// MARK: - AI Chat View

struct AIChatView: View {
    @EnvironmentObject var aiChatVM:    AIChatViewModel
    @EnvironmentObject var nutritionVM: NutritionViewModel
    @EnvironmentObject var bodyWeightVM: BodyWeightViewModel
    @Environment(\.dismiss) var dismiss

    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Chat history
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            if aiChatVM.messages.isEmpty {
                                welcomeCard
                                    .padding(.top, 24)
                                    .padding(.horizontal, 16)
                            }
                            ForEach(aiChatVM.messages) { msg in
                                ChatBubble(message: msg).id(msg.id)
                                    .padding(.horizontal, 16)
                            }
                            if aiChatVM.isLoading {
                                TypingIndicator().padding(.horizontal, 16)
                            }
                            Color.clear.frame(height: 80).id("bottom")
                        }
                        .padding(.top, 12)
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: aiChatVM.messages.count) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: aiChatVM.isLoading) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }

                // Input bar
                inputBar
            }
            .background(Color.appBackground)
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundColor(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !aiChatVM.messages.isEmpty {
                        Button(action: { aiChatVM.clearHistory() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Welcome card

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.15)).frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 32)).foregroundColor(.purple)
            }
            VStack(spacing: 6) {
                Text("AI Coach").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text("Ask me about nutrition, training, recovery, or anything fitness-related.")
                    .font(.system(size: 14)).foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            // Quick prompt chips
            VStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button(action: { sendMessage(prompt) }) {
                        Text(prompt)
                            .font(.system(size: 13)).foregroundColor(Color.white.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.white.opacity(0.06)).cornerRadius(10)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
    }

    private let quickPrompts = [
        "How are my calories looking today?",
        "Give me tips for my current goal",
        "How should I track my progress?",
        "What should I eat after a workout?",
    ]

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask your AI coach…", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .tint(.purple)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.07))
                .cornerRadius(20)

            Button(action: { sendMessage(inputText) }) {
                Image(systemName: aiChatVM.isLoading ? "ellipsis" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiChatVM.isLoading
                                ? Color.white.opacity(0.12) : Color.purple)
                    .cornerRadius(20)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiChatVM.isLoading)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            Color.appBackground
                .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
        )
    }

    // MARK: - Send

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        let ctx = aiChatVM.buildContext(
            nutritionVM: nutritionVM,
            bodyWeightVM: bodyWeightVM,
            recentWorkouts: 0
        )
        Task { await aiChatVM.send(message: trimmed, context: ctx) }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: AIMessage
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                ZStack {
                    Circle().fill(Color.purple.opacity(0.2)).frame(width: 30, height: 30)
                    Image(systemName: "sparkles").font(.system(size: 12)).foregroundColor(.purple)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(isUser ? .white : Color.white.opacity(0.9))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(isUser ? Color.orange : Color.white.opacity(0.08))
                    .cornerRadius(isUser ? 18 : 18, antialiased: true)

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10)).foregroundColor(Color.white.opacity(0.25))
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.2)).frame(width: 30, height: 30)
                Image(systemName: "sparkles").font(.system(size: 12)).foregroundColor(.purple)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .offset(y: animating ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.white.opacity(0.08)).cornerRadius(18)
            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
    }
}

// MARK: - Floating AI Button (used in MainTabView)

struct FloatingAIButton: View {
    @Binding var isPresented: Bool
    @State private var pulse = false

    var body: some View {
        Button(action: { isPresented = true }) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.25))
                    .frame(width: 58, height: 58)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                Circle()
                    .fill(LinearGradient(colors: [Color.purple, Color(red: 0.55, green: 0.2, blue: 0.9)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .shadow(color: Color.purple.opacity(0.5), radius: 12, y: 4)
        .onAppear { pulse = true }
    }
}
