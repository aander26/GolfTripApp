import SwiftUI

struct EditTripSheet: View {
    @Bindable var viewModel: TripViewModel

    var body: some View {
        NavigationStack {
            Form {
                if let tripName = viewModel.currentTrip?.name {
                    Section {
                        Text("Editing \"\(tripName)\"")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Section("Trip Details") {
                    TextField("Trip Name", text: $viewModel.editTripName)
                        .textInputAutocapitalization(.words)

                    DatePicker("Start Date", selection: $viewModel.editTripStartDate, displayedComponents: .date)

                    DatePicker("End Date", selection: $viewModel.editTripEndDate, in: viewModel.editTripStartDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showingEditTrip = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveTripEdits()
                    }
                    .disabled(viewModel.editTripName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    EditTripSheet(viewModel: SampleData.makeTripViewModel())
}
