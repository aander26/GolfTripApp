import SwiftUI

struct OnboardingCarouselView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "figure.golf",
            title: "Track Every Shot",
            description: "Keep score hole by hole with automatic handicap adjustments. Your scorecard, simplified.",
            accentColor: Theme.primary
        ),
        OnboardingPage(
            icon: "trophy.fill",
            title: "Live Leaderboards",
            description: "See who's leading in real time — overall standings, round-by-round, and Stableford.",
            accentColor: Color(red: 0.961, green: 0.620, blue: 0.043) // amber
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "Team Match Play",
            description: "Set up Ryder Cup-style teams, assign scoring formats per course, and track points across the trip.",
            accentColor: Color(red: 0.545, green: 0.361, blue: 0.965) // violet
        ),
        OnboardingPage(
            icon: "party.popper.fill",
            title: "Side Games & More",
            description: "Skins, Nassau, custom bets, weather forecasts, war room events, and Spotify playlists — all in one app.",
            accentColor: Color(red: 0.976, green: 0.451, blue: 0.086) // orange
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    onComplete()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textSecondary)
                .padding(.trailing, 24)
                .padding(.top, 8)
            }

            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Bottom controls
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Theme.primary : Theme.border)
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }

                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(BoldPrimaryButtonStyle())
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

// MARK: - Page Data

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}

// MARK: - Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon with gradient background circle
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(page.accentColor.opacity(0.06))
                    .frame(width: 200, height: 200)

                Image(systemName: page.icon)
                    .font(.system(size: 70))
                    .foregroundStyle(page.accentColor)
                    .symbolRenderingMode(.hierarchical)
            }

            // Title
            Text(page.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 36)

            // Description
            Text(page.description)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .padding(.top, 12)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingCarouselView {
        print("Onboarding complete")
    }
}
