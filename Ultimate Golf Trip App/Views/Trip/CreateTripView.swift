import SwiftUI

struct CreateTripView: View {
    @Bindable var viewModel: TripViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip Name", text: $viewModel.tripName)
                        .textInputAutocapitalization(.words)

                    DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)

                    DatePicker("End Date", selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: .date)
                }

                Section {
                    Text("You can add players, courses, and teams after creating the trip.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Golf Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createTrip()
                        isPresented = false
                    }
                    .disabled(viewModel.tripName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }
}

#Preview {
    CreateTripView(viewModel: SampleData.makeTripViewModel(), isPresented: .constant(true))
}
