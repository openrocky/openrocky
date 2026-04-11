//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyOnboardingView: View {
    @ObservedObject var providerStore: OpenRockyProviderStore
    @ObservedObject var realtimeProviderStore: OpenRockyRealtimeProviderStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: OnboardingStep = .welcome
    @State private var selectedProvider: OnboardingProvider = .openAI

    // Welcome animations
    @State private var iconVisible = false
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var featuresVisible = false
    @State private var buttonVisible = false
    @State private var apiKey = ""
    @State private var customHost = ""
    @State private var isSubmitting = false

    @State private var floatingOffset: CGFloat = 0

    private enum OnboardingStep: Comparable {
        case welcome
        case providerChoice
        case apiKey
        case done
    }

    private enum OnboardingProvider {
        case apple
        case openAI
    }

    private var appleIntelligenceAvailable: Bool {
        OpenRockyAppleFoundationModelsChatClient.isAvailable
    }

    var body: some View {
        ZStack {
            backgroundGradient

            Group {
                switch step {
                case .welcome:
                    welcomeStep
                case .providerChoice:
                    providerChoiceStep
                case .apiKey:
                    apiKeyStep
                case .done:
                    doneStep
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            OpenRockyPalette.background.ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [OpenRockyPalette.accent.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 300
                    )
                )
                .frame(width: 500, height: 500)
                .offset(y: -100 + floatingOffset * 0.3)
                .blur(radius: 60)
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            // Content group — centered in the space above the button
            Spacer()

            ZStack {
                Circle()
                    .stroke(OpenRockyPalette.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 130, height: 130)
                    .scaleEffect(iconVisible ? 1.2 : 0.8)
                    .opacity(iconVisible ? 0 : 0.8)
                    .animation(.easeOut(duration: 2).repeatForever(autoreverses: false), value: iconVisible)

                appIconView
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: OpenRockyPalette.accent.opacity(0.3), radius: 20, y: 8)
                    .scaleEffect(iconVisible ? 1.0 : 0.5)
                    .opacity(iconVisible ? 1 : 0)
                    .offset(y: floatingOffset)
            }
            .padding(.bottom, 28)

            Text("Welcome to Rocky")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(OpenRockyPalette.text)
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 20)

            Text("Your open-source AI assistant on iOS")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(OpenRockyPalette.muted)
                .padding(.top, 6)
                .opacity(subtitleVisible ? 1 : 0)
                .offset(y: subtitleVisible ? 0 : 15)

            VStack(spacing: 16) {
                featureRow(icon: "bubble.left.and.text.bubble.right.fill", color: OpenRockyPalette.accent, text: "Chat with any AI model")
                featureRow(icon: "waveform", color: OpenRockyPalette.secondary, text: "Realtime voice conversations")
                featureRow(icon: "wrench.and.screwdriver.fill", color: OpenRockyPalette.warning, text: "Tools, skills & memory")
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .opacity(featuresVisible ? 1 : 0)
            .offset(y: featuresVisible ? 0 : 20)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    step = .providerChoice
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OpenRockyPalette.accent)
                        .shadow(color: OpenRockyPalette.accent.opacity(0.4), radius: 12, y: 6)
                )
            }
            .padding(.horizontal, 12)
            .opacity(buttonVisible ? 1 : 0)
            .offset(y: buttonVisible ? 0 : 20)
            .padding(.bottom, 50)
        }
        .padding(.horizontal, 44)
        .frame(maxWidth: 500)
        .onAppear { startWelcomeAnimations() }
    }

    // MARK: - Provider Choice

    private var providerChoiceStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(OpenRockyPalette.accent.opacity(0.15), lineWidth: 1.5)
                        .frame(width: CGFloat(80 + i * 40), height: CGFloat(80 + i * 40))
                }

                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(OpenRockyPalette.accent)
            }

            VStack(spacing: 12) {
                Text("Choose Your Provider")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(OpenRockyPalette.text)

                Text("Pick how Rocky thinks and speaks.\nYou can change this in Settings anytime.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                // OpenAI option — recommended
                providerOptionCard(
                    provider: .openAI,
                    icon: "globe",
                    title: "OpenAI",
                    subtitle: "Recommended. One API key powers chat + voice.",
                    badge: "Recommended",
                    badgeColor: OpenRockyPalette.accent
                )

                // Apple Intelligence option — only when available
                if appleIntelligenceAvailable {
                    providerOptionCard(
                        provider: .apple,
                        icon: "apple.logo",
                        title: "Apple Intelligence",
                        subtitle: "On-device, no API key. Privacy-first.",
                        badge: "Free",
                        badgeColor: OpenRockyPalette.success
                    )
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        if selectedProvider == .apple {
                            submitAppleProvider()
                        } else {
                            step = .apiKey
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                        Text(selectedProvider == .apple ? "Continue with Apple" : "Continue with OpenAI")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(OpenRockyPalette.accent)
                            .shadow(color: OpenRockyPalette.accent.opacity(0.4), radius: 12, y: 6)
                    )
                }

                Button {
                    dismiss()
                } label: {
                    VStack(spacing: 4) {
                        Text("Skip for now")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(OpenRockyPalette.muted)
                        Text("You can set up a provider later in Settings.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(OpenRockyPalette.muted.opacity(0.7))
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 500)
    }

    private func providerOptionCard(
        provider: OnboardingProvider,
        icon: String,
        title: String,
        subtitle: String,
        badge: String,
        badgeColor: Color
    ) -> some View {
        let isSelected = selectedProvider == provider
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedProvider = provider
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? OpenRockyPalette.accent.opacity(0.14) : OpenRockyPalette.card)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? OpenRockyPalette.accent : OpenRockyPalette.muted)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(OpenRockyPalette.text)
                        Text(badge)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(badgeColor)
                            )
                    }
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(OpenRockyPalette.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? OpenRockyPalette.accent : OpenRockyPalette.stroke)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(OpenRockyPalette.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? OpenRockyPalette.accent.opacity(0.6) : OpenRockyPalette.stroke, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - API Key (OpenAI)

    private var apiKeyStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(OpenRockyPalette.accent.opacity(0.15), lineWidth: 1.5)
                        .frame(width: CGFloat(80 + i * 40), height: CGFloat(80 + i * 40))
                }

                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(OpenRockyPalette.accent)
            }

            VStack(spacing: 12) {
                Text("Enter OpenAI API Key")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(OpenRockyPalette.text)

                Text("One key powers both chat and voice.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // API key input
            VStack(spacing: 12) {
                SecureField("sk-...", text: $apiKey)
                    .font(.system(size: 16, design: .monospaced))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(OpenRockyPalette.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(apiKey.isEmpty ? OpenRockyPalette.stroke : OpenRockyPalette.accent.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                TextField("https://api.openai.com (Optional)", text: $customHost)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(OpenRockyPalette.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(customHost.isEmpty ? OpenRockyPalette.stroke : OpenRockyPalette.accent.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                Text("Custom host is optional. Use it if you have a proxy or self-hosted endpoint.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(OpenRockyPalette.muted)
            }
            .padding(.horizontal, 30)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    submitOpenAIKey()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Connect")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(apiKey.trimmingCharacters(in: .whitespaces).isEmpty ? OpenRockyPalette.cardElevated : OpenRockyPalette.accent)
                            .shadow(color: OpenRockyPalette.accent.opacity(apiKey.isEmpty ? 0 : 0.4), radius: 12, y: 6)
                    )
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)

                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        step = .providerChoice
                    }
                } label: {
                    Text("Back")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(OpenRockyPalette.muted)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 500)
    }

    // MARK: - Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(OpenRockyPalette.accent.opacity(0.2), lineWidth: 3)
                    .frame(width: 90, height: 90)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(OpenRockyPalette.success)
                    .symbolEffect(.bounce, value: step)
            }

            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(OpenRockyPalette.text)

                Text(doneSubtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text("Start Chatting")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OpenRockyPalette.accent)
                        .shadow(color: OpenRockyPalette.accent.opacity(0.4), radius: 12, y: 6)
                )
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 500)
    }

    private var doneSubtitle: String {
        switch selectedProvider {
        case .apple:
            "Chat and voice are ready with Apple Intelligence.\nExplore more providers in Settings anytime."
        case .openAI:
            "Chat and voice are ready.\nExplore more providers and settings anytime."
        }
    }

    // MARK: - Submit Helpers

    private func submitAppleProvider() {
        // Set up chat provider (Apple Foundation Models)
        let chatConfig = OpenRockyProviderConfiguration(
            provider: .appleFoundationModels,
            modelID: OpenRockyProviderKind.appleFoundationModels.defaultModel
        )
        providerStore.update(configuration: chatConfig)

        // Set up voice provider (Apple native voice)
        let voiceConfig = OpenRockyRealtimeProviderConfiguration(
            provider: .apple,
            modelID: OpenRockyRealtimeProviderKind.apple.defaultModel
        )
        realtimeProviderStore.update(configuration: voiceConfig)

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            step = .done
        }
    }

    private func submitOpenAIKey() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isSubmitting = true

        let host = customHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatHost: String? = host.isEmpty ? nil : host
        // For voice, convert https:// to wss:// if needed
        let voiceHost: String? = chatHost.map { h in
            h.hasPrefix("https://") ? h.replacingOccurrences(of: "https://", with: "wss://") : h
        }

        // Set up chat provider (OpenAI)
        var chatConfig = OpenRockyProviderConfiguration(
            provider: .openAI,
            modelID: OpenRockyProviderKind.openAI.defaultModel,
            credential: key
        )
        chatConfig.customHost = chatHost
        providerStore.update(configuration: chatConfig)

        // Set up voice provider (OpenAI Realtime) with the same key
        var voiceConfig = OpenRockyRealtimeProviderConfiguration(
            provider: .openAI,
            modelID: OpenRockyRealtimeProviderKind.openAI.defaultModel,
            credential: key
        )
        voiceConfig.customHost = voiceHost
        realtimeProviderStore.update(configuration: voiceConfig)

        isSubmitting = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            step = .done
        }
    }

    // MARK: - Shared Helpers

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(OpenRockyPalette.text)
            Spacer()
        }
    }

    @ViewBuilder
    private var appIconView: some View {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last,
           let uiImage = UIImage(named: name) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(OpenRockyPalette.accent)
                .frame(width: 100, height: 100)
                .background(OpenRockyPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func startWelcomeAnimations() {
        iconVisible = false
        titleVisible = false
        subtitleVisible = false
        featuresVisible = false
        buttonVisible = false
        floatingOffset = 0

        withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
            iconVisible = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            titleVisible = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45)) {
            subtitleVisible = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
            featuresVisible = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8)) {
            buttonVisible = true
        }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(1.0)) {
            floatingOffset = -8
        }
    }
}
