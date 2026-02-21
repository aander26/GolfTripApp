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

    // MARK: - Metrics & Challenges Sample Data

    static let sampleMetrics: [Metric] = {
        // Create new instances (don't use presets directly since those are templates)
        let birdies = Metric(name: "Birdies", icon: "🐦", unit: "birdies", trackingType: .perRound, category: .onCourse, higherIsBetter: true)
        let putts = Metric(name: "Total Putts", icon: "🏌️", unit: "putts", trackingType: .perRound, category: .onCourse, higherIsBetter: false)
        let fairways = Metric(name: "Fairways Hit", icon: "🎯", unit: "fairways", trackingType: .perRound, category: .onCourse, higherIsBetter: true)
        let beers = Metric(name: "Beers Consumed", icon: "🍺", unit: "beers", trackingType: .perDay, category: .offCourse, higherIsBetter: true)
        let sleep = Metric(name: "Hours Slept", icon: "😴", unit: "hours", trackingType: .perDay, category: .offCourse, higherIsBetter: false)
        let steps = Metric(name: "Steps Walked", icon: "👟", unit: "steps", trackingType: .perDay, category: .offCourse, higherIsBetter: true)
        return [birdies, putts, fairways, beers, sleep, steps]
    }()

    static let sampleMetricEntries: [MetricEntry] = {
        let metrics = sampleMetrics
        let p = playersWithTeams
        let r = round

        return [
            // Birdies
            MetricEntry(metric: metrics[0], member: p[0], value: 2, round: r),
            MetricEntry(metric: metrics[0], member: p[1], value: 3, round: r),
            MetricEntry(metric: metrics[0], member: p[2], value: 1, round: r),
            MetricEntry(metric: metrics[0], member: p[3], value: 4, round: r),
            // Total Putts
            MetricEntry(metric: metrics[1], member: p[0], value: 32, round: r),
            MetricEntry(metric: metrics[1], member: p[1], value: 29, round: r),
            MetricEntry(metric: metrics[1], member: p[2], value: 35, round: r),
            MetricEntry(metric: metrics[1], member: p[3], value: 28, round: r),
            // Beers
            MetricEntry(metric: metrics[3], member: p[0], value: 4, date: Date().addingTimeInterval(-86400)),
            MetricEntry(metric: metrics[3], member: p[1], value: 6, date: Date().addingTimeInterval(-86400)),
            MetricEntry(metric: metrics[3], member: p[2], value: 3, date: Date().addingTimeInterval(-86400)),
            MetricEntry(metric: metrics[3], member: p[3], value: 8, date: Date().addingTimeInterval(-86400), notes: "Welcome dinner went hard"),
            // Sleep
            MetricEntry(metric: metrics[4], member: p[0], value: 7.5, date: Date().addingTimeInterval(-86400)),
            MetricEntry(metric: metrics[4], member: p[1], value: 6.0, date: Date().addingTimeInterval(-86400)),
            MetricEntry(metric: metrics[4], member: p[2], value: 8.5, date: Date().addingTimeInterval(-86400)),
            MetricEntry(metric: metrics[4], member: p[3], value: 5.0, date: Date().addingTimeInterval(-86400), notes: "Dave was up late")
        ]
    }()

    static let sampleSideBets: [SideBet] = {
        let p = playersWithTeams
        let metrics = sampleMetrics
        return [
            SideBet(
                name: "Most Birdies",
                metric: metrics[0],
                betType: .highestTotal,
                participants: p.map(\.id),
                stake: "Bragging Rights"
            ),
            SideBet(
                name: "Fewest Putts",
                metric: metrics[1],
                betType: .lowestTotal,
                participants: p.map(\.id),
                stake: "Buys dinner"
            ),
            SideBet(
                name: "Beer King",
                metric: metrics[3],
                betType: .highestTotal,
                participants: p.map(\.id),
                stake: "Wears the visor"
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
            metrics: sampleMetrics,
            metricEntries: sampleMetricEntries,
            sideBets: sampleSideBets
        )
    }()

    static let weather: WeatherData = WeatherData(
        temperature: 78,
        feelsLike: 80,
        humidity: 35,
        windSpeed: 8,
        windDirection: 225,
        windGust: 14,
        condition: .fewClouds,
        description: "Partly cloudy",
        icon: "02d",
        visibility: 10000,
        precipitationChance: 0.1,
        uvIndex: 7,
        sunrise: Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()),
        sunset: Calendar.current.date(bySettingHour: 18, minute: 45, second: 0, of: Date()),
        fetchedAt: Date()
    )

    // MARK: - Preview ModelContainer (in-memory)

    @MainActor
    static let previewContainer: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Trip.self, UserProfile.self, configurations: config)
        return container
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

    static func makeWeatherViewModel(appState: AppState? = nil) -> WeatherViewModel {
        let vm = WeatherViewModel(appState: appState ?? makeAppState())
        vm.currentWeather = weather
        return vm
    }

    static func makeWarRoomViewModel(appState: AppState? = nil) -> WarRoomViewModel {
        WarRoomViewModel(appState: appState ?? makeAppState())
    }

    static func makeMetricsViewModel(appState: AppState? = nil) -> MetricsViewModel {
        MetricsViewModel(appState: appState ?? makeAppState())
    }
}
