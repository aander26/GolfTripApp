import Foundation
import SwiftUI

// MARK: - Display models

/// One round's slice of the pre-event confirmation summary.
struct ConfirmationRoundSummary: Identifiable {
    let id: UUID
    /// "Today · Round 2 · 1:30 PM"
    let dayLabel: String
    let courseName: String
    let formatLabel: String
    let formatDescription: String?
    /// Team scoring rule summary, e.g. "Singles Match Play — 1 pt win / 0.5 halve".
    let teamScoringLabel: String?
    let playerCount: Int
    /// 1v1 matchup strings, e.g. "Alex vs Keith". Empty when not a match-play round.
    let pairings: [String]
    /// Foursomes / playing groups configured for this round.
    let playingGroups: [ConfirmationPlayingGroupSummary]
    /// Challenges (SideBet) scoped to this round.
    let challenges: [ConfirmationChallengeSummary]
    /// Side games (SideGame) scoped to this round.
    let games: [ConfirmationGameSummary]
    /// "Tracking putts" / "No putts tracked".
    let puttsLabel: String
}

struct ConfirmationPlayingGroupSummary: Identifiable {
    let id: UUID
    let name: String
    let playerNames: [String]
    let teeTimeLabel: String?
    let scorerName: String?
    let startingHole: Int
}

struct ConfirmationChallengeSummary: Identifiable {
    let id: UUID
    let name: String
    /// "Most Birdies" / "Fewest Putts" / etc.
    let typeLabel: String
    /// Human-readable description from the challenge type.
    let description: String
    let participantNames: [String]
    /// Stakes / pot text, if any.
    let stakesLabel: String?
    /// Scope: "Trip-wide" or "Round 2 · Pine Valley".
    let scopeLabel: String
}

struct ConfirmationGameSummary: Identifiable {
    let id: UUID
    /// Display name, e.g. "Skins" / "Wolf".
    let typeName: String
    let participantNames: [String]
    let stakesLabel: String
    /// "Holes 4, 7, 12, 16" when designated; nil for full-round games.
    let designatedHolesLabel: String?
    /// Scope: "Trip-wide" or "Round 2 · Pine Valley".
    let scopeLabel: String
}

// MARK: - View model

@MainActor @Observable
final class TripConfirmationViewModel {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var trip: Trip? { appState.currentTrip }

    // MARK: - Section data

    /// All teams in the trip, with their members. Empty when no teams configured.
    var teams: [Team] { trip?.teams ?? [] }

    /// Per-round summaries, sorted by date (earliest first).
    var rounds: [ConfirmationRoundSummary] {
        guard let trip else { return [] }
        return trip.rounds
            .sorted { $0.date < $1.date }
            .enumerated()
            .map { index, round in
                buildRoundSummary(round: round, trip: trip, roundIndex: index)
            }
    }

    /// Challenges (SideBet) not tied to a specific round — trip-wide running competitions.
    var tripWideChallenges: [ConfirmationChallengeSummary] {
        guard let trip else { return [] }
        return trip.sideBets
            .filter { $0.round == nil && $0.isTripWide }
            .map { buildChallengeSummary(bet: $0, trip: trip) }
    }

    /// Side games (SideGame) not tied to a specific round.
    var tripWideGames: [ConfirmationGameSummary] {
        guard let trip else { return [] }
        return trip.sideGames
            .filter { $0.round == nil }
            .map { buildGameSummary(game: $0, trip: trip) }
    }

    /// True when there's anything at all to review (otherwise show an empty state).
    var hasContent: Bool {
        !teams.isEmpty || !rounds.isEmpty || !tripWideChallenges.isEmpty || !tripWideGames.isEmpty
    }

    // MARK: - Confirmation state

    /// The current user's Player record in this trip, if any. Confirmations are keyed on this.
    var myPlayer: Player? {
        guard let trip else { return nil }
        return appState.myPlayer(in: trip)
    }

    /// Players who have confirmed the pre-event setup, in roster order.
    var confirmedPlayers: [Player] {
        guard let trip else { return [] }
        let confirmedSet = Set(trip.confirmedByPlayerIds)
        return trip.players.filter { confirmedSet.contains($0.id.uuidString) }
    }

    /// Players in the trip who have a linked user profile (i.e., can actually confirm from a device).
    /// Used as the denominator for the "X of Y confirmed" progress.
    var appUserPlayers: [Player] {
        trip?.players.filter { $0.userProfileId != nil } ?? []
    }

    /// True when the current user has marked the setup as reviewed.
    var currentUserHasConfirmed: Bool {
        guard let me = myPlayer, let trip else { return false }
        return trip.confirmedByPlayerIds.contains(me.id.uuidString)
    }

    /// True when there's no Player record linked to the current user in this trip — they can
    /// view the screen but can't confirm (they're a guest viewer / spectator).
    var currentUserIsGuest: Bool { myPlayer == nil }

    /// Progress text: "3 of 4 players confirmed" / "All players confirmed". Nil when no app users.
    var progressLabel: String? {
        let total = appUserPlayers.count
        guard total > 0 else { return nil }
        let confirmed = confirmedPlayers.filter { $0.userProfileId != nil }.count
        if confirmed >= total { return "All \(total) players confirmed" }
        return "\(confirmed) of \(total) players confirmed"
    }

    // MARK: - Mutations

    /// Mark the setup as reviewed by the current user. Append-only; idempotent.
    func confirm() {
        guard let trip, let me = myPlayer else { return }
        let key = me.id.uuidString
        guard !trip.confirmedByPlayerIds.contains(key) else { return }
        trip.confirmedByPlayerIds.append(key)
        appState.saveContext()
    }

    /// Remove the current user's confirmation. Useful for "wait, I need to re-check something."
    func unconfirm() {
        guard let trip, let me = myPlayer else { return }
        let key = me.id.uuidString
        trip.confirmedByPlayerIds.removeAll { $0 == key }
        appState.saveContext()
    }

    // MARK: - Builders

    private func buildRoundSummary(round: Round, trip: Trip, roundIndex: Int) -> ConfirmationRoundSummary {
        let teeTimeFormatter = DateFormatter()
        teeTimeFormatter.dateFormat = "h:mm a"

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMM d"
        let calendar = Calendar.current
        let dayPrefix: String = {
            if calendar.isDateInToday(round.date) { return "Today" }
            if calendar.isDateInTomorrow(round.date) { return "Tomorrow" }
            if calendar.isDateInYesterday(round.date) { return "Yesterday" }
            return dayFormatter.string(from: round.date)
        }()
        let dayLabel = "\(dayPrefix) · Round \(roundIndex + 1) · \(teeTimeFormatter.string(from: round.date))"

        let format = round.format
        let teamRule = TeamMatchPlayEngine.resolveScoringRule(round: round, trip: trip)
        let teamScoringLabel: String? = {
            guard !trip.teams.isEmpty, format.requiresTeams else { return nil }
            return "\(teamRule.format.rawValue) — \(teamRule.format.description)"
        }()

        // Pairings: prefer the round's stored matchPairings; else derive (display-only) when
        // format is match-play and the round has teams.
        let pairings: [String] = {
            if !round.matchPairings.isEmpty {
                return round.matchPairings.compactMap { pairing in
                    guard let p1 = trip.player(withId: pairing.player1Id),
                          let p2 = trip.player(withId: pairing.player2Id) else { return nil }
                    return "\(p1.name) vs \(p2.name)"
                }
            }
            guard format == .matchPlay, trip.teams.count >= 2 else { return [] }
            let teamPairs = TeamMatchPlayEngine.generateTeamPairs(teams: trip.teams)
            var built: [String] = []
            for (teamA, teamB) in teamPairs {
                let aPlayers = trip.players.filter { $0.team?.id == teamA.id && round.playerIds.contains($0.id) }
                let bPlayers = trip.players.filter { $0.team?.id == teamB.id && round.playerIds.contains($0.id) }
                for pairing in TeamMatchPlayEngine.generatePairings(team1Players: aPlayers, team2Players: bPlayers) {
                    guard let p1 = trip.player(withId: pairing.player1Id),
                          let p2 = trip.player(withId: pairing.player2Id) else { continue }
                    built.append("\(p1.name) vs \(p2.name)")
                }
            }
            return built
        }()

        let groups: [ConfirmationPlayingGroupSummary] = round.playingGroups.map { g in
            ConfirmationPlayingGroupSummary(
                id: g.id,
                name: g.name,
                playerNames: g.playerIds.compactMap { trip.player(withId: $0)?.name },
                teeTimeLabel: g.teeTime.map { teeTimeFormatter.string(from: $0) },
                scorerName: g.scorerPlayerId.flatMap { trip.player(withId: $0)?.name },
                startingHole: g.startingHole
            )
        }

        let roundBets = trip.sideBets.filter { $0.round?.id == round.id }
        let challenges = roundBets.map { buildChallengeSummary(bet: $0, trip: trip) }

        let roundGames = trip.sideGames.filter { $0.round?.id == round.id }
        let games = roundGames.map { buildGameSummary(game: $0, trip: trip) }

        return ConfirmationRoundSummary(
            id: round.id,
            dayLabel: dayLabel,
            courseName: round.course?.name ?? "Course TBD",
            formatLabel: format.rawValue,
            formatDescription: format.description,
            teamScoringLabel: teamScoringLabel,
            playerCount: round.playerIds.count,
            pairings: pairings,
            playingGroups: groups,
            challenges: challenges,
            games: games,
            puttsLabel: round.trackPutts ? "Tracking putts" : "Putts off"
        )
    }

    private func buildChallengeSummary(bet: SideBet, trip: Trip) -> ConfirmationChallengeSummary {
        let names = bet.participants.compactMap { trip.player(withId: $0)?.name }
        let stakes: String? = {
            let pool = bet.poolDisplayText
            return pool.isEmpty ? nil : pool
        }()
        let scope: String = {
            if let r = bet.round {
                let idx = trip.rounds.sorted(by: { $0.date < $1.date }).firstIndex(where: { $0.id == r.id })
                let roundLabel = idx.map { "Round \($0 + 1)" } ?? "Round"
                return "\(roundLabel) · \(r.course?.name ?? "Course TBD")"
            }
            return "Trip-wide"
        }()
        return ConfirmationChallengeSummary(
            id: bet.id,
            name: bet.name,
            typeLabel: bet.challengeType.displayName,
            description: bet.challengeType.description,
            participantNames: names,
            stakesLabel: stakes,
            scopeLabel: scope
        )
    }

    private func buildGameSummary(game: SideGame, trip: Trip) -> ConfirmationGameSummary {
        let names = game.participantIds.compactMap { trip.player(withId: $0)?.name }
        let stakes = game.stakesLabel.isEmpty
            ? (game.stakes > 0 ? "\(String(format: "%.0f", game.stakes)) pts" : "Bragging rights")
            : game.stakesLabel
        let designatedLabel: String? = {
            guard !game.designatedHoles.isEmpty else { return nil }
            let list = game.designatedHoles.sorted().map(String.init).joined(separator: ", ")
            return "Holes \(list)"
        }()
        let scope: String = {
            if let r = game.round {
                let idx = trip.rounds.sorted(by: { $0.date < $1.date }).firstIndex(where: { $0.id == r.id })
                let roundLabel = idx.map { "Round \($0 + 1)" } ?? "Round"
                return "\(roundLabel) · \(r.course?.name ?? "Course TBD")"
            }
            return "Trip-wide"
        }()
        return ConfirmationGameSummary(
            id: game.id,
            typeName: game.type.rawValue,
            participantNames: names,
            stakesLabel: stakes,
            designatedHolesLabel: designatedLabel,
            scopeLabel: scope
        )
    }
}
