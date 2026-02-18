import SwiftUI

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var handicapText: String = ""
    @State private var selectedColor: PlayerColor = .blue

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Name") {
                    TextField("Full Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Handicap Index") {
                    TextField("e.g. 12.4", text: $handicapText)
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
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let user = appState.currentUser {
                    name = user.name
                    handicapText = user.handicapIndex == 0 ? "" : String(format: "%.1f", user.handicapIndex)
                    selectedColor = user.avatarColor
                }
            }
        }
    }

    private func saveProfile() {
        guard let user = appState.currentUser else { return }
        user.name = name.trimmingCharacters(in: .whitespaces)
        user.handicapIndex = Double(handicapText) ?? 0.0
        user.avatarColor = selectedColor
        appState.updateUserProfile()

        // Also update the user's Player in the current trip if linked
        if let myPlayer = appState.myCurrentPlayer {
            myPlayer.name = user.name
            myPlayer.handicapIndex = user.handicapIndex
            myPlayer.avatarColor = user.avatarColor
            appState.saveContext()
        }
    }
}

#Preview {
    EditProfileView()
        .environment(SampleData.makeAppState())
}
