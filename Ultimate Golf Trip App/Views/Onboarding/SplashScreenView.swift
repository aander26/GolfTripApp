import SwiftUI

struct SplashScreenView: View {
    let onComplete: () -> Void

    // Animation state
    @State private var iconVisible = false
    @State private var titleVisible = false
    @State private var taglineVisible = false

    var body: some View {
        ZStack {
            // Dark background
            Theme.backgroundDark
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App Icon
                if let uiImage = UIImage(named: "AppIcon") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                        .shadow(color: Theme.primary.opacity(0.4), radius: 20, y: 8)
                        .scaleEffect(iconVisible ? 1.0 : 0.6)
                        .opacity(iconVisible ? 1.0 : 0)
                }

                // App Title
                VStack(spacing: 8) {
                    Text("Ultimate")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Golf Trip")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primary)
                }
                .padding(.top, 28)
                .offset(y: titleVisible ? 0 : 20)
                .opacity(titleVisible ? 1.0 : 0)

                // Tagline
                Text("Your Buddies. Your Rules. Your Trip.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 12)
                    .opacity(taglineVisible ? 1.0 : 0)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Phase 1: Icon springs in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
            iconVisible = true
        }

        // Phase 2: Title slides up
        withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
            titleVisible = true
        }

        // Phase 3: Tagline fades in
        withAnimation(.easeOut(duration: 0.4).delay(1.2)) {
            taglineVisible = true
        }

        // Phase 4: Complete after 2.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onComplete()
        }
    }
}

#Preview {
    SplashScreenView {
        print("Splash complete")
    }
}
