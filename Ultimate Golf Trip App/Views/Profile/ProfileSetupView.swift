import SwiftUI

struct ProfileSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var name: String = ""
    @State private var handicapText: String = ""
    @State private var selectedColor: PlayerColor = .blue

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.primary)

                    Text("Welcome to Golf Trip")
                        .font(.title.bold())
                        .foregroundStyle(Theme.textPrimary)

                    Text("Set up your profile so your buddies know who you are.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)

                Form {
                    Section("Your Name") {
                        TextField("Full Name", text: $name)
                            .textInputAutocapitalization(.words)
                    }

                    Section("Handicap Index") {
                        TextField("e.g. 12.4 (optional)", text: $handicapText)
                            .keyboardType(.decimalPad)
                    }

                    Section("Avatar Color") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(PlayerColor.allCases) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .onTapGesture { selectedColor = color }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        Button {
                            createProfile()
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(Theme.textOnPrimary)
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .listRowBackground(
                            name.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Theme.primary.opacity(0.4)
                                : Theme.primary
                        )
                    }
                }
            }
        }
    }

    private func createProfile() {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            handicapIndex: Double(handicapText) ?? 0.0,
            avatarColor: selectedColor
        )
        appState.saveUserProfile(profile)
    }
}

#Preview {
    ProfileSetupView()
        .environment(SampleData.makeEmptyAppState())
}
