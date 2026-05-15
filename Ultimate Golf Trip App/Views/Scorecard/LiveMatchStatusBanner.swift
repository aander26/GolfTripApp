import SwiftUI

/// Glanceable live match status, rendered above the player cards in the active scorecard view.
/// Hides itself for non-match formats. Tap to open the detail sheet with per-hole breakdown.
struct LiveMatchStatusBanner: View {
    let state: LiveMatchBannerState
    let totalHoles: Int

    @State private var showingDetail = false

    var body: some View {
        if state.mode == .hidden {
            EmptyView()
        } else {
            Button {
                showingDetail = true
            } label: {
                content
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingDetail) {
                LiveMatchDetailSheet(state: state, totalHoles: totalHoles)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            headlineRow
            if state.mode != .nines, state.pairings.count > 1 {
                pairingsStrip
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundFill)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap for per-hole match details.")
    }

    // MARK: - Headline

    private var headlineRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.primaryLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                if let secondary = state.secondaryLine, !secondary.isEmpty {
                    Text(secondary)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(secondaryColor)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            statusPill
        }
    }

    private var statusPill: some View {
        Group {
            if state.isClosedOut {
                Text("CLOSED")
                    .pillStyle(background: Theme.success.opacity(0.18), text: Theme.success)
            } else if state.isDormie {
                Text("DORMIE")
                    .pillStyle(background: Theme.warning.opacity(0.22), text: Theme.warning)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(8)
                    .background(Theme.cardBackground)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Pairings strip

    private var pairingsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(state.pairings) { pairing in
                    pairingChip(pairing)
                }
            }
        }
    }

    private func pairingChip(_ pairing: PairingSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(pairing.leftLabel) v \(pairing.rightLabel)")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Text(pairing.statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(pairing.isComplete ? Theme.success.opacity(0.5) :
                        pairing.isDormie ? Theme.warning.opacity(0.6) :
                        Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Style helpers

    private var backgroundFill: some ShapeStyle {
        if state.isClosedOut { return Theme.success.opacity(0.10) }
        if state.isDormie { return Theme.warning.opacity(0.12) }
        return Theme.primaryMuted
    }

    private var borderColor: Color {
        if state.isClosedOut { return Theme.success.opacity(0.5) }
        if state.isDormie { return Theme.warning.opacity(0.55) }
        return Theme.primary.opacity(0.35)
    }

    private var secondaryColor: Color {
        if state.isDormie { return Theme.warning }
        if state.isClosedOut { return Theme.success }
        return Theme.textSecondary
    }

    private var accessibilityLabel: String {
        var parts = [state.primaryLine]
        if let secondary = state.secondaryLine, !secondary.isEmpty { parts.append(secondary) }
        if state.isClosedOut { parts.append("Closed out.") }
        else if state.isDormie { parts.append("Dormie.") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Local style modifier

private extension View {
    func pillStyle(background: Color, text: Color) -> some View {
        self.font(.caption2.weight(.heavy))
            .tracking(0.5)
            .foregroundStyle(text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background)
            .clipShape(Capsule())
    }
}
