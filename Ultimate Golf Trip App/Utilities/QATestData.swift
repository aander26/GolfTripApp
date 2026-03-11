import Foundation
import SwiftData

// MARK: - QA Test Data Generator
// Generates two complete trips with full scoring for QA testing.

enum QATestData {

    // MARK: - Shared User Profile

    static let userProfile: UserProfile = {
        UserProfile(name: "Alex Anderson", handicapIndex: 12.0, avatarColor: .blue)
    }()

    // ============================================================
    // MARK: - TRIP 1: Raleigh Showdown 2025 (4 Golfers, 2v2 Best Ball)
    // ============================================================

    // MARK: Players (Trip 1)

    static let t1Players: [Player] = {
        [
            Player(name: "Drew Palmer", handicapIndex: 6.0, avatarColor: .blue, userProfileId: userProfile.id),
            Player(name: "Jake Nicklaus", handicapIndex: 12.0, avatarColor: .green),
            Player(name: "Ryan Watson", handicapIndex: 18.0, avatarColor: .red),
            Player(name: "Tyler Hogan", handicapIndex: 24.0, avatarColor: .orange)
        ]
    }()

    // MARK: Teams (Trip 1)

    static let t1Teams: [Team] = {
        let teamA = Team(name: "Aces", color: .blue)
        let teamB = Team(name: "Eagles", color: .red)
        return [teamA, teamB]
    }()

    static let t1PlayersWithTeams: [Player] = {
        let p = t1Players
        // Team A: Drew Palmer (6) + Jake Nicklaus (12)
        p[0].team = t1Teams[0]
        p[1].team = t1Teams[0]
        // Team B: Ryan Watson (18) + Tyler Hogan (24)
        p[2].team = t1Teams[1]
        p[3].team = t1Teams[1]
        return p
    }()

    // MARK: Courses (Trip 1) — Raleigh, NC area

    static let t1Course1: Course = {
        let pars     = [4, 5, 3, 4, 4, 4, 3, 4, 5,   4, 4, 3, 5, 4, 4, 4, 3, 5]
        let yardages = [415, 535, 180, 390, 425, 405, 200, 445, 550,
                        400, 420, 170, 525, 385, 440, 410, 190, 560]
        let hdcps    = [7, 11, 15, 3, 1, 9, 13, 5, 17,   8, 2, 16, 10, 6, 4, 12, 18, 14]
        let holes = (0..<18).map { i in
            Hole(number: i+1, par: pars[i], yardage: yardages[i], handicapRating: hdcps[i])
        }
        return Course(
            name: "Lonnie Poole Golf Course",
            holes: holes, slopeRating: 138, courseRating: 73.2,
            city: "Raleigh", state: "NC", latitude: 35.77, longitude: -78.68,
            teamScoringRule: TeamScoringRule(
                format: .teamBestBall,
                pointsPerWin: 1.0, pointsPerHalve: 0.0, pointsPerLoss: 0.0,
                pointsPerNineWin: 1.0, pointsPerNineHalve: 0.0,
                pointsPerOverallWin: 3.0, pointsPerOverallHalve: 0.0,
                useNinesAndOverall: true
            )
        )
    }()

    static let t1Course2: Course = {
        let pars     = [4, 4, 3, 5, 4, 4, 3, 5, 4,   4, 3, 4, 5, 4, 4, 3, 4, 5]
        let yardages = [395, 410, 165, 520, 380, 430, 185, 540, 400,
                        420, 175, 405, 510, 375, 445, 195, 415, 545]
        let hdcps    = [5, 3, 17, 9, 7, 1, 15, 11, 13,   6, 18, 4, 10, 8, 2, 16, 12, 14]
        let holes = (0..<18).map { i in
            Hole(number: i+1, par: pars[i], yardage: yardages[i], handicapRating: hdcps[i])
        }
        return Course(
            name: "UNC Finley Golf Course",
            holes: holes, slopeRating: 132, courseRating: 72.6,
            city: "Chapel Hill", state: "NC", latitude: 35.89, longitude: -79.07,
            teamScoringRule: TeamScoringRule(
                format: .teamBestBall,
                pointsPerWin: 1.0, pointsPerHalve: 0.0, pointsPerLoss: 0.0,
                pointsPerNineWin: 1.0, pointsPerNineHalve: 0.0,
                pointsPerOverallWin: 3.0, pointsPerOverallHalve: 0.0,
                useNinesAndOverall: true
            )
        )
    }()

    static let t1Course3: Course = {
        let pars     = [4, 3, 5, 4, 4, 3, 4, 5, 4,   4, 5, 3, 4, 4, 4, 3, 5, 4]
        let yardages = [405, 175, 530, 400, 435, 190, 420, 550, 395,
                        410, 515, 180, 425, 390, 445, 200, 540, 405]
        let hdcps    = [3, 15, 9, 5, 1, 17, 7, 11, 13,   4, 10, 18, 2, 8, 6, 16, 12, 14]
        let holes = (0..<18).map { i in
            Hole(number: i+1, par: pars[i], yardage: yardages[i], handicapRating: hdcps[i])
        }
        return Course(
            name: "Prestonwood Country Club",
            holes: holes, slopeRating: 140, courseRating: 73.5,
            city: "Cary", state: "NC", latitude: 35.73, longitude: -78.82,
            teamScoringRule: TeamScoringRule(
                format: .teamBestBall,
                pointsPerWin: 1.0, pointsPerHalve: 0.0, pointsPerLoss: 0.0,
                pointsPerNineWin: 1.0, pointsPerNineHalve: 0.0,
                pointsPerOverallWin: 3.0, pointsPerOverallHalve: 0.0,
                useNinesAndOverall: true
            )
        )
    }()

    // MARK: - Score Generation Helpers

    /// Compute course handicap for a player on a course
    private static func courseHdcp(_ playerHdcp: Double, slope: Double, rating: Double, par: Int) -> Int {
        HandicapEngine.courseHandicap(handicapIndex: playerHdcp, slopeRating: slope, courseRating: rating, par: par)
    }

    /// Build a complete scorecard with pre-computed net scores
    private static func buildScorecard(
        round: Round, player: Player, course: Course, grossScores: [Int], putts: [Int]
    ) -> Scorecard {
        let ch = courseHdcp(player.handicapIndex, slope: course.slopeRating, rating: course.courseRating, par: course.totalPar)
        let strokeMap = HandicapEngine.distributeStrokes(courseHandicap: ch, holes: course.holes)

        var holeScores: [HoleScore] = []
        for (i, hole) in course.holes.enumerated() {
            let gross = grossScores[i]
            let received = strokeMap[hole.number] ?? 0
            let net = max(1, gross - received)
            holeScores.append(HoleScore(
                holeNumber: hole.number, par: hole.par,
                strokes: gross, netStrokes: net, strokesReceived: received,
                putts: putts[i]
            ))
        }

        let card = Scorecard(round: round, player: player, holeScores: holeScores, courseHandicap: ch, isComplete: true)
        return card
    }

    // MARK: - Round 1 (Lonnie Poole) — Team A wins F9, Team B wins B9, Team A wins overall
    // CH: Drew=9, Jake=16, Ryan=23, Tyler=31
    // Best-ball net: Aces F9=30, Eagles F9=36 → Aces win F9 (+1)
    //               Aces B9=35, Eagles B9=30 → Eagles win B9 (+1)
    //               Aces OA=65, Eagles OA=66 → Aces win Overall (+3)
    // Result: Aces 4 pts, Eagles 1 pt

    static let t1Round1: Round = {
        let p = t1PlayersWithTeams
        let course = t1Course1

        let round = Round(course: course, date: makeDate(2025, 6, 12), format: .bestBall,
                          playerIds: p.map(\.id), isComplete: true)

        // Drew Palmer (6 hdcp, CH=9) — great front nine, fades on back
        let drew1Gross = [4, 4, 3, 4, 4, 4, 3, 4, 5,   5, 5, 3, 5, 5, 5, 4, 3, 4] // 74
        let drew1Putts = [2, 2, 1, 2, 2, 1, 2, 1, 2,   2, 2, 2, 1, 2, 2, 1, 2, 2]

        // Jake Nicklaus (12 hdcp, CH=16) — steady round
        let jake1Gross = [4, 5, 4, 4, 4, 4, 4, 4, 5,   5, 5, 4, 6, 5, 5, 5, 3, 5] // 81
        let jake1Putts = [2, 2, 2, 2, 2, 1, 2, 2, 2,   2, 2, 2, 2, 1, 2, 2, 2, 2]

        // Ryan Watson (18 hdcp, CH=23) — tough front 9, strong back 9
        let ryan1Gross = [5, 6, 4, 6, 6, 5, 4, 6, 6,   4, 5, 4, 5, 4, 5, 4, 4, 6] // 89
        let ryan1Putts = [2, 2, 2, 2, 2, 2, 2, 2, 2,   1, 2, 1, 2, 2, 2, 2, 2, 2]

        // Tyler Hogan (24 hdcp, CH=31) — struggles early, settles in
        let tyler1Gross = [6, 7, 4, 6, 6, 6, 5, 6, 6,   5, 5, 4, 6, 5, 5, 5, 4, 6] // 97
        let tyler1Putts = [2, 3, 2, 2, 3, 2, 2, 2, 3,   2, 2, 2, 2, 2, 2, 2, 2, 2]

        let s1 = buildScorecard(round: round, player: p[0], course: course, grossScores: drew1Gross, putts: drew1Putts)
        let s2 = buildScorecard(round: round, player: p[1], course: course, grossScores: jake1Gross, putts: jake1Putts)
        let s3 = buildScorecard(round: round, player: p[2], course: course, grossScores: ryan1Gross, putts: ryan1Putts)
        let s4 = buildScorecard(round: round, player: p[3], course: course, grossScores: tyler1Gross, putts: tyler1Putts)

        round.scorecards = [s1, s2, s3, s4]
        return round
    }()

    // MARK: - Round 2 (UNC Finley) — Team B sweeps: wins F9, B9, and overall
    // CH: Drew=8, Jake=15, Ryan=22, Tyler=29
    // Best-ball net: Aces F9=31, Eagles F9=30 → Eagles win F9 (+1)
    //               Aces B9=32, Eagles B9=31 → Eagles win B9 (+1)
    //               Aces OA=63, Eagles OA=61 → Eagles win Overall (+3)
    // Result: Aces 0 pts, Eagles 5 pts

    static let t1Round2: Round = {
        let p = t1PlayersWithTeams
        let course = t1Course2

        let round = Round(course: course, date: makeDate(2025, 6, 13), format: .bestBall,
                          playerIds: p.map(\.id), isComplete: true)

        // Drew Palmer (6 hdcp, CH=8) — off day, struggles on the par 5s
        let drew2Gross = [4, 4, 3, 5, 4, 5, 4, 5, 4,   4, 3, 5, 5, 5, 4, 3, 5, 5] // 77
        let drew2Putts = [2, 2, 2, 2, 3, 2, 2, 2, 2,   2, 2, 3, 2, 2, 2, 2, 2, 2]

        // Jake Nicklaus (12 hdcp, CH=15) — flat day, no momentum
        let jake2Gross = [5, 5, 4, 5, 5, 5, 4, 5, 5,   5, 3, 5, 5, 5, 5, 4, 5, 5] // 85
        let jake2Putts = [2, 2, 2, 2, 2, 3, 2, 2, 2,   2, 2, 2, 2, 2, 3, 2, 2, 2]

        // Ryan Watson (18 hdcp, CH=22) — grinding out pars with strokes
        let ryan2Gross = [5, 5, 4, 6, 5, 5, 4, 6, 5,   5, 4, 5, 5, 5, 5, 4, 5, 6] // 89
        let ryan2Putts = [1, 2, 1, 2, 1, 2, 2, 2, 2,   1, 2, 2, 2, 1, 2, 1, 2, 2]

        // Tyler Hogan (24 hdcp, CH=29) — handicap strokes do heavy lifting
        let tyler2Gross = [5, 6, 4, 6, 5, 6, 4, 6, 5,   5, 4, 5, 6, 5, 6, 4, 5, 6] // 93
        let tyler2Putts = [2, 2, 2, 2, 2, 2, 1, 2, 2,   2, 2, 2, 2, 2, 2, 2, 2, 2]

        let s1 = buildScorecard(round: round, player: p[0], course: course, grossScores: drew2Gross, putts: drew2Putts)
        let s2 = buildScorecard(round: round, player: p[1], course: course, grossScores: jake2Gross, putts: jake2Putts)
        let s3 = buildScorecard(round: round, player: p[2], course: course, grossScores: ryan2Gross, putts: ryan2Putts)
        let s4 = buildScorecard(round: round, player: p[3], course: course, grossScores: tyler2Gross, putts: tyler2Putts)

        round.scorecards = [s1, s2, s3, s4]
        return round
    }()

    // MARK: - Round 3 (Prestonwood) — F9 tied, Team A wins B9 and overall
    // CH: Drew=9, Jake=16, Ryan=24, Tyler=31
    // Best-ball net: Aces F9=31, Eagles F9=31 → TIE (0 pts each)
    //               Aces B9=32, Eagles B9=33 → Aces win B9 (+1)
    //               Aces OA=63, Eagles OA=64 → Aces win Overall (+3)
    // Result: Aces 4 pts, Eagles 0 pts

    static let t1Round3: Round = {
        let p = t1PlayersWithTeams
        let course = t1Course3

        let round = Round(course: course, date: makeDate(2025, 6, 14), format: .bestBall,
                          playerIds: p.map(\.id), isComplete: true)

        // Drew Palmer (6 hdcp, CH=9) — solid round, team anchor
        let drew3Gross = [4, 3, 5, 4, 5, 3, 4, 6, 5,   4, 5, 3, 4, 4, 4, 3, 5, 4] // 75
        let drew3Putts = [1, 1, 2, 2, 2, 1, 2, 2, 2,   2, 2, 1, 1, 2, 2, 1, 2, 2]

        // Jake Nicklaus (12 hdcp, CH=16) — tough day, high scores
        let jake3Gross = [5, 4, 6, 5, 5, 4, 5, 5, 5,   5, 6, 4, 5, 5, 5, 4, 6, 5] // 89
        let jake3Putts = [2, 1, 2, 2, 2, 2, 2, 2, 2,   1, 2, 2, 2, 2, 2, 2, 2, 2]

        // Ryan Watson (18 hdcp, CH=24) — consistent but B9 slips
        let ryan3Gross = [5, 4, 5, 5, 6, 4, 4, 5, 5,   6, 5, 4, 6, 5, 5, 4, 5, 5] // 88
        let ryan3Putts = [1, 1, 2, 2, 2, 2, 2, 2, 2,   2, 2, 2, 2, 2, 2, 2, 2, 2]

        // Tyler Hogan (24 hdcp, CH=31) — fades on back nine
        let tyler3Gross = [5, 4, 6, 5, 6, 4, 5, 6, 6,   6, 6, 4, 6, 6, 5, 4, 6, 5] // 95
        let tyler3Putts = [2, 1, 2, 2, 2, 1, 2, 2, 2,   2, 3, 2, 2, 2, 2, 2, 2, 3]

        let s1 = buildScorecard(round: round, player: p[0], course: course, grossScores: drew3Gross, putts: drew3Putts)
        let s2 = buildScorecard(round: round, player: p[1], course: course, grossScores: jake3Gross, putts: jake3Putts)
        let s3 = buildScorecard(round: round, player: p[2], course: course, grossScores: ryan3Gross, putts: ryan3Putts)
        let s4 = buildScorecard(round: round, player: p[3], course: course, grossScores: tyler3Gross, putts: tyler3Putts)

        round.scorecards = [s1, s2, s3, s4]
        return round
    }()

    // MARK: - Side Bets (Trip 1)

    static let t1SideBets: [SideBet] = {
        let p = t1PlayersWithTeams
        return [
            // Closest to the pin on Hole 3 (par 3) — Round 1
            {
                let bet = SideBet(
                    name: "Closest to Pin — Hole 3",
                    betType: .custom,
                    participants: p.map(\.id),
                    stake: "$10 each",
                    status: .completed,
                    winnerId: p[0].id,  // Drew Palmer wins
                    isPotBet: true, potAmount: 10,
                    round: t1Round1
                )
                bet.customMetricName = "Distance (feet)"
                bet.customHighestWins = false  // lowest distance wins
                var vals: [UUID: Double] = [:]
                vals[p[0].id] = 4.5   // Drew: 4'6"
                vals[p[1].id] = 12.0  // Jake: 12'
                vals[p[2].id] = 8.3   // Ryan: 8'4"
                vals[p[3].id] = 22.0  // Tyler: 22'
                bet.customValues = vals
                return bet
            }(),

            // Longest Drive on Hole 2 (par 5) — Round 2
            {
                let bet = SideBet(
                    name: "Longest Drive — Hole 2",
                    betType: .custom,
                    participants: p.map(\.id),
                    stake: "Bragging Rights",
                    status: .completed,
                    winnerId: p[2].id,  // Ryan Watson wins (big hitter!)
                    round: t1Round2
                )
                bet.customMetricName = "Distance (yards)"
                bet.customHighestWins = true
                var vals: [UUID: Double] = [:]
                vals[p[0].id] = 275
                vals[p[1].id] = 262
                vals[p[2].id] = 289
                vals[p[3].id] = 255
                bet.customValues = vals
                return bet
            }(),

            // Most Birdies in Round 1
            {
                let bet = SideBet(
                    name: "Most Birdies — Round 1",
                    betType: .mostBirdies,
                    participants: p.map(\.id),
                    stake: "$20 per player",
                    status: .completed,
                    winnerId: p[0].id,  // Drew Palmer
                    isPotBet: true, potAmount: 20,
                    round: t1Round1
                )
                return bet
            }(),

            // Low Individual Round (Medalist) — Trip-wide
            {
                let bet = SideBet(
                    name: "Trip Medalist (Low Gross)",
                    betType: .lowRound,
                    participants: p.map(\.id),
                    stake: "Winner's trophy",
                    status: .completed,
                    winnerId: p[0].id  // Drew Palmer's 74 in R1
                )
                return bet
            }()
        ]
    }()

    // MARK: - Side Games (Trip 1)

    static let t1SideGames: [SideGame] = {
        let p = t1PlayersWithTeams
        let game = SideGame(
            type: .skins,
            round: t1Round1,
            participantIds: p.map(\.id),
            stakes: 5
        )
        // Add some skin results
        game.addResult(SideGameResult(holeNumber: 3, winnerId: p[0].id, amount: 5, description: "Drew wins with birdie"))
        game.addResult(SideGameResult(holeNumber: 7, winnerId: p[2].id, amount: 5, description: "Ryan wins with par"))
        game.addResult(SideGameResult(holeNumber: 12, winnerId: p[2].id, amount: 10, description: "Ryan wins (carry over)"))
        game.addResult(SideGameResult(holeNumber: 15, winnerId: p[0].id, amount: 15, description: "Drew wins (carry over)"))
        return [game]
    }()

    // MARK: - Trip 1 Assembly

    static let trip1: Trip = {
        let cal = Calendar.current
        let p = t1PlayersWithTeams

        let trip = Trip(
            name: "Raleigh Showdown 2025",
            startDate: makeDate(2025, 6, 12),
            endDate: makeDate(2025, 6, 14),
            players: p,
            teams: t1Teams,
            courses: [t1Course1, t1Course2, t1Course3],
            rounds: [t1Round1, t1Round2, t1Round3],
            sideGames: t1SideGames,
            ownerProfileId: userProfile.id,
            sideBets: t1SideBets,
            pointsPerMatchWin: 1.0,
            pointsPerMatchHalve: 0.5,
            pointsPerMatchLoss: 0.0
        )

        // War Room events
        let events = [
            WarRoomEvent(type: .flight, title: "Drew & Jake Arrive", subtitle: "DL 1247 from ATL",
                         dateTime: makeDateTime(2025, 6, 12, 10, 30), location: "RDU Airport",
                         playerIds: [p[0].id, p[1].id]),
            WarRoomEvent(type: .teeTime, title: "Round 1 — Lonnie Poole", subtitle: "8:00 AM Shotgun",
                         dateTime: makeDateTime(2025, 6, 12, 8, 0), location: "Lonnie Poole GC",
                         playerIds: p.map(\.id)),
            WarRoomEvent(type: .dinner, title: "Steakhouse Dinner", subtitle: "Angus Barn",
                         dateTime: makeDateTime(2025, 6, 12, 19, 0), location: "Angus Barn, Raleigh",
                         playerIds: p.map(\.id)),
            WarRoomEvent(type: .teeTime, title: "Round 2 — UNC Finley", subtitle: "9:30 AM",
                         dateTime: makeDateTime(2025, 6, 13, 9, 30), location: "UNC Finley GC",
                         playerIds: p.map(\.id)),
            WarRoomEvent(type: .teeTime, title: "Round 3 — Prestonwood", subtitle: "8:30 AM",
                         dateTime: makeDateTime(2025, 6, 14, 8, 30), location: "Prestonwood CC",
                         playerIds: p.map(\.id)),
        ]
        for e in events { trip.addWarRoomEvent(e) }

        return trip
    }()

    // ============================================================
    // MARK: - TRIP 2: Hilton Head Classic 2025 (8 Golfers, Round Robin)
    // ============================================================

    // MARK: Players (Trip 2)

    static let t2Players: [Player] = {
        [
            Player(name: "Marcus Johnson", handicapIndex: 4.0, avatarColor: .blue),
            Player(name: "Brandon Lee", handicapIndex: 8.0, avatarColor: .green),
            Player(name: "Chris Davis", handicapIndex: 12.0, avatarColor: .red),
            Player(name: "Derek Miller", handicapIndex: 16.0, avatarColor: .orange),
            Player(name: "Eric Wilson", handicapIndex: 20.0, avatarColor: .purple),
            Player(name: "Frank Thomas", handicapIndex: 22.0, avatarColor: .teal),
            Player(name: "Greg Anderson", handicapIndex: 25.0, avatarColor: .pink),
            Player(name: "Henry Clark", handicapIndex: 28.0, avatarColor: .indigo)
        ]
    }()

    // MARK: Teams (Trip 2) — 4 teams of 2

    static let t2Teams: [Team] = {
        [
            Team(name: "Sharks", color: .blue),
            Team(name: "Tigers", color: .red),
            Team(name: "Hawks", color: .green),
            Team(name: "Bears", color: .gold)
        ]
    }()

    static let t2PlayersWithTeams: [Player] = {
        let p = t2Players
        // Sharks: Marcus (4) + Brandon (8)
        p[0].team = t2Teams[0]; p[1].team = t2Teams[0]
        // Tigers: Chris (12) + Derek (16)
        p[2].team = t2Teams[1]; p[3].team = t2Teams[1]
        // Hawks: Eric (20) + Frank (22)
        p[4].team = t2Teams[2]; p[5].team = t2Teams[2]
        // Bears: Greg (25) + Henry (28)
        p[6].team = t2Teams[3]; p[7].team = t2Teams[3]
        return p
    }()

    // MARK: Courses (Trip 2) — Hilton Head, SC

    // Full 18-hole courses used for the round-robin matches
    static let t2Course1: Course = {
        let pars     = [4, 5, 4, 3, 5, 4, 3, 4, 4,   4, 4, 3, 5, 4, 4, 3, 5, 4]
        let yardages = [410, 530, 395, 185, 540, 420, 175, 440, 405,
                        385, 430, 170, 525, 400, 445, 190, 555, 415]
        let hdcps    = [5, 9, 3, 15, 11, 1, 17, 7, 13,   6, 2, 18, 10, 8, 4, 16, 12, 14]
        let holes = (0..<18).map { i in
            Hole(number: i+1, par: pars[i], yardage: yardages[i], handicapRating: hdcps[i])
        }
        return Course(
            name: "Harbour Town Golf Links",
            holes: holes, slopeRating: 146, courseRating: 74.2,
            city: "Hilton Head Island", state: "SC", latitude: 32.13, longitude: -80.80,
            teamScoringRule: TeamScoringRule(
                format: .teamBestBall,
                pointsPerWin: 1.0, pointsPerHalve: 0.5, pointsPerLoss: 0.0,
                useNinesAndOverall: false
            )
        )
    }()

    static let t2Course2: Course = {
        let pars     = [4, 4, 5, 3, 4, 4, 3, 5, 4,   4, 3, 5, 4, 4, 4, 3, 4, 5]
        let yardages = [400, 415, 520, 175, 410, 395, 180, 535, 420,
                        405, 165, 510, 385, 430, 440, 195, 400, 545]
        let hdcps    = [7, 3, 11, 17, 5, 1, 15, 9, 13,   8, 18, 10, 4, 2, 6, 16, 12, 14]
        let holes = (0..<18).map { i in
            Hole(number: i+1, par: pars[i], yardage: yardages[i], handicapRating: hdcps[i])
        }
        return Course(
            name: "RTJ Course at Palmetto Dunes",
            holes: holes, slopeRating: 136, courseRating: 73.0,
            city: "Hilton Head Island", state: "SC", latitude: 32.16, longitude: -80.74,
            teamScoringRule: TeamScoringRule(
                format: .teamBestBall,
                pointsPerWin: 1.0, pointsPerHalve: 0.5, pointsPerLoss: 0.0,
                useNinesAndOverall: false
            )
        )
    }()

    static let t2Course3: Course = {
        let pars     = [4, 3, 5, 4, 4, 3, 4, 5, 4,   4, 5, 3, 4, 4, 3, 4, 5, 4]
        let yardages = [395, 170, 525, 405, 425, 185, 415, 540, 400,
                        410, 520, 175, 390, 435, 180, 420, 550, 405]
        let hdcps    = [3, 15, 9, 5, 1, 17, 7, 11, 13,   4, 10, 18, 8, 2, 16, 6, 12, 14]
        let holes = (0..<18).map { i in
            Hole(number: i+1, par: pars[i], yardage: yardages[i], handicapRating: hdcps[i])
        }
        return Course(
            name: "Oyster Reef Golf Club",
            holes: holes, slopeRating: 131, courseRating: 72.1,
            city: "Hilton Head Island", state: "SC", latitude: 32.18, longitude: -80.72,
            teamScoringRule: TeamScoringRule(
                format: .teamBestBall,
                pointsPerWin: 1.0, pointsPerHalve: 0.5, pointsPerLoss: 0.0,
                useNinesAndOverall: false
            )
        )
    }()

    // MARK: - Trip 2 Rounds (Round Robin: 6 matches across 3 courses)
    // Each round has all 8 golfers playing the same course.
    // The round-robin matchups are computed by the engine from the team pairings.

    // Also create a 4-hole "mini course" to test the edge case
    static let t2Course4Hole: Course = {
        let pars     = [4, 3, 5, 4]
        let yardages = [410, 175, 530, 395]
        let hdcps    = [1, 3, 2, 4]
        let holes = (0..<4).map { i in
            Hole(number: i+1, par: pars[i], yardage: yardages[i], handicapRating: hdcps[i])
        }
        return Course(
            name: "Harbour Town — Front 4 (Test)",
            holes: holes, slopeRating: 146, courseRating: 74.2,
            city: "Hilton Head Island", state: "SC",
            teamScoringRule: TeamScoringRule(
                format: .teamBestBall,
                pointsPerWin: 1.0, pointsPerHalve: 0.5, pointsPerLoss: 0.0
            )
        )
    }()

    // Round 1: All 8 golfers at Harbour Town
    static let t2Round1: Round = {
        let p = t2PlayersWithTeams
        let course = t2Course1
        let round = Round(course: course, date: makeDate(2025, 9, 18), format: .bestBall,
                          playerIds: p.map(\.id), isComplete: true)

        // Generate realistic scores for all 8 golfers
        let scores: [[Int]] = [
            // Marcus (4): ~74
            [4, 5, 4, 3, 5, 4, 3, 4, 4,   4, 4, 3, 5, 4, 4, 3, 5, 4],  // 72 (great round)
            // Brandon (8): ~79
            [4, 5, 5, 3, 5, 5, 3, 4, 5,   5, 4, 4, 5, 5, 4, 3, 5, 5],  // 79
            // Chris (12): ~83
            [5, 5, 5, 4, 5, 5, 3, 5, 5,   4, 5, 3, 6, 4, 5, 4, 5, 5],  // 83
            // Derek (16): ~87
            [5, 6, 5, 3, 6, 5, 4, 5, 5,   5, 5, 4, 6, 5, 5, 4, 6, 5],  // 89
            // Eric (20): ~90
            [5, 6, 5, 4, 6, 5, 4, 5, 5,   5, 5, 4, 6, 5, 5, 4, 6, 6],  // 91
            // Frank (22): ~91
            [5, 6, 5, 4, 6, 5, 4, 5, 6,   5, 5, 4, 6, 5, 6, 4, 6, 5],  // 92
            // Greg (25): ~95
            [6, 6, 5, 4, 6, 5, 5, 5, 6,   5, 6, 4, 7, 5, 5, 4, 6, 6],  // 96
            // Henry (28): ~98
            [6, 7, 5, 4, 7, 6, 4, 6, 6,   6, 5, 5, 7, 5, 6, 5, 6, 6],  // 100 (tough day)
        ]
        let defaultPutts = [2, 2, 2, 2, 2, 2, 2, 2, 2,   2, 2, 2, 2, 2, 2, 2, 2, 2]

        round.scorecards = p.enumerated().map { i, player in
            buildScorecard(round: round, player: player, course: course, grossScores: scores[i], putts: defaultPutts)
        }
        return round
    }()

    // Round 2: All 8 golfers at RTJ Palmetto Dunes
    static let t2Round2: Round = {
        let p = t2PlayersWithTeams
        let course = t2Course2
        let round = Round(course: course, date: makeDate(2025, 9, 19), format: .bestBall,
                          playerIds: p.map(\.id), isComplete: true)

        let scores: [[Int]] = [
            // Marcus (4): 75
            [4, 4, 5, 3, 5, 4, 3, 5, 4,   4, 3, 6, 4, 5, 4, 3, 4, 5],
            // Brandon (8): 80
            [5, 4, 5, 3, 5, 4, 4, 5, 5,   4, 4, 5, 5, 5, 5, 3, 4, 5],
            // Chris (12): 81
            [4, 5, 5, 3, 5, 4, 3, 5, 5,   5, 4, 5, 5, 4, 5, 3, 4, 6],
            // Derek (16): 86
            [5, 5, 6, 4, 5, 5, 3, 5, 5,   5, 4, 5, 5, 5, 5, 4, 4, 6],
            // Eric (20): 89
            [5, 5, 5, 4, 5, 5, 4, 6, 5,   5, 4, 6, 5, 5, 5, 4, 5, 6],
            // Frank (22): 91
            [5, 5, 6, 4, 5, 5, 4, 6, 5,   5, 4, 6, 6, 5, 5, 4, 5, 6],
            // Greg (25): 94
            [5, 5, 6, 4, 6, 5, 4, 6, 6,   5, 4, 6, 6, 5, 6, 4, 5, 6],
            // Henry (28): 98
            [6, 5, 6, 5, 6, 5, 4, 6, 6,   6, 4, 7, 6, 6, 6, 5, 5, 6],
        ]
        let defaultPutts = [2, 2, 2, 2, 2, 2, 2, 2, 2,   2, 2, 2, 2, 2, 2, 2, 2, 2]

        round.scorecards = p.enumerated().map { i, player in
            buildScorecard(round: round, player: player, course: course, grossScores: scores[i], putts: defaultPutts)
        }
        return round
    }()

    // Round 3: All 8 golfers at Oyster Reef
    static let t2Round3: Round = {
        let p = t2PlayersWithTeams
        let course = t2Course3
        let round = Round(course: course, date: makeDate(2025, 9, 20), format: .bestBall,
                          playerIds: p.map(\.id), isComplete: true)

        let scores: [[Int]] = [
            // Marcus (4): 73 (strong finish)
            [4, 3, 5, 4, 4, 3, 4, 5, 4,   4, 5, 3, 4, 4, 3, 4, 5, 4],
            // Brandon (8): 78
            [4, 3, 5, 5, 5, 3, 4, 5, 5,   4, 5, 3, 5, 4, 3, 5, 5, 4],
            // Chris (12): 82
            [5, 3, 5, 5, 5, 4, 4, 5, 5,   4, 5, 4, 5, 4, 4, 4, 5, 5],
            // Derek (16): 87
            [5, 4, 6, 5, 5, 4, 4, 5, 5,   5, 5, 4, 5, 5, 4, 4, 6, 5],
            // Eric (20): 88
            [5, 4, 5, 5, 5, 3, 5, 6, 5,   4, 6, 4, 5, 5, 4, 5, 5, 5],
            // Frank (22): 90
            [5, 4, 6, 5, 5, 4, 5, 5, 5,   5, 6, 4, 5, 5, 3, 4, 6, 6],
            // Greg (25): 95
            [6, 4, 6, 5, 5, 4, 5, 6, 6,   5, 6, 4, 5, 5, 4, 5, 7, 5],
            // Henry (28): 99
            [6, 4, 7, 6, 6, 4, 5, 6, 6,   5, 6, 5, 6, 5, 4, 5, 7, 6],
        ]
        let defaultPutts = [2, 2, 2, 2, 2, 2, 2, 2, 2,   2, 2, 2, 2, 2, 2, 2, 2, 2]

        round.scorecards = p.enumerated().map { i, player in
            buildScorecard(round: round, player: player, course: course, grossScores: scores[i], putts: defaultPutts)
        }
        return round
    }()

    // MARK: - 4-Hole Edge Case Round (Trip 2 bonus)
    static let t2Round4Hole: Round = {
        let p = t2PlayersWithTeams
        let course = t2Course4Hole
        let round = Round(course: course, date: makeDate(2025, 9, 21), format: .bestBall,
                          playerIds: Array(p[0...3].map(\.id)),  // Only first 4 golfers
                          isComplete: true)

        let scores: [[Int]] = [
            [4, 3, 5, 4],  // Marcus: 16
            [5, 3, 5, 5],  // Brandon: 18
            [5, 4, 5, 5],  // Chris: 19
            [5, 4, 6, 5],  // Derek: 20
        ]
        let putts4 = [2, 2, 2, 2]

        round.scorecards = (0..<4).map { i in
            buildScorecard(round: round, player: p[i], course: course, grossScores: scores[i], putts: putts4)
        }
        return round
    }()

    // MARK: - Side Bets (Trip 2)

    static let t2SideBets: [SideBet] = {
        let p = t2PlayersWithTeams
        return [
            // First birdie of the tournament
            {
                let bet = SideBet(
                    name: "First Birdie of Tournament",
                    betType: .custom,
                    participants: p.map(\.id),
                    stake: "$5 each",
                    status: .completed,
                    winnerId: p[0].id,  // Marcus
                    isPotBet: true, potAmount: 5,
                    round: t2Round1
                )
                bet.customMetricName = "Hole Number"
                bet.customHighestWins = false
                var vals: [UUID: Double] = [:]
                vals[p[0].id] = 1  // Marcus birdied hole 1
                bet.customValues = vals
                return bet
            }(),

            // Most Birdies across all rounds
            {
                let bet = SideBet(
                    name: "Most Birdies (All Rounds)",
                    betType: .mostBirdies,
                    participants: p.map(\.id),
                    stake: "$20 per player",
                    status: .completed,
                    winnerId: p[0].id,  // Marcus dominates
                    isPotBet: true, potAmount: 20
                )
                return bet
            }(),

            // Closest to the pin — specific hole
            {
                let bet = SideBet(
                    name: "CTP — Hole 4 (Par 3)",
                    betType: .custom,
                    participants: p.map(\.id),
                    stake: "$10 each",
                    status: .completed,
                    winnerId: p[3].id,  // Derek surprise win
                    isPotBet: true, potAmount: 10,
                    round: t2Round1
                )
                bet.customMetricName = "Distance (feet)"
                bet.customHighestWins = false
                var vals: [UUID: Double] = [:]
                vals[p[0].id] = 15.0
                vals[p[1].id] = 22.0
                vals[p[2].id] = 8.5
                vals[p[3].id] = 3.2  // Derek stiffs it!
                vals[p[4].id] = 18.0
                vals[p[5].id] = 25.0
                vals[p[6].id] = 30.0
                vals[p[7].id] = 42.0
                bet.customValues = vals
                return bet
            }(),

            // Low Individual Round
            {
                let bet = SideBet(
                    name: "Low Round — Tournament",
                    betType: .lowRound,
                    participants: p.map(\.id),
                    stake: "Champion's belt",
                    status: .completed,
                    winnerId: p[0].id  // Marcus' 72 at Harbour Town
                )
                return bet
            }()
        ]
    }()

    // MARK: - Trip 2 Assembly

    static let trip2: Trip = {
        let p = t2PlayersWithTeams

        let trip = Trip(
            name: "Hilton Head Classic 2025",
            startDate: makeDate(2025, 9, 18),
            endDate: makeDate(2025, 9, 21),
            players: p,
            teams: t2Teams,
            courses: [t2Course1, t2Course2, t2Course3, t2Course4Hole],
            rounds: [t2Round1, t2Round2, t2Round3, t2Round4Hole],
            sideGames: [],
            ownerProfileId: userProfile.id,
            sideBets: t2SideBets,
            pointsPerMatchWin: 1.0,
            pointsPerMatchHalve: 0.5,
            pointsPerMatchLoss: 0.0
        )

        // War Room events
        let events = [
            WarRoomEvent(type: .flight, title: "Group 1 Arrives", subtitle: "AA from Charlotte",
                         dateTime: makeDateTime(2025, 9, 18, 9, 0), location: "SAV Airport",
                         playerIds: Array(p[0...3].map(\.id))),
            WarRoomEvent(type: .teeTime, title: "Round 1 — Harbour Town", subtitle: "10:30 AM",
                         dateTime: makeDateTime(2025, 9, 18, 10, 30), location: "Harbour Town GL",
                         playerIds: p.map(\.id)),
            WarRoomEvent(type: .dinner, title: "Welcome Dinner", subtitle: "Skull Creek Boathouse",
                         dateTime: makeDateTime(2025, 9, 18, 19, 0), location: "Skull Creek Boathouse",
                         playerIds: p.map(\.id)),
            WarRoomEvent(type: .teeTime, title: "Round 2 — RTJ Palmetto Dunes", subtitle: "9:00 AM",
                         dateTime: makeDateTime(2025, 9, 19, 9, 0), location: "Palmetto Dunes",
                         playerIds: p.map(\.id)),
            WarRoomEvent(type: .teeTime, title: "Round 3 — Oyster Reef", subtitle: "9:00 AM",
                         dateTime: makeDateTime(2025, 9, 20, 9, 0), location: "Oyster Reef GC",
                         playerIds: p.map(\.id)),
            WarRoomEvent(type: .activity, title: "Awards Ceremony & Beers", subtitle: "Final night celebration",
                         dateTime: makeDateTime(2025, 9, 20, 18, 0), location: "The Salty Dog Cafe",
                         playerIds: p.map(\.id)),
        ]
        for e in events { trip.addWarRoomEvent(e) }

        return trip
    }()

    // ============================================================
    // MARK: - Date Helpers
    // ============================================================

    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func makeDateTime(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        components.hour = hour; components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    // ============================================================
    // MARK: - QA AppState Factory
    // ============================================================

    /// Creates an AppState pre-loaded with both QA trips.
    /// Pass `tripIndex: 0` for Trip 1 (Raleigh) or `tripIndex: 1` for Trip 2 (Hilton Head).
    static func makeAppState(tripIndex: Int = 0) -> AppState {
        let state = AppState()
        state.currentUser = userProfile
        state.trips = [trip1, trip2]
        state.currentTrip = tripIndex == 0 ? trip1 : trip2
        return state
    }
}
