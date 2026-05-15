import SwiftUI

/// Full per-pairing breakdown opened by tapping the live match status banner.
/// For singles match play shows per-hole W/L/H trails; for other modes shows status + counts.
struct LiveMatchDetailSheet: View {
    let state: LiveMatchBannerState
    let totalHoles: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(state.pairings) { pairing in
                        pairingCard(pairing)
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Match Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func pairingCard(_ pairing: PairingSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pairing.leftLabel) vs \(pairing.rightLabel)")
                        .font(.headline)
                    Text(pairing.statusText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor(pairing))
                }
                Spacer()
                if pairing.isComplete {
                    Text("FINAL")
                        .font(.caption2.weight(.heavy))
                        .tracking(0.6)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.success.opacity(0.18))
                        .foregroundStyle(Theme.success)
                        .clipShape(Capsule())
                } else if pairing.isDormie {
                    Text("DORMIE")
                        .font(.caption2.weight(.heavy))
                        .tracking(0.6)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.warning.opacity(0.22))
                        .foregroundStyle(Theme.warning)
                        .clipShape(Capsule())
                }
            }

            // Win-loss-halve counts (singles + traditional match play). Hidden in modes that
            // don't track per-hole wins (nines, best ball detail not yet exposed).
            if pairing.leftWins + pairing.rightWins + pairing.halved > 0 {
                countsRow(pairing)
            }

            // Per-hole strip. Only individual matches currently populate holeResults.
            if !pairing.holeResults.isEmpty {
                Divider()
                perHoleStrip(pairing)
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func countsRow(_ pairing: PairingSummary) -> some View {
        HStack(spacing: 16) {
            countCell(label: "WON", value: pairing.leftWins, accent: pairing.leadingSide == .left)
            countCell(label: "HALVED", value: pairing.halved, accent: false)
            countCell(label: "LOST", value: pairing.rightWins, accent: pairing.leadingSide == .right)
            Spacer()
            countCell(label: "THRU", value: pairing.holesPlayed, accent: false)
        }
    }

    private func countCell(label: String, value: Int, accent: Bool) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(accent ? Theme.primary : Theme.textPrimary)
                .monospacedDigit()
        }
    }

    // MARK: - Per-hole strip

    private func perHoleStrip(_ pairing: PairingSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOLE-BY-HOLE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .tracking(0.5)

            let half = max(1, totalHoles / 2)
            VStack(spacing: 4) {
                holeRow(pairing: pairing, holes: Array(1...half))
                if totalHoles > half {
                    holeRow(pairing: pairing, holes: Array((half + 1)...totalHoles))
                }
            }
        }
    }

    private func holeRow(pairing: PairingSummary, holes: [Int]) -> some View {
        HStack(spacing: 3) {
            ForEach(holes, id: \.self) { hole in
                holeCell(pairing: pairing, hole: hole)
            }
        }
    }

    private func holeCell(pairing: PairingSummary, hole: Int) -> some View {
        let result = pairing.holeResults[hole] ?? .notPlayed
        return VStack(spacing: 0) {
            Text("\(hole)")
                .font(.system(size: 9))
                .foregroundStyle(Theme.textSecondary)
            Text(symbolFor(result))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(colorFor(result))
        }
        .frame(maxWidth: .infinity, minHeight: 30)
        .background(backgroundFor(result))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func symbolFor(_ r: HoleResult) -> String {
        switch r {
        case .win: return "W"
        case .loss: return "L"
        case .halve: return "H"
        case .notPlayed: return "·"
        }
    }

    private func colorFor(_ r: HoleResult) -> Color {
        switch r {
        case .win: return Theme.primary
        case .loss: return Theme.error
        case .halve: return Theme.textSecondary
        case .notPlayed: return Theme.textSecondary.opacity(0.4)
        }
    }

    private func backgroundFor(_ r: HoleResult) -> Color {
        switch r {
        case .win: return Theme.primaryMuted
        case .loss: return Theme.error.opacity(0.10)
        case .halve: return Theme.border.opacity(0.3)
        case .notPlayed: return .clear
        }
    }

    private func statusColor(_ pairing: PairingSummary) -> Color {
        if pairing.isComplete { return Theme.success }
        if pairing.isDormie { return Theme.warning }
        return Theme.textPrimary
    }
}
