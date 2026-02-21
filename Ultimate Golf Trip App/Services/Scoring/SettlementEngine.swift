import Foundation

// MARK: - Result Types

/// A player's net position across all games and challenges
struct PlayerBalance: Identifiable {
    let playerId: UUID
    let playerName: String
    let netBalance: Double  // positive = net winner, negative = net loser

    var id: UUID { playerId }

    var formattedBalance: String {
        if netBalance >= 0 {
            return "+\(String(format: "%.0f", netBalance)) pts"
        } else {
            return "-\(String(format: "%.0f", abs(netBalance))) pts"
        }
    }

    var isPositive: Bool { netBalance >= 0 }
}

/// A single settlement instruction: "Player A owes Player B X pts"
struct Payment: Identifiable {
    let id = UUID()
    let fromPlayerId: UUID
    let fromName: String
    let toPlayerId: UUID
    let toName: String
    let amount: Double

    var formattedAmount: String {
        "\(String(format: "%.0f", amount)) pts"
    }

    var displayText: String {
        "\(fromName) owes \(toName) \(formattedAmount)"
    }
}

/// Per-game breakdown showing each player's results within that game
struct GameBreakdown: Identifiable {
    let gameId: UUID
    let gameName: String
    let gameType: String  // "Skins", "Nassau", or the challenge name
    let isMonetary: Bool
    let stakeText: String?  // For non-point challenges: "buys dinner"
    let winnerId: UUID?     // For non-point challenges
    let winnerName: String? // For non-point challenges
    let playerAmounts: [(playerId: UUID, playerName: String, amount: Double)]

    var id: UUID { gameId }
}

/// Complete settlement summary for the trip
struct SettlementSummary {
    let playerBalances: [PlayerBalance]
    let payments: [Payment]
    let totalMoneyInPlay: Double
    let gameBreakdowns: [GameBreakdown]
    let nonMonetaryBets: [GameBreakdown]

    var hasData: Bool {
        !gameBreakdowns.isEmpty || !nonMonetaryBets.isEmpty
    }

    var hasMonetaryData: Bool {
        !gameBreakdowns.isEmpty
    }
}

// MARK: - Settlement Engine

struct SettlementEngine {

    // MARK: - Main Entry Point

    /// Generate the complete settlement summary for a trip
    static func generateSettlement(trip: Trip) -> SettlementSummary {
        var aggregatedBalances: [UUID: Double] = [:]
        var gameBreakdowns: [GameBreakdown] = []
        var nonMonetaryBets: [GameBreakdown] = []

        // 1. Process all side games (Skins, Nassau, Snake, etc.)
        for game in trip.sideGames {
            guard game.hasResults else { continue }

            let balances = calculateSideGameBalances(game: game)
            let playerAmounts: [(playerId: UUID, playerName: String, amount: Double)] = balances.compactMap { (playerId, amount) in
                guard let player = trip.player(withId: playerId) else { return nil }
                return (playerId: playerId, playerName: player.name, amount: amount)
            }.sorted { $0.amount > $1.amount }

            if !playerAmounts.isEmpty {
                gameBreakdowns.append(GameBreakdown(
                    gameId: game.id,
                    gameName: game.type.rawValue,
                    gameType: game.type.rawValue,
                    isMonetary: true,
                    stakeText: game.stakesLabel,
                    winnerId: nil,
                    winnerName: nil,
                    playerAmounts: playerAmounts
                ))
            }

            // Merge into aggregated balances
            for (playerId, amount) in balances {
                aggregatedBalances[playerId, default: 0] += amount
            }
        }

        // 2. Process all completed challenges
        for bet in trip.completedSideBets {
            guard let winnerId = bet.winnerId else { continue }

            if bet.isPotBet && bet.potAmount > 0 {
                // Pool challenge: each participant contributes potAmount, winner takes the pool
                let balances = calculatePotBetBalances(bet: bet)
                let playerAmounts: [(playerId: UUID, playerName: String, amount: Double)] = balances.compactMap { (playerId, amount) in
                    guard let player = trip.player(withId: playerId) else { return nil }
                    return (playerId: playerId, playerName: player.name, amount: amount)
                }.sorted { $0.amount > $1.amount }

                if !playerAmounts.isEmpty {
                    gameBreakdowns.append(GameBreakdown(
                        gameId: bet.id,
                        gameName: bet.name,
                        gameType: "Challenge (Pool)",
                        isMonetary: true,
                        stakeText: bet.potDisplayText,
                        winnerId: winnerId,
                        winnerName: trip.player(withId: winnerId)?.name,
                        playerAmounts: playerAmounts
                    ))
                }

                for (playerId, amount) in balances {
                    aggregatedBalances[playerId, default: 0] += amount
                }

                // If the pool challenge also has a free-text commitment (e.g. "Loser buys dinner"),
                // add it to the non-monetary results too
                let stakeIsNonNumeric = parseBetStake(bet.stake) == nil
                    && !bet.stake.isEmpty
                    && bet.stake != "Bragging Rights"
                if stakeIsNonNumeric {
                    nonMonetaryBets.append(GameBreakdown(
                        gameId: UUID(), // unique ID so both entries show
                        gameName: bet.name,
                        gameType: "Challenge",
                        isMonetary: false,
                        stakeText: bet.stake,
                        winnerId: winnerId,
                        winnerName: trip.player(withId: winnerId)?.name,
                        playerAmounts: []
                    ))
                }
            } else if let dollarAmount = parseBetStake(bet.stake), dollarAmount > 0 {
                // Point-based challenge (flat stake)
                let balances = calculateSideBetBalances(bet: bet, dollarAmount: dollarAmount)
                let playerAmounts: [(playerId: UUID, playerName: String, amount: Double)] = balances.compactMap { (playerId, amount) in
                    guard let player = trip.player(withId: playerId) else { return nil }
                    return (playerId: playerId, playerName: player.name, amount: amount)
                }.sorted { $0.amount > $1.amount }

                if !playerAmounts.isEmpty {
                    gameBreakdowns.append(GameBreakdown(
                        gameId: bet.id,
                        gameName: bet.name,
                        gameType: "Challenge",
                        isMonetary: true,
                        stakeText: bet.stake,
                        winnerId: winnerId,
                        winnerName: trip.player(withId: winnerId)?.name,
                        playerAmounts: playerAmounts
                    ))
                }

                for (playerId, amount) in balances {
                    aggregatedBalances[playerId, default: 0] += amount
                }
            } else {
                // Non-point challenge (bragging rights, buys dinner, etc.)
                nonMonetaryBets.append(GameBreakdown(
                    gameId: bet.id,
                    gameName: bet.name,
                    gameType: "Challenge",
                    isMonetary: false,
                    stakeText: bet.stake,
                    winnerId: winnerId,
                    winnerName: trip.player(withId: winnerId)?.name,
                    playerAmounts: []
                ))
            }
        }

        // 3. Build player balances
        let playerBalances = aggregatedBalances.compactMap { (playerId, balance) -> PlayerBalance? in
            guard let player = trip.player(withId: playerId) else { return nil }
            return PlayerBalance(playerId: playerId, playerName: player.name, netBalance: balance)
        }.sorted { $0.netBalance > $1.netBalance }

        // 4. Calculate total points in play
        let totalMoneyInPlay = aggregatedBalances.values.filter { $0 > 0 }.reduce(0, +)

        // 5. Simplify balances into minimum settlements
        let payments = simplifyDebts(balances: aggregatedBalances, trip: trip)

        return SettlementSummary(
            playerBalances: playerBalances,
            payments: payments,
            totalMoneyInPlay: totalMoneyInPlay,
            gameBreakdowns: gameBreakdowns,
            nonMonetaryBets: nonMonetaryBets
        )
    }

    // MARK: - Side Game Balances

    /// Calculate per-player balances for a single side game.
    /// For pot games: winner gets pot minus their buy-in, each loser loses their buy-in.
    /// For regular games: winners gain their result amounts; losers share the cost equally.
    static func calculateSideGameBalances(game: SideGame) -> [UUID: Double] {
        var balances: [UUID: Double] = [:]
        let participants = game.participantIds

        // Initialize all participants at zero
        for pid in participants {
            balances[pid] = 0
        }

        // Pot game: single winner takes the pot
        if game.isPotGame, let winnerId = game.potWinnerId {
            let losers = participants.filter { $0 != winnerId }
            // Each loser loses their buy-in
            for loserId in losers {
                balances[loserId, default: 0] -= game.stakes
            }
            // Winner gains everyone else's buy-in (net = totalPot - their own stake)
            balances[winnerId, default: 0] += game.stakes * Double(losers.count)
            return balances
        }

        // Regular game: per-result distribution
        for result in game.results {
            guard let winnerId = result.winnerId, result.amount > 0 else { continue }

            // Winner gains
            balances[winnerId, default: 0] += result.amount

            // Losers split the cost
            let losers = participants.filter { $0 != winnerId }
            let loserCount = losers.count
            guard loserCount > 0 else { continue }
            let perLoserCost = (result.amount / Double(loserCount) * 100).rounded() / 100
            for loserId in losers {
                balances[loserId, default: 0] -= perLoserCost
            }
        }

        return balances
    }

    // MARK: - Challenge Balances

    /// Calculate per-player balances for a completed challenge.
    /// Each loser transfers the stake amount to the winner.
    static func calculateSideBetBalances(bet: SideBet, dollarAmount: Double) -> [UUID: Double] {
        guard let winnerId = bet.winnerId else { return [:] }

        var balances: [UUID: Double] = [:]
        let losers = bet.participants.filter { $0 != winnerId }

        // Each loser owes the stake amount
        for loserId in losers {
            balances[loserId, default: 0] -= dollarAmount
        }

        // Winner collects from all losers
        balances[winnerId, default: 0] += dollarAmount * Double(losers.count)

        return balances
    }

    // MARK: - Pool Challenge Balances

    /// Calculate per-player balances for a pool-mode challenge.
    /// Each loser loses their buy-in; winner gains everyone else's buy-in.
    static func calculatePotBetBalances(bet: SideBet) -> [UUID: Double] {
        guard let winnerId = bet.winnerId, bet.isPotBet, bet.potAmount > 0 else { return [:] }

        var balances: [UUID: Double] = [:]
        let losers = bet.participants.filter { $0 != winnerId }

        // Each loser loses their buy-in
        for loserId in losers {
            balances[loserId, default: 0] -= bet.potAmount
        }

        // Winner gains everyone else's buy-in (net = totalPot - their own stake)
        balances[winnerId, default: 0] += bet.potAmount * Double(losers.count)

        return balances
    }

    // MARK: - Value Parsing

    /// Parse a numeric value from a free-text stake string.
    /// Returns nil for non-numeric stakes like "Bragging Rights" or "buys dinner".
    static func parseBetStake(_ stake: String) -> Double? {
        let trimmed = stake.trimmingCharacters(in: .whitespaces)

        // Try direct number parse (e.g., "20", "5.50")
        if let value = Double(trimmed), value > 0 {
            return value
        }

        // Try parsing "$X" or "$X.XX" pattern
        let pattern = #"\$\s*(\d+(?:\.\d{1,2})?)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let range = Range(match.range(at: 1), in: trimmed),
           let value = Double(trimmed[range]), value > 0 {
            return value
        }

        return nil
    }

    // MARK: - Debt Simplification

    /// Simplify a set of balances into minimum number of settlements.
    /// Uses greedy algorithm: repeatedly pair the largest creditor with the largest debtor.
    static func simplifyDebts(balances: [UUID: Double], trip: Trip) -> [Payment] {
        // Separate into creditors (positive) and debtors (negative)
        var creditors: [(id: UUID, amount: Double)] = []
        var debtors: [(id: UUID, amount: Double)] = []

        for (playerId, balance) in balances {
            let rounded = (balance * 100).rounded() / 100  // Round to hundredths
            if rounded > 0.01 {
                creditors.append((id: playerId, amount: rounded))
            } else if rounded < -0.01 {
                debtors.append((id: playerId, amount: abs(rounded)))
            }
        }

        // Sort: largest amounts first for optimal pairing
        creditors.sort { $0.amount > $1.amount }
        debtors.sort { $0.amount > $1.amount }

        var payments: [Payment] = []

        while !creditors.isEmpty && !debtors.isEmpty {
            var creditor = creditors.removeFirst()
            var debtor = debtors.removeFirst()

            let paymentAmount = min(creditor.amount, debtor.amount)

            if paymentAmount > 0.01 {
                let fromName = trip.player(withId: debtor.id)?.name ?? "Unknown"
                let toName = trip.player(withId: creditor.id)?.name ?? "Unknown"

                payments.append(Payment(
                    fromPlayerId: debtor.id,
                    fromName: fromName,
                    toPlayerId: creditor.id,
                    toName: toName,
                    amount: (paymentAmount * 100).rounded() / 100
                ))
            }

            // Handle remainder
            creditor.amount -= paymentAmount
            debtor.amount -= paymentAmount

            if creditor.amount > 0.01 {
                creditors.insert(creditor, at: 0)
                creditors.sort { $0.amount > $1.amount }
            }
            if debtor.amount > 0.01 {
                debtors.insert(debtor, at: 0)
                debtors.sort { $0.amount > $1.amount }
            }
        }

        return payments
    }
}
