import Foundation

struct LeaderboardEntry: Identifiable, Equatable, Hashable {
    var id: UUID { playerId }
    var playerId: UUID
    var playerName: String
    var teamId: UUID?
    var position: Int
    var totalGross: Int
    var totalNet: Int
    var scoreToPar: Int
    var netScoreToPar: Int
    var holesCompleted: Int
    var roundsCompleted: Int
    var totalRounds: Int
    var stablefordPoints: Int

    init(
        playerId: UUID,
        playerName: String,
        teamId: UUID? = nil,
        position: Int = 0,
        totalGross: Int = 0,
        totalNet: Int = 0,
        scoreToPar: Int = 0,
        netScoreToPar: Int = 0,
        holesCompleted: Int = 0,
        roundsCompleted: Int = 0,
        totalRounds: Int = 0,
        stablefordPoints: Int = 0
    ) {
        self.playerId = playerId
        self.playerName = playerName
        self.teamId = teamId
        self.position = position
        self.totalGross = totalGross
        self.totalNet = totalNet
        self.scoreToPar = scoreToPar
        self.netScoreToPar = netScoreToPar
        self.holesCompleted = holesCompleted
        self.roundsCompleted = roundsCompleted
        self.totalRounds = totalRounds
        self.stablefordPoints = stablefordPoints
    }

    static func == (lhs: LeaderboardEntry, rhs: LeaderboardEntry) -> Bool {
        lhs.playerId == rhs.playerId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(playerId)
    }

    var formattedScoreToPar: String {
        if netScoreToPar == 0 { return "E" }
        return netScoreToPar > 0 ? "+\(netScoreToPar)" : "\(netScoreToPar)"
    }

    var formattedGrossScoreToPar: String {
        if scoreToPar == 0 { return "E" }
        return scoreToPar > 0 ? "+\(scoreToPar)" : "\(scoreToPar)"
    }

    var thruDisplay: String {
        if holesCompleted == 18 { return "F" }
        if holesCompleted == 0 { return "-" }
        return "\(holesCompleted)"
    }

    var positionDisplay: String {
        if position == 0 { return "-" }
        return "\(position)"
    }
}

struct MatchPlayResult: Identifiable, Hashable {
    var id: UUID
    var player1Id: UUID
    var player2Id: UUID
    var player1Wins: Int
    var player2Wins: Int
    var holesPlayed: Int
    var result: String

    init(
        id: UUID = UUID(),
        player1Id: UUID,
        player2Id: UUID,
        player1Wins: Int = 0,
        player2Wins: Int = 0,
        holesPlayed: Int = 0,
        result: String = ""
    ) {
        self.id = id
        self.player1Id = player1Id
        self.player2Id = player2Id
        self.player1Wins = player1Wins
        self.player2Wins = player2Wins
        self.holesPlayed = holesPlayed
        self.result = result
    }

    var margin: Int { abs(player1Wins - player2Wins) }
    var holesRemaining: Int { 18 - holesPlayed }
    var isComplete: Bool { holesPlayed == 18 || margin > holesRemaining }

    var statusText: String {
        if isComplete {
            return result
        }
        if player1Wins == player2Wins {
            return "All Square thru \(holesPlayed)"
        }
        let leader = player1Wins > player2Wins ? "P1" : "P2"
        return "\(leader) \(margin) UP thru \(holesPlayed)"
    }
}
