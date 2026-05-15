import SwiftUI

/// Orchestrates the three-step photo import: capture → parse → review.
/// Presented as a sheet from ScorecardView.
struct ScorecardImportFlowView: View {
    @State var viewModel: ScorecardImportViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var applyMessage: String?

    var body: some View {
        NavigationStack {
            content
        }
        .alert(applyMessage ?? "", isPresented: Binding(get: { applyMessage != nil }, set: { if !$0 { applyMessage = nil } })) {
            Button("OK") { dismiss() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .capture:
            ScorecardCaptureView(
                onImage: { image in
                    Task { await viewModel.process(image: image) }
                },
                onCancel: { dismiss() }
            )
        case .parsing:
            parsingView
        case .review:
            ScorecardReviewView(
                viewModel: viewModel,
                onApply: applyImport,
                onRetake: { viewModel.reset() },
                onCancel: { dismiss() }
            )
        case .noHeader:
            noHeaderView
        case .failed(let message):
            failedView(message: message)
        }
    }

    private var parsingView: some View {
        VStack(spacing: 20) {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 2))
                    .padding()
            }
            ProgressView()
                .controlSize(.large)
            Text("Reading scorecard…")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding()
        .navigationTitle("Photo Import")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var noHeaderView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.warning)
            Text("Couldn't detect the scorecard layout")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Make sure the hole-number row (1–9 and 10–18) is fully visible, the card is flat, and there's no glare. Then try again.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            VStack(spacing: 10) {
                Button("Retake Photo") { viewModel.reset() }
                    .buttonStyle(BoldPrimaryButtonStyle())
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 24)
        }
        .padding()
        .navigationTitle("Photo Import")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.error)
            Text("Import failed")
                .font(.title3.weight(.bold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            VStack(spacing: 10) {
                Button("Try Again") { viewModel.reset() }
                    .buttonStyle(BoldPrimaryButtonStyle())
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 24)
        }
        .padding()
        .navigationTitle("Photo Import")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Apply

    private func applyImport() {
        switch viewModel.apply() {
        case .success(let updated):
            if updated == 0 {
                applyMessage = "No scores were applied — the cells you mapped were empty."
            } else {
                dismiss()
            }
        case .noPlayersMapped:
            applyMessage = "Map at least one row to a player before applying."
        case .missingDependencies:
            applyMessage = "Something went wrong — the round or course is no longer available."
        }
    }
}
