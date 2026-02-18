import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showingSplash = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            if showingSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showingSplash = false
                    }
                }
                .transition(.opacity)
            } else if !hasSeenOnboarding && appState.currentUser == nil {
                OnboardingCarouselView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            } else if appState.currentUser == nil {
                ProfileSetupView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showingSplash)
        .animation(.easeInOut(duration: 0.4), value: hasSeenOnboarding)
    }
}

#Preview {
    ContentView()
        .environment(SampleData.makeAppState())
        .modelContainer(SampleData.previewContainer)
}
