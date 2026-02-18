import SwiftUI

struct SettlementView: View {
    let trip: Trip?

    private var settlement: SettlementSummary {
        guard let trip = trip else {
            return SettlementSummary(
                playerBalances: [], payments: [],
                totalMoneyInPlay: 0, gameBreakdowns: [], nonMonetaryBets: []
            )
        }
        return SettlementEngine.generateSettlement(trip: trip)
    }

    var body: some View {
        if !settlement.hasData {
            emptyState
        } else {
            List {
                // Net Balances
                if !settlement.playerBalances.isEmpty {
                    Section {
                        ForEach(settlement.playerBalances) { balance in
                            playerBalanceRow(balance)
                        }
                    } header: {
                        Text("Net Balances")
                    } footer: {
                        if settlement.totalMoneyInPlay > 0 {
                            Text("Total in play: $\(String(format: "%.0f", settlement.totalMoneyInPlay))")
                        }
                    }
                }

                // Settle Up — Payment Instructions
                if !settlement.payments.isEmpty {
                    Section {
                        ForEach(settlement.payments) { payment in
                            paymentRow(payment)
                        }
                    } header: {
                        HStack {
                            Text("Settle Up")
                            Spacer()
                            Text("\(settlement.payments.count) payment\(settlement.payments.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } footer: {
                        Text("Minimum payments to clear all debts.")
                    }
                }

                // Non-Monetary Bets
                if !settlement.nonMonetaryBets.isEmpty {
                    Section("Other Bets") {
                        ForEach(settlement.nonMonetaryBets) { bet in
                            nonMonetaryBetRow(bet)
                        }
                    }
                }

                // Breakdown by Game
                if !settlement.gameBreakdowns.isEmpty {
                    Section("Breakdown by Game") {
                        ForEach(settlement.gameBreakdowns) { breakdown in
                            DisclosureGroup {
                                ForEach(breakdown.playerAmounts, id: \.playerId) { entry in
                                    HStack {
                                        playerAvatar(playerId: entry.playerId)
                                        Text(entry.playerName)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(entry.amount >= 0
                                             ? "+$\(String(format: "%.0f", entry.amount))"
                                             : "-$\(String(format: "%.0f", abs(entry.amount)))")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(entry.amount >= 0 ? .green : .red)
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(breakdown.gameName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(breakdown.gameType)
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    if let stakeText = breakdown.stakeText {
                                        Text(stakeText)
                                            .font(.caption)
                                            .foregroundStyle(Theme.primary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row Views

    private func playerBalanceRow(_ balance: PlayerBalance) -> some View {
        HStack(spacing: 12) {
            playerAvatar(playerId: balance.playerId)

            Text(balance.playerName)
                .font(.body)

            Spacer()

            Text(balance.formattedBalance)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(balance.isPositive ? .green : .red)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(balance.playerName), \(balance.formattedBalance)")
    }

    private func paymentRow(_ payment: Payment) -> some View {
        HStack(spacing: 8) {
            playerAvatar(playerId: payment.fromPlayerId)

            VStack(alignment: .leading, spacing: 2) {
                Text(payment.displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()

            Text(payment.formattedAmount)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Theme.primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(payment.displayText)
    }

    private func nonMonetaryBetRow(_ bet: GameBreakdown) -> some View {
        HStack(spacing: 8) {
            if let winnerId = bet.winnerId {
                playerAvatar(playerId: winnerId)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bet.gameName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let winnerName = bet.winnerName, let stakeText = bet.stakeText {
                    Text("\(winnerName) wins: \(stakeText)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "trophy.fill")
                .foregroundStyle(Theme.warning)
                .font(.caption)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "banknote")
                .font(.system(size: 60))
                .foregroundStyle(Theme.primary)

            Text("No Settlements Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Complete some side games and settle bets to see who owes who across the entire trip.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func playerAvatar(playerId: UUID) -> some View {
        let player = trip?.player(withId: playerId)
        let color = player?.avatarColor.color ?? .gray
        let initials = player?.initials ?? "?"

        return Circle()
            .fill(color)
            .frame(width: 30, height: 30)
            .overlay {
                Text(String(initials.prefix(2)))
                    .font(.system(size: 10))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        SettlementView(trip: nil)
    }
}
