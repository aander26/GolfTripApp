import Foundation

// MARK: - Banner state

/// Display-ready model for the live match-status banner shown during in-progress scoring.
/// Built from `TeamMatchPlayEngine.calculateRoundResults` — the engine is the source of truth.
struct LiveMatchBannerState: Equatable {
    enum Mode: Equatable {
        case hidden                 // round isn't a match-play format, or no scores yet
        case individual             // 1v1 singles / traditional match play
        case bestBall               // 4-ball best ball
        case nines                  // nines & overall (or match play with nines toggle)
    }

    let mode: Mode

    /// Top line shown in the banner — e.g., "Team Blue 1 UP thru 7" or "Alex def. Keith 3&2".
    let primaryLine: String

    /// Optional second line — e.g., "DORMIE", "F9: BLUE 1↑ · B9: AS", or nil.
    let secondaryLine: String?

    /// All pairings/matches for this round, used by the strip and the detail sheet.
    let pairings: [PairingSummary]

    /// True when the headline match is closed out.
    let isClosedOut: Bool

    /// True when the headline match is dormie (leader up by exactly remaining holes).
    let isDormie: Bool

    /// Optional "MY TEAM 2-1-0" pill summarizing the user's team record across all pairings/matches
    /// in this round. Nil when there's no team context (singles round-robin, no teams configured,
    /// or the user has no team).
    let teamRecordLine: String?

    static let hidden = LiveMatchBannerState(
        mode: .hidden,
        primaryLine: "",
        secondaryLine: nil,
        pairings: [],
        isClosedOut: false,
        isDormie: false,
        teamRecordLine: nil
    )
}

/// A single pairing inside the banner / detail sheet.
struct PairingSummary: Identifiable, Equatable {
    enum Side { case left, right }

    let id: UUID
    let leftLabel: String
    let rightLabel: String
    let statusText: String
    let leftWins: Int
    let rightWins: Int
    let halved: Int
    let holesPlayed: Int
    let isComplete: Bool
    let isDormie: Bool
    /// Side currently leading (.left, .right, or nil for all-square).
    let leadingSide: Side?
    /// Per-hole result from left side's perspective, indexed by hole number.
    /// .win/.loss/.halve/.notPlayed.
    let holeResults: [Int: HoleResult]
    /// Player IDs of each side. Populated for individual/singles match play. Nil for team-vs-team
    /// (best ball, nines) where the "side" is a team, not a single player. Used by the concede flow.
    let leftPlayerId: UUID?
    let rightPlayerId: UUID?
}

enum HoleResult: Equatable {
    case win, loss, halve, notPlayed
}

// MARK: - View model

enum LiveMatchStatusViewModel {
    /// Compute live match status for an in-progress (or completed) round.
    /// Returns `.hidden` for stroke-play-only formats, rounds with no teams, or rounds with no scores.
    /// - Parameter currentPlayerId: when provided, the headline pairing prefers a match involving
    ///   this player. Falls back to the "biggest margin" heuristic if the player isn't in any pairing.
    static func state(
        round: Round,
        trip: Trip,
        course: Course,
        currentPlayerId: UUID? = nil
    ) -> LiveMatchBannerState {
        // Need at least 2 teams for any match-play computation.
        guard trip.teams.count >= 2 else { return .hidden }

        // Lazily persist auto-generated match pairings on first access. Without this, every
        // engine call produces fresh UUIDs for transient pairings and concession can't target
        // a stable identity. Idempotent — only runs once per round when pairings are empty.
        TeamMatchPlayEngine.materializePairingsIfNeeded(
            round: round,
            players: trip.players,
            teams: trip.teams
        )

        let rule = TeamMatchPlayEngine.resolveScoringRule(round: round, trip: trip)
        let result = TeamMatchPlayEngine.calculateRoundResults(
            round: round,
            course: course,
            players: trip.players,
            teams: trip.teams,
            scoringRule: rule
        )

        // Compute the user's team record across all matches in this round, used by the banner
        // as a single pill ("BLUE 2-1-0"). Nil when there's no team context.
        let userTeamId: UUID? = {
            guard let pid = currentPlayerId,
                  let player = trip.players.first(where: { $0.id == pid }) else { return nil }
            return player.team?.id
        }()
        let teamRecordLine = teamRecordSummary(
            result: result,
            userTeamId: userTeamId,
            teams: trip.teams
        )

        // Best ball mode wins if populated.
        if !result.bestBallMatches.isEmpty {
            return buildBestBallState(
                result: result,
                currentPlayerId: currentPlayerId,
                teamRecordLine: teamRecordLine
            )
        }
        // Nines & overall populates ninesMatches.
        if !result.ninesMatches.isEmpty {
            return buildNinesState(
                result: result,
                currentPlayerId: currentPlayerId,
                teamRecordLine: teamRecordLine
            )
        }
        // Traditional / singles match play populates individualMatches.
        if !result.individualMatches.isEmpty {
            return buildIndividualState(
                result: result,
                round: round,
                course: course,
                currentPlayerId: currentPlayerId,
                teamRecordLine: teamRecordLine
            )
        }

        // Pure stroke-play formats — totalsBar already covers the user.
        return .hidden
    }

    // MARK: - Mode builders

    private static func buildIndividualState(
        result: RoundTeamMatchResult,
        round: Round,
        course: Course,
        currentPlayerId: UUID?,
        teamRecordLine: String?
    ) -> LiveMatchBannerState {
        // Skip when no holes have been scored across any pairing yet — banner would be all-noise.
        let anyScored = result.individualMatches.contains { $0.matchPlayResult.holesPlayed > 0 }
        guard anyScored else { return .hidden }

        // Keep the source `IndividualMatchResult` next to each `PairingSummary` so we can pick a
        // headline using the original player IDs (PairingSummary doesn't carry them).
        let zipped: [(PairingSummary, IndividualMatchResult)] = result.individualMatches.map { match in
            let mp = match.matchPlayResult
            let halved = max(0, mp.holesPlayed - mp.player1Wins - mp.player2Wins)
            let leading: PairingSummary.Side? = {
                if mp.player1Wins > mp.player2Wins { return .left }
                if mp.player2Wins > mp.player1Wins { return .right }
                return nil
            }()
            let summary = PairingSummary(
                id: match.id,
                leftLabel: match.player1Name,
                rightLabel: match.player2Name,
                statusText: shortStatus(for: mp),
                leftWins: mp.player1Wins,
                rightWins: mp.player2Wins,
                halved: halved,
                holesPlayed: mp.holesPlayed,
                isComplete: mp.isComplete,
                isDormie: mp.isDormie,
                leadingSide: leading,
                holeResults: holeResultsForIndividual(match: match, round: round, course: course),
                leftPlayerId: match.player1Id,
                rightPlayerId: match.player2Id
            )
            return (summary, match)
        }
        let pairings = zipped.map(\.0)

        // Prefer the current user's own pairing. Fall back to "most decided active match"
        // (biggest absolute margin among in-progress, then most-progressed).
        let headline: PairingSummary? = {
            if let pid = currentPlayerId,
               let mine = zipped.first(where: { $0.1.player1Id == pid || $0.1.player2Id == pid })?.0 {
                return mine
            }
            return pairings.max { a, b in
                if a.isComplete != b.isComplete { return a.isComplete && !b.isComplete }
                let aMargin = abs(a.leftWins - a.rightWins)
                let bMargin = abs(b.leftWins - b.rightWins)
                if aMargin != bMargin { return aMargin < bMargin }
                return a.holesPlayed < b.holesPlayed
            }
        }()

        let primary = headline?.statusText.isEmpty == false
            ? "\(headline!.leftLabel) vs \(headline!.rightLabel): \(headline!.statusText)"
            : "Match in progress"
        let secondary: String? = {
            if let h = headline, h.isDormie { return "DORMIE" }
            return nil
        }()

        return LiveMatchBannerState(
            mode: .individual,
            primaryLine: primary,
            secondaryLine: secondary,
            pairings: pairings,
            isClosedOut: headline?.isComplete ?? false,
            isDormie: headline?.isDormie ?? false,
            teamRecordLine: teamRecordLine
        )
    }

    private static func buildBestBallState(
        result: RoundTeamMatchResult,
        currentPlayerId: UUID?,
        teamRecordLine: String?
    ) -> LiveMatchBannerState {
        let anyScored = result.bestBallMatches.contains { $0.holesPlayed > 0 }
        guard anyScored else { return .hidden }

        // For best-ball, the source match doesn't expose member player IDs — we can't tell
        // which match the current player belongs to without team membership. So `currentPlayerId`
        // is only used as a no-op fallback here. The headline stays as the first match.
        _ = currentPlayerId

        let pairings = result.bestBallMatches.map { match -> PairingSummary in
            let halved = max(0, match.holesPlayed - match.team1HolesWon - match.team2HolesWon)
            let leading: PairingSummary.Side? = {
                if match.team1HolesWon > match.team2HolesWon { return .left }
                if match.team2HolesWon > match.team1HolesWon { return .right }
                return nil
            }()
            return PairingSummary(
                id: match.id,
                leftLabel: match.team1Name,
                rightLabel: match.team2Name,
                statusText: shortStatus(for: match),
                leftWins: match.team1HolesWon,
                rightWins: match.team2HolesWon,
                halved: halved,
                holesPlayed: match.holesPlayed,
                isComplete: match.isComplete,
                isDormie: match.isDormie,
                leadingSide: leading,
                holeResults: [:],   // per-hole granularity for best ball requires engine support; deferred
                leftPlayerId: nil,
                rightPlayerId: nil
            )
        }

        let headline = pairings.first
        let primary = headline.map { "\($0.leftLabel) vs \($0.rightLabel): \($0.statusText)" } ?? "Match in progress"
        let secondary: String? = {
            if let h = headline, h.isDormie { return "DORMIE" }
            return nil
        }()

        return LiveMatchBannerState(
            mode: .bestBall,
            primaryLine: primary,
            secondaryLine: secondary,
            pairings: pairings,
            isClosedOut: headline?.isComplete ?? false,
            isDormie: headline?.isDormie ?? false,
            teamRecordLine: teamRecordLine
        )
    }

    private static func buildNinesState(
        result: RoundTeamMatchResult,
        currentPlayerId: UUID?,
        teamRecordLine: String?
    ) -> LiveMatchBannerState {
        let anyScored = result.ninesMatches.contains { $0.holesCompleted > 0 }
        guard anyScored else { return .hidden }

        let zipped: [(PairingSummary, NinesMatchResult)] = result.ninesMatches.map { match in
            let summary = PairingSummary(
                id: match.id,
                leftLabel: match.player1Name,
                rightLabel: match.player2Name,
                statusText: ninesShortStatus(match),
                leftWins: 0,            // nines doesn't use per-hole win counts
                rightWins: 0,
                halved: 0,
                holesPlayed: match.holesCompleted,
                isComplete: match.isComplete,
                isDormie: false,        // dormie is a binary match concept; nines runs to 18 by design
                leadingSide: nil,
                holeResults: [:],
                leftPlayerId: nil,      // nines doesn't currently surface concession
                rightPlayerId: nil
            )
            return (summary, match)
        }
        let pairings = zipped.map(\.0)

        let headline: PairingSummary? = {
            if let pid = currentPlayerId,
               let mine = zipped.first(where: { $0.1.player1Id == pid || $0.1.player2Id == pid })?.0 {
                return mine
            }
            return pairings.first
        }()
        let primary = headline.map { "\($0.leftLabel) vs \($0.rightLabel)" } ?? "Match in progress"
        let secondary = headline?.statusText

        return LiveMatchBannerState(
            mode: .nines,
            primaryLine: primary,
            secondaryLine: secondary,
            pairings: pairings,
            isClosedOut: pairings.allSatisfy { $0.isComplete },
            isDormie: false,
            teamRecordLine: teamRecordLine
        )
    }

    // MARK: - Status text helpers

    /// Shorter than `IndividualMatchResult.displayText` — drops the "PlayerA vs PlayerB —" prefix
    /// since the banner shows the names separately.
    private static func shortStatus(for mp: MatchPlayResult) -> String {
        if mp.isComplete {
            // Engine already produces "Alex def. Keith 3&2" or "Halved" — but it lives on the
            // wrapper (IndividualMatchResult). For MatchPlayResult standalone we synthesize from margin.
            let remaining = mp.holesRemaining
            if mp.player1Wins == mp.player2Wins { return "Halved" }
            let margin = mp.margin
            if remaining == 0 { return "WIN \(margin) UP" }
            return "WIN \(margin)&\(remaining)"
        }
        if mp.player1Wins == mp.player2Wins {
            return "AS thru \(mp.holesPlayed)"
        }
        return "\(mp.margin) UP thru \(mp.holesPlayed)"
    }

    private static func shortStatus(for match: TeamBestBallMatchResult) -> String {
        let absMarg = abs(match.margin)
        let remaining = match.holesRemaining
        if match.isComplete {
            if match.margin == 0 { return "Halved" }
            if remaining == 0 { return "WIN \(absMarg) UP" }
            return "WIN \(absMarg)&\(remaining)"
        }
        if match.margin == 0 { return "AS thru \(match.holesPlayed)" }
        return "\(absMarg) UP thru \(match.holesPlayed)"
    }

    private static func ninesShortStatus(_ match: NinesMatchResult) -> String {
        guard match.front9Complete else { return "F9 in progress (\(match.holesCompleted) holes)" }

        var parts: [String] = []
        // F9
        if match.front9Halved {
            parts.append("F9: AS")
        } else if let winner = match.front9WinnerTeamId {
            let name = winner == match.player1TeamId ? match.player1Name : match.player2Name
            parts.append("F9: \(name)")
        }

        if match.isComplete {
            if match.back9Halved {
                parts.append("B9: AS")
            } else if let winner = match.back9WinnerTeamId {
                let name = winner == match.player1TeamId ? match.player1Name : match.player2Name
                parts.append("B9: \(name)")
            }
            if match.overallHalved {
                parts.append("OA: AS")
            } else if let winner = match.overallWinnerTeamId {
                let name = winner == match.player1TeamId ? match.player1Name : match.player2Name
                parts.append("OA: \(name)")
            }
        } else {
            parts.append("B9 in progress")
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Per-hole result reconstruction (individual match play only)

    /// Re-run the match-play comparison hole-by-hole so the detail sheet can show a W/L/H
    /// trail under each pairing. Uses the same handicap-aware path as the engine.
    private static func holeResultsForIndividual(
        match: IndividualMatchResult,
        round: Round,
        course: Course
    ) -> [Int: HoleResult] {
        guard let card1 = round.scorecard(forPlayer: match.player1Id),
              let card2 = round.scorecard(forPlayer: match.player2Id) else { return [:] }

        // Engine uses 90% allowance + lowest-plays-scratch across the *pairing*.
        let strokeMaps = TeamMatchPlayEngine.matchPlayStrokeMaps(
            playerIds: [match.player1Id, match.player2Id],
            round: round,
            holes: course.holes
        )
        let map1 = strokeMaps[match.player1Id] ?? [:]
        let map2 = strokeMaps[match.player2Id] ?? [:]

        var results: [Int: HoleResult] = [:]
        for hole in course.holes {
            guard let s1 = card1.score(forHole: hole.number), s1.isCompleted,
                  let s2 = card2.score(forHole: hole.number), s2.isCompleted else {
                results[hole.number] = .notPlayed
                continue
            }
            let net1 = s1.strokes - (map1[hole.number] ?? 0)
            let net2 = s2.strokes - (map2[hole.number] ?? 0)
            if net1 < net2 { results[hole.number] = .win }
            else if net2 < net1 { results[hole.number] = .loss }
            else { results[hole.number] = .halve }
        }
        return results
    }

    // MARK: - Team record summary

    /// Build a "BLUE 2-1-0" pill summarizing the user's team record across all individual,
    /// best ball, and nines matches in this round. Returns nil when there's no team to summarize.
    private static func teamRecordSummary(
        result: RoundTeamMatchResult,
        userTeamId: UUID?,
        teams: [Team]
    ) -> String? {
        guard let teamId = userTeamId,
              let team = teams.first(where: { $0.id == teamId }) else { return nil }

        var wins = 0, losses = 0, halves = 0, inProgress = 0
        var counted = false

        // Individual / singles / traditional match play: count one record per pairing involving this team.
        for match in result.individualMatches {
            guard match.player1TeamId == teamId || match.player2TeamId == teamId else { continue }
            counted = true
            if !match.matchPlayResult.isComplete {
                inProgress += 1
            } else if let winnerId = match.winningTeamId {
                if winnerId == teamId { wins += 1 } else { losses += 1 }
            } else {
                halves += 1
            }
        }

        // Best ball: count one record per team-vs-team match the team is in.
        for match in result.bestBallMatches {
            guard match.team1Id == teamId || match.team2Id == teamId else { continue }
            counted = true
            if !match.isComplete {
                inProgress += 1
            } else if let winnerId = match.winningTeamId {
                if winnerId == teamId { wins += 1 } else { losses += 1 }
            } else {
                halves += 1
            }
        }

        // Nines & overall: each pairing contributes up to 3 segment outcomes (F9, B9, OA).
        for match in result.ninesMatches {
            guard match.player1TeamId == teamId || match.player2TeamId == teamId else { continue }
            counted = true
            if match.front9Complete {
                if match.front9Halved {
                    halves += 1
                } else if let winner = match.front9WinnerTeamId {
                    if winner == teamId { wins += 1 } else { losses += 1 }
                }
            } else {
                inProgress += 1
            }
            if match.isComplete {
                if match.back9Halved {
                    halves += 1
                } else if let winner = match.back9WinnerTeamId {
                    if winner == teamId { wins += 1 } else { losses += 1 }
                }
                if match.overallHalved {
                    halves += 1
                } else if let winner = match.overallWinnerTeamId {
                    if winner == teamId { wins += 1 } else { losses += 1 }
                }
            } else {
                inProgress += 2  // B9 + OA both still open
            }
        }

        guard counted else { return nil }

        // Compact summary: "BLUE 2-1-0" or "BLUE 1-0-0 · 2 open"
        let core = "\(team.name.uppercased()) \(wins)-\(losses)-\(halves)"
        if inProgress > 0 {
            return "\(core) · \(inProgress) open"
        }
        return core
    }
}
