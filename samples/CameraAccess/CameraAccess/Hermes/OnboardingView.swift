import SwiftUI

// MARK: - Onboarding Flow
// Shown on first launch. Explains what the app does before asking
// the user to connect their glasses.

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "visionpro",
            title: "Welcome to VisionHermes",
            description: "Your AI-powered glasses assistant. See what your Meta Ray-Ban sees and get real-time answers.",
            gradientColors: [.purple, .blue]
        ),
        OnboardingPage(
            icon: "waveform",
            title: "Voice-First AI",
            description: "Talk naturally with Gemini Live or Hermes AI. Get hands-free answers, translation, and task execution.",
            gradientColors: [.blue, .cyan]
        ),
        OnboardingPage(
            icon: "antenna.radiowaves.left.and.right",
            title: "Live Streaming",
            description: "Share your point of view in real-time via WebRTC. Perfect for demos, support, and collaboration.",
            gradientColors: [.cyan, .green]
        ),
        OnboardingPage(
            icon: "eyeglasses",
            title: "Connect Your Glasses",
            description: "Link your Meta Ray-Ban glasses to start streaming video and interacting with AI — all hands-free.",
            gradientColors: [.purple, .pink]
        ),
    ]

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.easeInOut) {
                            hasSeenOnboarding = true
                            showOnboarding = false
                        }
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 14))
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }

                Spacer()

                // TabView pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index], isCurrent: index == currentPage)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.white : Color.white.opacity(0.2))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Action button
                VStack(spacing: 12) {
                    GlassButton(
                        title: currentPage == pages.count - 1 ? "Get Started" : "Next",
                        icon: currentPage == pages.count - 1 ? nil : "arrow.right"
                    ) {
                        withAnimation(.spring()) {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                hasSeenOnboarding = true
                                showOnboarding = false
                            }
                        }
                    }
                    .padding(.horizontal, 32)

                    if currentPage < pages.count - 1 {
                        Button("Get Started") {
                            withAnimation(.spring()) {
                                hasSeenOnboarding = true
                                showOnboarding = false
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let gradientColors: [Color]
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let isCurrent: Bool

    @State private var showContent = false

    var body: some View {
        VStack(spacing: 32) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradientColors.map { $0.opacity(0.2) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: page.icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }

            // Text content
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .onChange(of: isCurrent) {
            if isCurrent {
                withAnimation(.easeOut(duration: 0.5)) {
                    showContent = true
                }
            } else {
                showContent = false
            }
        }
        .onAppear {
            if isCurrent {
                withAnimation(.easeOut(duration: 0.5)) {
                    showContent = true
                }
            }
        }
    }
}
