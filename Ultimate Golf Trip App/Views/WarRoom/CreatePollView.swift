import SwiftUI

struct CreatePollView: View {
    @Bindable var viewModel: WarRoomViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("What should we do?", text: $viewModel.newPollQuestion)
                }

                Section("Options") {
                    ForEach(viewModel.newPollOptions.indices, id: \.self) { index in
                        HStack {
                            Image(systemName: "\(index + 1).circle.fill")
                                .foregroundStyle(Theme.primary)
                            TextField("Option \(index + 1)", text: $viewModel.newPollOptions[index])
                            if viewModel.newPollOptions.count > 2 {
                                Button {
                                    viewModel.newPollOptions.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(Theme.error)
                                }
                            }
                        }
                    }

                    if viewModel.newPollOptions.count < 6 {
                        Button {
                            viewModel.newPollOptions.append("")
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Theme.primary)
                                Text("Add Option")
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                    }
                }

                Section("Settings") {
                    Toggle("Allow Multiple Votes", isOn: $viewModel.newPollAllowMultiple)
                        .tint(Theme.primary)
                }
            }
            .navigationTitle("Create Poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetPollForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createPoll()
                        dismiss()
                    }
                    .disabled(!canCreatePoll)
                    .fontWeight(.semibold)
                    .foregroundStyle(canCreatePoll ? Theme.primary : Theme.textSecondary)
                }
            }
        }
    }

    private var canCreatePoll: Bool {
        !viewModel.newPollQuestion.isEmpty &&
        viewModel.newPollOptions.filter({ !$0.isEmpty }).count >= 2
    }
}

#Preview {
    CreatePollView(viewModel: SampleData.makeWarRoomViewModel())
        .environment(SampleData.makeAppState())
}
