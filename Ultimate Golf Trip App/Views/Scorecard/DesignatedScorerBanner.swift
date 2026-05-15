import SwiftUI

/// Banner shown above the score entry view when a playing group has a designated scorer
/// other than the current user. Surfaces who's scoring and lets the user take over.
struct DesignatedScorerBanner: View {
    /// Display name of the current scorer.
    let scorerName: String
    /// True when the current user has scoring permission (banner shows as info, not lockout).
    let userIsScorer: Bool
    /// Tapped to claim the scorer role.
    let onTakeOver: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: userIsScorer ? "pencil.circle.fill" : "lock.fill")
                .foregroundStyle(userIsScorer ? Theme.primary : Theme.warning)
            VStack(alignment: .leading, spacing: 1) {
                if userIsScorer {
                    Text("You're scoring for this group")
                        .font(.caption.weight(.semibold))
                } else {
                    Text("\(scorerName) is scoring")
                        .font(.caption.weight(.semibold))
                    Text("Tap “Take over” if you need to edit.")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if !userIsScorer {
                Button("Take over", action: onTakeOver)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(userIsScorer ? Theme.primaryMuted : Theme.warning.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(userIsScorer ? Theme.primary.opacity(0.35) : Theme.warning.opacity(0.55), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
