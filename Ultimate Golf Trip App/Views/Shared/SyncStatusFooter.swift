import SwiftUI
import Combine

/// Compact "synced just now / 12s ago / offline" footer shown on live-data surfaces
/// (rounds list, active scorecard, leaderboard) so users know the freshness of what they see.
struct SyncStatusFooter: View {
    let isSyncing: Bool
    let lastSyncCompletedAt: Date?
    let iCloudAvailable: Bool
    let syncFailed: Bool

    /// Re-evaluate the "X seconds ago" text every 5s so the label doesn't go stale.
    @State private var tick: Date = Date()
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
            Text(label)
                .font(.caption2)
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.clear)
        .onReceive(timer) { tick = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isSyncing {
            ProgressView()
                .controlSize(.mini)
        } else if !iCloudAvailable {
            Image(systemName: "icloud.slash")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        } else if syncFailed {
            Image(systemName: "exclamationmark.icloud")
                .font(.caption2)
                .foregroundStyle(Theme.error)
        } else {
            Image(systemName: "checkmark.icloud")
                .font(.caption2)
                .foregroundStyle(Theme.success)
        }
    }

    private var label: String {
        if isSyncing { return "Syncing…" }
        if !iCloudAvailable { return "Offline — local only" }
        if syncFailed { return "Sync failed — pull to retry" }
        guard let when = lastSyncCompletedAt else { return "Not synced yet" }
        return "Synced \(relativeText(from: when, to: tick))"
    }

    private var textColor: Color {
        if syncFailed && iCloudAvailable { return Theme.error }
        return Theme.textSecondary
    }

    private func relativeText(from when: Date, to now: Date) -> String {
        let elapsed = Int(max(0, now.timeIntervalSince(when)))
        if elapsed < 5 { return "just now" }
        if elapsed < 60 { return "\(elapsed)s ago" }
        if elapsed < 3600 { return "\(elapsed / 60)m ago" }
        return "\(elapsed / 3600)h ago"
    }
}
