import Foundation
import SwiftData

enum SampleData {
    // MARK: - User Profile (simulates device owner)

    static let sampleUserProfile: UserProfile = {
        UserProfile(
            name: "Alex Anderson",
            handicapIndex: 12.4,
            avatarColor: .blue
        )
    }()

    static let players: [Player] = [
        Player(name: "Alex Anderson", handicapIndex: 12.4, avatarColor: .blue, userProfileId: sampleUserProfile.id),
        Player(name: "Mike Johnson", handicapIndex: 8.2, avatarColor: .green),
        Player(name: "Chris Williams", handicapIndex: 18.6, avatarColor: .red),
        Player(name: "Dave Thompson", handicapIndex: 5.1, avatarColor: .orange)
    ]

    static let teams: [Team] = {
        let team1 = Team(name: "Eagles", color: .blue)
        let team2 = Team(name: "Birdies", color: .red)
        return [team1, team2]
    }()

    static let playersWithTeams: [Player] = {
        let p = players
        p[0].team = teams[0]
        p[1].team = teams[0]
        p[2].team = teams[1]
        p[3].team = teams[1]
        return p
    }()

    static let course: Course = {
        let pars = [4, 3, 5, 4, 4, 3, 4, 5, 4, 4, 3, 4, 5, 4, 4, 3, 5, 4]
        let yardages = [385, 165, 520, 410, 375, 190, 430, 545, 395, 405, 175, 420, 510, 390, 365, 200, 530, 415]
        let holes = (0..<18).map { i in
            Hole(number: i + 1, par: pars[i], yardage: yardages[i], handicapRating: i + 1)
        }
        return Course(
            name: "Pine Valley Golf Club",
            holes: holes,
            slopeRating: 135,
            courseRating: 72.4,
            city: "Scottsdale",
            state: "AZ",
            latitude: 33.45,
            longitude: -111.95
        )
    }()

    static let round: Round = {
        let p = playersWithTeams

        let roundObj = Round(
            course: course,
            format: .strokePlay,
            playerIds: p.map(\.id)
        )

        let scorecards = p.map { player in
            let courseHandicap = HandicapEngine.courseHandicap(
                handicapIndex: player.handicapIndex,
                slopeRating: course.slopeRating,
                courseRating: course.courseRating,
                par: course.totalPar
            )
            let card = Scorecard.createEmpty(
                round: roundObj,
                player: player,
                courseHandicap: courseHandicap,
                holes: course.holes
            )
            // Fill in some scores for first 9 holes
            for i in 0..<9 {
                let par = course.holes[i].par
                let score = par + Int.random(in: -1...2)
                card.holeScores[i].strokes = max(1, score)
                card.holeScores[i].putts = Int.random(in: 1...3)
            }
            return card
        }

        roundObj.scorecards = scorecards
        return roundObj
    }()

    static let sideGame: SideGame = {
        SideGame(
            type: .skins,
            round: round,
            participantIds: playersWithTeams.map(\.id),
            stakes: 5
        )
    }()

    // MARK: - War Room Sample Data

    static let warRoomEvents: [WarRoomEvent] = {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today)!
        let day3 = calendar.date(byAdding: .day, value: 3, to: today)!

        return [
            WarRoomEvent(
                type: .flight,
                title: "Alex & Mike Arrive",
                subtitle: "AA 1847 from DFW",
                dateTime: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: today)!,
                location: "Phoenix Sky Harbor (PHX)",
                playerIds: [playersWithTeams[0].id, playersWithTeams[1].id]
            ),
            WarRoomEvent(
                type: .hotel,
                title: "Hotel Check-In",
                subtitle: "Scottsdale Resort & Spa",
                dateTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today)!,
                location: "7700 E McCormick Pkwy",
                playerIds: playersWithTeams.map(\.id)
            ),
            WarRoomEvent(
                type: .dinner,
                title: "Welcome Dinner",
                subtitle: "Steakhouse night",
                dateTime: calendar.date(bySettingHour: 19, minute: 30, second: 0, of: today)!,
                location: "Dominick's Steakhouse",
                playerIds: playersWithTeams.map(\.id)
            ),
            WarRoomEvent(
                type: .teeTime,
                title: "Round 1 - Pine Valley",
                subtitle: "Shotgun Start",
                dateTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)!,
                endDateTime: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: tomorrow)!,
                location: "Pine Valley Golf Club",
                notes: "Cart fees included. Bring sunscreen!",
                playerIds: playersWithTeams.map(\.id)
            ),
            WarRoomEvent(
                type: .dinner,
                title: "Tacos & Margs",
                subtitle: "Post-round celebration",
                dateTime: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow)!,
                location: "Diego Pops",
                playerIds: playersWithTeams.map(\.id)
            ),
            WarRoomEvent(
                type: .teeTime,
                title: "Round 2 - TPC Scottsdale",
                subtitle: "Stadium Course",
                dateTime: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: dayAfter)!,
                endDateTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: dayAfter)!,
                location: "TPC Scottsdale",
                playerIds: playersWithTeams.map(\.id)
            ),
            WarRoomEvent(
                type: .flight,
                title: "Departure",
                subtitle: "Don't miss your flights!",
                dateTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day3)!,
                location: "Phoenix Sky Harbor (PHX)",
                playerIds: playersWithTeams.map(\.id)
            )
        ]
    }()

    static let travelStatuses: [TravelStatus] = {
        let p = playersWithTeams
        return [
            TravelStatus(
                player: p[0],
                status: .atHotel,
                updatedAt: Date().addingTimeInterval(-1800),
                flightInfo: "AA 1847"
            ),
            TravelStatus(
                player: p[1],
                status: .landed,
                updatedAt: Date().addingTimeInterval(-3600),
                flightInfo: "AA 1847"
            ),
            TravelStatus(
                player: p[2],
                status: .enRoute,
                updatedAt: Date().addingTimeInterval(-7200),
                flightInfo: "UA 442"
            ),
            TravelStatus(
                player: p[3],
                status: .atCourse,
                updatedAt: Date().addingTimeInterval(-600)
            )
        ]
    }()

    static let samplePoll: Poll = {
        Poll(
            question: "Which course should we play Saturday?",
            options: [
                PollOption(text: "TPC Scottsdale", voterIds: [playersWithTeams[0].id, playersWithTeams[1].id]),
                PollOption(text: "Troon North", voterIds: [playersWithTeams[2].id]),
                PollOption(text: "We-Ko-Pa", voterIds: [])
            ]
        )
    }()

    // MARK: - Challenges Sample Data

    static let sampleSideBets: [SideBet] = {
        let p = playersWithTeams
        return [
            SideBet(
                name: "Low Round Day 1",
                betType: .lowRound,
                participants: p.map(\.id),
                stake: "Bragging Rights",
                round: round
            ),
            SideBet(
                name: "Alex vs Mike",
                betType: .headToHeadRound,
                participants: [p[0].id, p[1].id],
                stake: "Buys dinner",
                round: round
            )
        ]
    }()

    // MARK: - Trip with all data

    static let trip: Trip = {
        Trip(
            name: "Scottsdale Boys Trip 2026",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            players: playersWithTeams,
            teams: teams,
            courses: [course],
            rounds: [round],
            sideGames: [sideGame],
            ownerProfileId: sampleUserProfile.id,
            warRoomEvents: warRoomEvents,
            travelStatuses: travelStatuses,
            polls: [samplePoll],
            sideBets: sampleSideBets
        )
    }()

    // MARK: - Preview ModelContainer (in-memory)

    @MainActor
    static let previewContainer: ModelContainer = {
        let schema = Schema([
            Trip.self, UserProfile.self, Course.self, Round.self,
            Scorecard.self, Player.self, Team.self, SideGame.self,
            WarRoomEvent.self, TravelStatus.self, Poll.self,
            SideBet.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("[SampleData] Could not create preview ModelContainer: \(error)")
        }
    }()

    // MARK: - AppState with sample data

    static func makeAppState() -> AppState {
        let state = AppState()
        state.currentUser = sampleUserProfile
        state.trips = [trip]
        state.currentTrip = trip
        return state
    }

    static func makeEmptyAppState() -> AppState {
        AppState()
    }

    static func makeTripViewModel(appState: AppState? = nil) -> TripViewModel {
        TripViewModel(appState: appState ?? makeAppState())
    }

    static func makeScorecardViewModel(appState: AppState? = nil) -> ScorecardViewModel {
        ScorecardViewModel(appState: appState ?? makeAppState())
    }

    static func makeLeaderboardViewModel(appState: AppState? = nil) -> LeaderboardViewModel {
        LeaderboardViewModel(appState: appState ?? makeAppState())
    }

    static func makeSideGameViewModel(appState: AppState? = nil) -> SideGameViewModel {
        SideGameViewModel(appState: appState ?? makeAppState())
    }

    static func makeWarRoomViewModel(appState: AppState? = nil) -> WarRoomViewModel {
        WarRoomViewModel(appState: appState ?? makeAppState())
    }

    static func makeChallengesViewModel(appState: AppState? = nil) -> ChallengesViewModel {
        ChallengesViewModel(appState: appState ?? makeAppState())
    }
}
