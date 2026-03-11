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
                    pollOptionsList
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

    @ViewBuilder
    private var pollOptionsList: some View {
        let count = viewModel.newPollOptions.count
        ForEach(0..<count, id: \.self) { index in
            PollOptionEditRow(
                index: index,
                text: Binding(
                    get: { viewModel.newPollOptions[index] },
                    set: { viewModel.newPollOptions[index] = $0 }
                ),
                canRemove: count > 2,
                onRemove: {
                    let i = index
                    withAnimation {
                        viewModel.newPollOptions.remove(at: i)
                    }
                }
            )
        }

        if count < 6 {
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

    private var canCreatePoll: Bool {
        !viewModel.newPollQuestion.isEmpty &&
        viewModel.newPollOptions.filter({ !$0.isEmpty }).count >= 2
    }
}

private struct PollOptionEditRow: View {
    let index: Int
    @Binding var text: String
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "\(index + 1).circle.fill")
                .foregroundStyle(Theme.primary)
            TextField("Option \(index + 1)", text: $text)
            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Theme.error)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

#Preview {
    CreatePollView(viewModel: SampleData.makeWarRoomViewModel())
        .environment(SampleData.makeAppState())
}
