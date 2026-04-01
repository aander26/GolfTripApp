import SwiftUI

struct PlayerDetailView: View {
    let entry: LeaderboardEntry
    let trip: Trip
    @Environment(AppState.self) private var appState
    @State private var showingEditPlayer = false
    @State private var editName: String = ""
    @State private var editHandicap: String = ""
    @State private var editColor: PlayerColor = .blue

    var body: some View {
        List {
            headerSection
            scoringSummarySection
            roundByRoundSection
            matchRecordSection
            challengesSection
            pointsBalanceSection
        }
        .themedList()
        .navigationTitle(entry.playerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    if let player = player {
                        editName = player.name
                        editHandicap = player.handicapIndex == 0 ? "" : String(format: "%.1f", player.handicapIndex)
                        editColor = player.avatarColor
                        showingEditPlayer = true
                    }
                }
                .disabled(player == nil)
            }
        }
        .sheet(isPresented: $showingEditPlayer) {
            NavigationStack {
                Form {
                    Section("Player Details") {
                        TextField("Name", text: $editName)
                            .textInputAutocapitalization(.words)
                        TextField("Handicap Index", text: $editHandicap)
                            .keyboardType(.decimalPad)
                    }

                    Section("Avatar Color") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(PlayerColor.allCases) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if editColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture { editColor = color }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Edit Player")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEditPlayer = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let player = player {
                                player.name = editName.trimmingCharacters(in: .whitespaces)
                                player.handicapIndex = Double(editHandicap) ?? 0.0
                                player.avatarColor = editColor
                                appState.saveContext()
                            }
                            showingEditPlayer = false
                        }
                        .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                // Avatar
                Circle()
                    .fill(playerColor.color)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(player?.initials ?? String(entry.playerName.prefix(1)))
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.playerName)
                        .font(.title3.bold())

                    HStack(spacing: 12) {
                        if let player = player {
                            Label(player.formattedHandicap, systemImage: "number")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let team = player?.team {
                            Label(team.name, systemImage: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Position badge
                VStack(spacing: 2) {
                    Text(entry.positionDisplay)
                        .font(.title.bold())
                        .foregroundStyle(positionColor)
                    Text("POS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Scoring Summary

    private var scoringSummarySection: some View {
        Section("Scoring Summary") {
            HStack {
                statBox(title: "Gross", value: "\(entry.totalGross)", subtitle: entry.formattedGrossScoreToPar)
                Divider()
                statBox(title: "Net", value: "\(entry.totalNet)", subtitle: entry.formattedScoreToPar)
                Divider()
                statBox(title: "Rounds", value: "\(entry.roundsCompleted)/\(entry.totalRounds)", subtitle: entry.thruDisplay == "F" ? "Complete" : "Thru \(entry.thruDisplay)")
            }
            .frame(minHeight: 60)

            if entry.stablefordPoints > 0 {
                HStack {
                    Text("Stableford Points")
                        .font(.subheadline)
                    Spacer()
                    Text("\(entry.stablefordPoints)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.primary)
                }
            }
        }
    }

    // MARK: - Round by Round

    private var roundByRoundSection: some View {
        Section("Round-by-Round") {
            let playerRounds = roundDetails
            if playerRounds.isEmpty {
                Text("No rounds played yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(playerRounds) { detail in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(detail.courseName)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(detail.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 0) {
                            roundStatCell(label: "Gross", value: "\(detail.gross)")
                            roundStatCell(label: "Net", value: "\(detail.net)")
                            roundStatCell(label: "F9", value: "\(detail.frontNineGross)")
                            roundStatCell(label: "B9", value: "\(detail.backNineGross)")
                            if detail.putts > 0 {
                                roundStatCell(label: "Putts", value: "\(detail.putts)")
                            }
                            roundStatCell(label: "Birdies", value: "\(detail.birdies)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Match Record

    @ViewBuilder
    private var matchRecordSection: some View {
        let record = matchRecord
        if record.played > 0 {
            Section("Match Record") {
                HStack {
                    statBox(title: "Won", value: "\(record.won)", subtitle: nil)
                    Divider()
                    statBox(title: "Lost", value: "\(record.lost)", subtitle: nil)
                    Divider()
                    statBox(title: "Halved", value: "\(record.halved)", subtitle: nil)
                }
                .frame(minHeight: 50)

                HStack {
                    Text("Record")
                        .font(.subheadline)
                    Spacer()
                    Text("\(record.won)W - \(record.lost)L - \(record.halved)H")
                        .font(.subheadline.bold())
                        .foregroundStyle(record.won > record.lost ? .green : record.won < record.lost ? .red : .primary)
                }
            }
        }
    }

    // MARK: - Challenges

    @ViewBuilder
    private var challengesSection: some View {
        let challenges = challengeDetails
        if !challenges.isEmpty {
            Section("Challenges") {
                ForEach(challenges) { challenge in
                    HStack(spacing: 10) {
                        Image(systemName: challenge.icon)
                            .font(.caption)
                            .foregroundStyle(Theme.primary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(challenge.typeName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let metricValue = challenge.metricValue {
                            Text(metricValue)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }

                        challengeStatusBadge(challenge.status)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Points Balance

    @ViewBuilder
    private var pointsBalanceSection: some View {
        let balance = playerBalance
        if let balance = balance {
            Section("Points Balance") {
                HStack {
                    Text("Net Balance")
                        .font(.subheadline)
                    Spacer()
                    Text(balance.formattedBalance)
                        .font(.title3.bold())
                        .foregroundStyle(balance.isPositive ? .green : .red)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func statBox(title: String, value: String, subtitle: String?) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(scoreColorForSubtitle(subtitle))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func roundStatCell(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
        }
        .frame(maxWidth: .infinity)
    }

    private func challengeStatusBadge(_ status: ChallengeDetailStatus) -> some View {
        Text(status.label)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }

    // MARK: - Data Computation

    private var player: Player? {
        trip.player(withId: entry.playerId)
    }

    private var playerColor: PlayerColor {
        player?.avatarColor ?? .blue
    }

    private var positionColor: Color {
        switch entry.position {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }

    private func scoreColorForSubtitle(_ text: String) -> Color {
        if text.hasPrefix("-") { return .birdie }
        if text == "E" || text.hasPrefix("Complete") || text.hasPrefix("Thru") { return .par }
        return .bogey
    }

    // MARK: - Round Details

    struct RoundDetail: Identifiable {
        let id: UUID
        let courseName: String
        let date: String
        let gross: Int
        let net: Int
        let frontNineGross: Int
        let backNineGross: Int
        let putts: Int
        let birdies: Int
    }

    private var roundDetails: [RoundDetail] {
        trip.rounds.compactMap { round in
            guard let card = round.scorecard(forPlayer: entry.playerId),
                  card.holesCompleted > 0 else { return nil }

            let birdies = card.holeScores.filter { $0.isCompleted && $0.scoreToPar <= -1 }.count

            return RoundDetail(
                id: round.id,
                courseName: round.course?.name ?? "Unknown",
                date: round.formattedDate,
                gross: card.totalGross,
                net: card.totalNet,
                frontNineGross: card.frontNineGross,
                backNineGross: card.backNineGross,
                putts: card.totalPutts,
                birdies: birdies
            )
        }
    }

    // MARK: - Match Record

    struct MatchRecordSummary {
        let won: Int
        let lost: Int
        let halved: Int
        var played: Int { won + lost + halved }
    }

    private var matchRecord: MatchRecordSummary {
        var won = 0, lost = 0, halved = 0

        for round in trip.rounds {
            guard let course = round.course else { continue }
            let rule = TeamMatchPlayEngine.resolveScoringRule(round: round, trip: trip)
            let result = TeamMatchPlayEngine.calculateRoundResults(
                round: round, course: course, players: trip.players, teams: trip.teams, scoringRule: rule
            )

            // Individual matches
            for match in result.individualMatches {
                guard match.player1Id == entry.playerId || match.player2Id == entry.playerId else { continue }
                guard match.matchPlayResult.isComplete else { continue }

                let p1Wins = match.matchPlayResult.player1Wins
                let p2Wins = match.matchPlayResult.player2Wins
                let isPlayer1 = match.player1Id == entry.playerId

                if p1Wins == p2Wins {
                    halved += 1
                } else if (isPlayer1 && p1Wins > p2Wins) || (!isPlayer1 && p2Wins > p1Wins) {
                    won += 1
                } else {
                    lost += 1
                }
            }

            // Nines matches
            for match in result.ninesMatches {
                guard match.player1Id == entry.playerId || match.player2Id == entry.playerId else { continue }
                let isPlayer1 = match.player1Id == entry.playerId
                let myTeamId = isPlayer1 ? match.player1TeamId : match.player2TeamId

                // Front 9
                if match.front9Complete {
                    if let winner = match.front9WinnerTeamId {
                        if winner == myTeamId { won += 1 } else { lost += 1 }
                    } else if match.front9Halved {
                        halved += 1
                    }
                }
                // Back 9
                if match.isComplete {
                    if let winner = match.back9WinnerTeamId {
                        if winner == myTeamId { won += 1 } else { lost += 1 }
                    } else if match.back9Halved {
                        halved += 1
                    }
                }
                // Overall
                if match.isComplete {
                    if let winner = match.overallWinnerTeamId {
                        if winner == myTeamId { won += 1 } else { lost += 1 }
                    } else if match.overallHalved {
                        halved += 1
                    }
                }
            }
        }

        return MatchRecordSummary(won: won, lost: lost, halved: halved)
    }

    // MARK: - Challenge Details

    enum ChallengeDetailStatus {
        case won, lost, active

        var label: String {
            switch self {
            case .won: return "WON"
            case .lost: return "LOST"
            case .active: return "ACTIVE"
            }
        }

        var color: Color {
            switch self {
            case .won: return .green
            case .lost: return .red
            case .active: return Theme.primary
            }
        }
    }

    struct ChallengeDetail: Identifiable {
        let id: UUID
        let name: String
        let typeName: String
        let icon: String
        let status: ChallengeDetailStatus
        let metricValue: String?
    }

    private var challengeDetails: [ChallengeDetail] {
        trip.sideBets
            .filter { $0.participants.contains(entry.playerId) }
            .map { bet in
                let status: ChallengeDetailStatus
                if bet.isCompleted {
                    status = bet.winnerId == entry.playerId ? .won : .lost
                } else {
                    status = .active
                }

                var metricValue: String? = nil
                if bet.isRoundBased, let round = bet.round {
                    if let value = ChallengesViewModel.metricForPlayer(entry.playerId, bet: bet, round: round) {
                        metricValue = "\(value) \(ChallengesViewModel.metricLabel(for: bet.challengeType))"
                    }
                } else if bet.challengeType.isCustom {
                    if let value = bet.customValues[entry.playerId] {
                        metricValue = "\(value.formatted())"
                    }
                }

                return ChallengeDetail(
                    id: bet.id,
                    name: bet.name,
                    typeName: bet.betType.displayName,
                    icon: bet.betType.icon,
                    status: status,
                    metricValue: metricValue
                )
            }
    }

    // MARK: - Points Balance

    private var playerBalance: PlayerBalance? {
        let settlement = SettlementEngine.generateSettlement(trip: trip)
        return settlement.playerBalances.first { $0.playerId == entry.playerId }
    }
}
