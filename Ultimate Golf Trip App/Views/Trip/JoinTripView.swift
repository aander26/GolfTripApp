import SwiftUI

struct JoinTripView: View {
    @Bindable var viewModel: TripViewModel
    @Binding var isPresented: Bool
    @State private var shareCode: String = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Share Code") {
                    TextField("e.g. ABC123", text: $shareCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.title3.monospaced())
                        .onChange(of: shareCode) { _, newValue in
                            // Limit to 6 characters, uppercase only
                            let filtered = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                            if filtered != newValue {
                                shareCode = filtered
                            }
                        }
                }

                Section {
                    Text("Ask the trip organizer for their 6-character share code. You'll find it on the Trip tab.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Join a Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isJoining {
                        ProgressView()
                    } else {
                        Button("Join") {
                            joinTrip()
                        }
                        .disabled(shareCode.count != 6)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func joinTrip() {
        isJoining = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.joinTrip(shareCode: shareCode)
                await MainActor.run {
                    isJoining = false
                    isPresented = false
                }
            } catch let joinError as JoinTripError {
                await MainActor.run {
                    errorMessage = joinError.localizedDescription
                    isJoining = false
                }
            } catch {
                await MainActor.run {
                    // Show a friendly message instead of raw CloudKit errors
                    errorMessage = "Could not join trip. Please check your internet connection and make sure you're signed into iCloud, then try again."
                    isJoining = false
                }
            }
        }
    }
}

#Preview {
    JoinTripView(viewModel: SampleData.makeTripViewModel(), isPresented: .constant(true))
}
