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
                            Text("Total in play: \(String(format: "%.0f", settlement.totalMoneyInPlay)) pts")
                        }
                    }
                }

                // Who Owes What — Settlement Instructions
                if !settlement.payments.isEmpty {
                    Section {
                        ForEach(settlement.payments) { payment in
                            paymentRow(payment)
                        }
                    } header: {
                        HStack {
                            Text("Who Owes What")
                            Spacer()
                            Text("\(settlement.payments.count) payment\(settlement.payments.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } footer: {
                        Text("Minimum settlements to balance everyone out.")
                    }
                }

                // Non-Monetary Bets
                if !settlement.nonMonetaryBets.isEmpty {
                    Section("Other Challenges") {
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
                                // For round-based challenges, show scorecard details
                                if let winnerId = breakdown.winnerId,
                                   breakdown.gameType.contains("Round") || breakdown.gameType.contains("Head-to-Head") {
                                    roundChallengeDetail(breakdown: breakdown, winnerId: winnerId)
                                }

                                ForEach(breakdown.playerAmounts, id: \.playerId) { entry in
                                    HStack {
                                        playerAvatar(playerId: entry.playerId)
                                        Text(entry.playerName)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(entry.amount >= 0
                                             ? "+\(String(format: "%.0f", entry.amount)) pts"
                                             : "-\(String(format: "%.0f", abs(entry.amount))) pts")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(entry.amount >= 0 ? .green : .red)
                                    }
                                }
                            } label: {
                                breakdownLabel(breakdown)
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
                HStack(spacing: 6) {
                    Text(bet.gameName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    // Gross/Net badge for round-based challenge types
                    if bet.gameType.contains("(Net)") {
                        Text("NET")
                            .font(.system(size: 7, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                if let winnerName = bet.winnerName {
                    if let stakeText = bet.stakeText, !stakeText.isEmpty, stakeText != "Bragging Rights" {
                        Text("\(winnerName) wins \(stakeText)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("\(winnerName) wins bragging rights")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if !bet.gameType.isEmpty && bet.gameType != "Challenge" {
                    Text(bet.gameType)
                        .font(.caption2)
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

    // MARK: - Breakdown Helpers

    private func breakdownLabel(_ breakdown: GameBreakdown) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(breakdown.gameName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    // Gross/Net badge for round-based challenges
                    if breakdown.gameType.contains("(Net)") {
                        Text("NET")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    } else if breakdown.gameType.contains("Round") || breakdown.gameType.contains("Head-to-Head") {
                        Text("GROSS")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                Text(breakdown.gameType)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if let winnerName = breakdown.winnerName {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.warning)
                    Text(winnerName.split(separator: " ").first.map(String.init) ?? winnerName)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else if let stakeText = breakdown.stakeText {
                Text(stakeText)
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
            }
        }
    }

    /// Show scorecard score details for round-based challenges
    private func roundChallengeDetail(breakdown: GameBreakdown, winnerId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Find the associated SideBet to get round scorecard data
            if let trip = trip {
                let matchingBet = trip.completedSideBets.first { $0.id == breakdown.gameId }
                if let bet = matchingBet, let round = bet.round {
                    ForEach(bet.participants, id: \.self) { playerId in
                        if let scorecard = round.scorecard(forPlayer: playerId),
                           let player = trip.player(withId: playerId) {
                            HStack(spacing: 8) {
                                playerAvatar(playerId: playerId)
                                Text(player.name)
                                    .font(.caption)
                                if playerId == winnerId {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Theme.warning)
                                }
                                Spacer()
                                if bet.useNetScoring {
                                    Text("\(scorecard.totalNet) net")
                                        .font(.caption.bold())
                                        .foregroundStyle(playerId == winnerId ? .green : Theme.textSecondary)
                                    Text("(\(scorecard.totalGross) gross)")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textSecondary)
                                } else {
                                    Text("\(scorecard.totalGross) gross")
                                        .font(.caption.bold())
                                        .foregroundStyle(playerId == winnerId ? .green : Theme.textSecondary)
                                    if scorecard.totalNet != scorecard.totalGross {
                                        Text("(\(scorecard.totalNet) net)")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    Divider()
                        .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundStyle(Theme.primary)

            Text("No Results Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Complete some side games and challenges to see the trip summary.")
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
