import SwiftUI

struct RecapAwardCard: View {
    let award: DailyRecapViewModel.RecapAward

    private var accentColor: Color {
        award.isRoast ? Theme.error : Theme.primary
    }

    private var lightColor: Color {
        award.isRoast ? Theme.error.opacity(0.08) : Theme.primaryLight
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(award.emoji)
                .font(.system(size: 32))

            Text(award.title)
                .font(.caption.bold())
                .foregroundStyle(accentColor)
                .lineLimit(1)

            Text(award.playerName)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Text(award.detail)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 140)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(lightColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 14)
                .fill(accentColor)
                .frame(height: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(award.isRoast ? Theme.error.opacity(0.3) : Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

#Preview {
    HStack(spacing: 12) {
        RecapAwardCard(award: .init(
            emoji: "👑", title: "Low Round King", playerName: "Alex", detail: "72 net (E) — bow down", isRoast: false
        ))
        RecapAwardCard(award: .init(
            emoji: "☃️", title: "Snowman Alert", playerName: "Chris", detail: "8 on hole 14 — we don't talk about this one", isRoast: true
        ))
        RecapAwardCard(award: .init(
            emoji: "🪣", title: "Cellar Dweller", playerName: "Dave", detail: "94 net (+22) — someone had to finish last", isRoast: true
        ))
    }
    .padding()
    .background(Theme.background)
}
