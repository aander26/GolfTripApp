import Foundation
import SwiftUI

@MainActor @Observable
class DailyRecapViewModel {
    var appState: AppState
    var selectedDayIndex: Int = 0

    init(appState: AppState) {
        self.appState = appState
        // Default to today if within trip dates, otherwise last day
        if let trip = appState.currentTrip {
            let days = Self.computeTripDays(trip: trip)
            let today = Calendar.current.startOfDay(for: Date())
            if let todayIdx = days.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
                selectedDayIndex = todayIdx
            } else if !days.isEmpty {
                selectedDayIndex = days.count - 1
            }
        }
    }

    var currentTrip: Trip? {
        appState.currentTrip
    }

    // MARK: - Day Navigation

    var tripDays: [Date] {
        guard let trip = currentTrip else { return [] }
        return Self.computeTripDays(trip: trip)
    }

    var selectedDay: Date? {
        let days = tripDays
        // Clamp to valid range in case trip changed and index is now out of bounds
        guard !days.isEmpty else { return nil }
        let clamped = min(selectedDayIndex, days.count - 1)
        if clamped != selectedDayIndex {
            selectedDayIndex = clamped
        }
        return days[clamped]
    }

    var dayNumber: Int {
        selectedDayIndex + 1
    }

    var formattedDayDate: String {
        guard let day = selectedDay else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: day)
    }

    private static func computeTripDays(trip: Trip) -> [Date] {
        let calendar = Calendar.current
        var days: [Date] = []
        var current = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        while current <= end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86400)
        }
        return days
    }

    // MARK: - Rounds for Selected Day

    var roundsForDay: [Round] {
        guard let trip = currentTrip, let day = selectedDay else { return [] }
        let calendar = Calendar.current
        return trip.rounds.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    var completedRoundsForDay: [Round] {
        roundsForDay.filter { $0.isComplete }
    }

    // MARK: - Round Leaderboards

    func leaderboard(for round: Round) -> [LeaderboardEntry] {
        guard let trip = currentTrip, let course = round.course else { return [] }
        return LeaderboardEngine.generateRoundLeaderboard(round: round, course: course, players: trip.players)
    }

    // MARK: - Match Play Results

    func matchResults(for round: Round) -> RoundTeamMatchResult? {
        guard let trip = currentTrip,
              let course = round.course,
              trip.teams.count >= 2 else { return nil }
        let rule = TeamMatchPlayEngine.resolveScoringRule(round: round, trip: trip)
        return TeamMatchPlayEngine.calculateRoundResults(
            round: round, course: course, players: trip.players, teams: trip.teams, scoringRule: rule
        )
    }

    // MARK: - Awards / Superlatives

    struct RecapAward: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let playerName: String
        let detail: String
        let isRoast: Bool // true = red/roast card, false = green/glory card
    }

    /// Cached awards to avoid expensive recomputation on every view update.
    /// Invalidated when the selected day or trip data changes.
    private var _cachedAwards: [RecapAward]?
    private var _cachedAwardsDayIndex: Int = -1
    private var _cachedAwardsRoundCount: Int = -1

    var awards: [RecapAward] {
        // Return cache if still valid (same day, same number of completed rounds)
        let roundCount = completedRoundsForDay.count
        if let cached = _cachedAwards,
           _cachedAwardsDayIndex == selectedDayIndex,
           _cachedAwardsRoundCount == roundCount {
            return cached
        }
        let result = computeAwards()
        _cachedAwards = result
        _cachedAwardsDayIndex = selectedDayIndex
        _cachedAwardsRoundCount = roundCount
        return result
    }

    private func computeAwards() -> [RecapAward] {
        guard let trip = currentTrip else { return [] }
        var results: [RecapAward] = []

        // Gather all scorecards from completed rounds today
        let todayCards: [(Player, Scorecard, Course)] = completedRoundsForDay.flatMap { round in
            guard let course = round.course else { return [(Player, Scorecard, Course)]() }
            return round.completedScorecards.compactMap { card in
                guard let player = card.player else { return nil }
                return (player, card, course)
            }
        }

        guard !todayCards.isEmpty else { return [] }
        let firstName = { (name: String) -> String in
            name.split(separator: " ").first.map(String.init) ?? name
        }

        // --- GLORY AWARDS ---

        // Low Round King
        if let best = todayCards.min(by: { $0.1.totalNet < $1.1.totalNet }) {
            let scoreToPar = best.1.totalNet - best.2.totalPar
            let parText = scoreToPar == 0 ? "E" : (scoreToPar > 0 ? "+\(scoreToPar)" : "\(scoreToPar)")
            results.append(RecapAward(
                emoji: "👑",
                title: "Low Round King",
                playerName: firstName(best.0.name),
                detail: "\(best.1.totalNet) net (\(parText)) — bow down",
                isRoast: false
            ))
        }

        // Birdie Machine
        let birdieCounts = todayCards.map { (player, card, _) in
            (player, card.holeScores.filter { $0.isCompleted && $0.scoreToPar <= -1 }.count)
        }
        if let best = birdieCounts.max(by: { $0.1 < $1.1 }), best.1 > 0 {
            let quip = best.1 >= 4 ? "On a heater" : (best.1 >= 2 ? "Red numbers all day" : "Got one to drop")
            results.append(RecapAward(
                emoji: "🐦",
                title: "Birdie Machine",
                playerName: firstName(best.0.name),
                detail: "\(best.1) birdie\(best.1 == 1 ? "" : "s") — \(quip)",
                isRoast: false
            ))
        }

        // The Grinder
        let parCounts = todayCards.map { (player, card, _) in
            (player, card.holeScores.filter { $0.isCompleted && $0.scoreToPar == 0 }.count)
        }
        if let best = parCounts.max(by: { $0.1 < $1.1 }), best.1 > 0 {
            results.append(RecapAward(
                emoji: "💪",
                title: "The Grinder",
                playerName: firstName(best.0.name),
                detail: "\(best.1) pars — boring but effective",
                isRoast: false
            ))
        }

        // Flat Stick Wizard
        let puttCounts = todayCards.map { (player, card, _) in
            (player, card.totalPutts)
        }.filter { $0.1 > 0 }
        if let best = puttCounts.min(by: { $0.1 < $1.1 }) {
            results.append(RecapAward(
                emoji: "🎯",
                title: "Flat Stick Wizard",
                playerName: firstName(best.0.name),
                detail: "\(best.1) putts — rolling it pure",
                isRoast: false
            ))
        }

        // Hot Start
        if let best = todayCards.min(by: { $0.1.frontNineGross < $1.1.frontNineGross }),
           best.1.frontNineGross > 0 {
            results.append(RecapAward(
                emoji: "🔥",
                title: "Hot Start",
                playerName: firstName(best.0.name),
                detail: "\(best.1.frontNineGross) on the front — came out swinging",
                isRoast: false
            ))
        }

        // --- ROAST AWARDS ---

        // Cellar Dweller — highest net score (worst round)
        if let worst = todayCards.max(by: { $0.1.totalNet < $1.1.totalNet }),
           todayCards.count > 1 {
            let scoreToPar = worst.1.totalNet - worst.2.totalPar
            let parText = scoreToPar > 0 ? "+\(scoreToPar)" : "\(scoreToPar)"
            let quips = [
                "At least you had fun?",
                "The course won today",
                "A learning experience",
                "Someone had to finish last",
                "Character building round"
            ]
            results.append(RecapAward(
                emoji: "🪣",
                title: "Cellar Dweller",
                playerName: firstName(worst.0.name),
                detail: "\(worst.1.totalNet) net (\(parText)) — \(quips[abs(scoreToPar) % quips.count])",
                isRoast: true
            ))
        }

        // Snowman Alert — highest single hole score (only if >= 7)
        let worstHoles = todayCards.compactMap { (player, card, _) -> (Player, Int, Int)? in
            guard let worst = card.holeScores.filter({ $0.isCompleted }).max(by: { $0.strokes < $1.strokes }),
                  worst.strokes >= 7 else { return nil }
            return (player, worst.strokes, worst.holeNumber)
        }
        if let snowman = worstHoles.max(by: { $0.1 < $1.1 }) {
            let quips = [
                "We don't talk about this one",
                "Lost a sleeve on that hole",
                "The group chat went silent",
                "Witnesses say it was painful",
                "A bold strategy"
            ]
            results.append(RecapAward(
                emoji: "☃️",
                title: snowman.1 >= 9 ? "Total Disaster" : "Snowman Alert",
                playerName: firstName(snowman.0.name),
                detail: "\(snowman.1) on hole \(snowman.2) — \(quips[snowman.2 % quips.count])",
                isRoast: true
            ))
        }

        // Three-Putt King — most 3-putts
        let threePuttCounts = todayCards.map { (player, card, _) in
            (player, card.holeScores.filter { $0.isCompleted && $0.putts >= 3 }.count)
        }
        if let worst = threePuttCounts.max(by: { $0.1 < $1.1 }), worst.1 >= 2 {
            results.append(RecapAward(
                emoji: "🧱",
                title: "Three-Putt King",
                playerName: firstName(worst.0.name),
                detail: "\(worst.1) three-putts — the yips are real",
                isRoast: true
            ))
        }

        // Bogey Train — most bogeys or worse
        let bogeyCounts = todayCards.map { (player, card, _) in
            (player, card.holeScores.filter { $0.isCompleted && $0.scoreToPar >= 1 }.count)
        }
        if let worst = bogeyCounts.max(by: { $0.1 < $1.1 }), worst.1 >= 6 {
            let quips = [
                "Couldn't stop the bleeding",
                "Very consistent... at making bogeys",
                "The wheels came off",
                "Somewhere a golf instructor is weeping"
            ]
            results.append(RecapAward(
                emoji: "🚂",
                title: "Bogey Train",
                playerName: firstName(worst.0.name),
                detail: "\(worst.1) bogeys+ — \(quips[worst.1 % quips.count])",
                isRoast: true
            ))
        }

        // Back Nine Meltdown — worst back 9 vs front 9 collapse
        let collapses = todayCards.compactMap { (player, card, _) -> (Player, Int)? in
            guard card.frontNineGross > 0, card.backNineGross > 0 else { return nil }
            let diff = card.backNineGross - card.frontNineGross
            return diff >= 6 ? (player, diff) : nil
        }
        if let worst = collapses.max(by: { $0.1 < $1.1 }) {
            results.append(RecapAward(
                emoji: "📉",
                title: "Back 9 Meltdown",
                playerName: firstName(worst.0.name),
                detail: "+\(worst.1) strokes on the back — what happened out there?",
                isRoast: true
            ))
        }

        // --- MONEY AWARDS ---

        let settlement = SettlementEngine.generateSettlement(trip: trip)
        if let richest = settlement.playerBalances.max(by: { $0.netBalance < $1.netBalance }),
           richest.netBalance > 0 {
            results.append(RecapAward(
                emoji: "💰",
                title: "Money Bags",
                playerName: richest.playerName.split(separator: " ").first.map(String.init) ?? richest.playerName,
                detail: "\(richest.formattedBalance) — collecting rent",
                isRoast: false
            ))
        }
        if let poorest = settlement.playerBalances.min(by: { $0.netBalance < $1.netBalance }),
           poorest.netBalance < 0 {
            results.append(RecapAward(
                emoji: "🕳️",
                title: "Down Bad",
                playerName: poorest.playerName.split(separator: " ").first.map(String.init) ?? poorest.playerName,
                detail: "\(poorest.formattedBalance) — wallet on life support",
                isRoast: true
            ))
        }

        return results
    }

    // MARK: - Commentary / Trash Talk

    struct RecapCommentary: Identifiable {
        let id = UUID()
        let text: String
    }

    var commentary: [RecapCommentary] {
        guard currentTrip != nil else { return [] }
        var lines: [RecapCommentary] = []

        let todayCards: [(Player, Scorecard, Course)] = completedRoundsForDay.flatMap { round in
            guard let course = round.course else { return [(Player, Scorecard, Course)]() }
            return round.completedScorecards.compactMap { card in
                guard let player = card.player else { return nil }
                return (player, card, course)
            }
        }

        guard todayCards.count >= 2 else { return [] }

        let firstName = { (name: String) -> String in
            name.split(separator: " ").first.map(String.init) ?? name
        }

        // Biggest blowout — gap between 1st and last
        let sorted = todayCards.sorted { $0.1.totalGross < $1.1.totalGross }
        guard let best = sorted.first, let worst = sorted.last else { return [] }
        let gap = worst.1.totalGross - best.1.totalGross
        if gap >= 10 {
            lines.append(RecapCommentary(
                text: "📢 \(firstName(best.0.name)) beat \(firstName(worst.0.name)) by \(gap) strokes. That's not a round, that's a hostage situation."
            ))
        } else if gap >= 5 {
            lines.append(RecapCommentary(
                text: "📢 \(firstName(worst.0.name)) finished \(gap) strokes behind \(firstName(best.0.name)). Might want to hit the range tonight."
            ))
        }

        // Front/back 9 collapse callout
        for (player, card, _) in todayCards {
            guard card.frontNineGross > 0, card.backNineGross > 0 else { continue }
            let diff = card.backNineGross - card.frontNineGross
            if diff >= 8 {
                lines.append(RecapCommentary(
                    text: "🍺 \(firstName(player.name)) shot \(card.frontNineGross) on the front and \(card.backNineGross) on the back. Someone check if the beer cart got to them on the turn."
                ))
                break
            }
        }

        // Eagle/Ace callout
        for (player, card, _) in todayCards {
            for hole in card.holeScores where hole.isCompleted {
                if hole.strokes == 1 {
                    lines.append(RecapCommentary(
                        text: "🚨 HOLE IN ONE! \(firstName(player.name)) aced hole \(hole.holeNumber)! Drinks are on them tonight!"
                    ))
                } else if hole.scoreToPar <= -2 {
                    let label = hole.scoreToPar == -2 ? "eagle" : "albatross"
                    lines.append(RecapCommentary(
                        text: "🦅 \(firstName(player.name)) made \(label) on hole \(hole.holeNumber). Show-off."
                    ))
                }
            }
        }

        // Double-digit hole callout
        for (player, card, _) in todayCards {
            if let horror = card.holeScores.first(where: { $0.isCompleted && $0.strokes >= 10 }) {
                lines.append(RecapCommentary(
                    text: "🔢 \(firstName(player.name)) put up a \(horror.strokes) on hole \(horror.holeNumber). We're told they're still looking for the ball."
                ))
                break
            }
        }

        // Close finish
        if gap <= 2 && todayCards.count >= 2 {
            lines.append(RecapCommentary(
                text: "🤏 Only \(gap) stroke\(gap == 1 ? "" : "s") separating the top and bottom. Tight day out there — the group chat is going to be heated."
            ))
        }

        // Worst putts callout
        let puttData = todayCards.map { (player, card, _) in
            (player, card.totalPutts)
        }.filter { $0.1 > 0 }
        if let worstPutter = puttData.max(by: { $0.1 < $1.1 }),
           let bestPutter = puttData.min(by: { $0.1 < $1.1 }),
           worstPutter.1 - bestPutter.1 >= 6 {
            lines.append(RecapCommentary(
                text: "🧊 \(firstName(worstPutter.0.name)) had \(worstPutter.1) putts vs \(firstName(bestPutter.0.name))'s \(bestPutter.1). Somebody needs a putting lesson."
            ))
        }

        return lines
    }

    // MARK: - Challenge Highlights

    struct ChallengeHighlight: Identifiable {
        let id: UUID
        let name: String
        let winnerName: String
        let stake: String
        let emoji: String
    }

    var challengeHighlights: [ChallengeHighlight] {
        guard let trip = currentTrip, let day = selectedDay else { return [] }
        let calendar = Calendar.current

        return trip.sideBets.compactMap { bet in
            guard bet.isCompleted,
                  let round = bet.round,
                  calendar.isDate(round.date, inSameDayAs: day),
                  let winnerId = bet.winnerId,
                  let winner = trip.player(withId: winnerId) else { return nil }
            return ChallengeHighlight(
                id: bet.id,
                name: bet.name,
                winnerName: winner.name,
                stake: bet.stake,
                emoji: bet.betType.icon
            )
        }
    }

    // MARK: - Events

    var eventsForDay: [WarRoomEvent] {
        guard let trip = currentTrip, let day = selectedDay else { return [] }
        let calendar = Calendar.current
        return trip.warRoomEvents
            .filter { calendar.isDate($0.dateTime, inSameDayAs: day) }
            .sorted { $0.dateTime < $1.dateTime }
    }

    var tomorrowEvents: [WarRoomEvent] {
        guard let trip = currentTrip,
              selectedDayIndex + 1 < tripDays.count else { return [] }
        let tomorrow = tripDays[selectedDayIndex + 1]
        let calendar = Calendar.current
        return trip.warRoomEvents
            .filter { calendar.isDate($0.dateTime, inSameDayAs: tomorrow) }
            .sorted { $0.dateTime < $1.dateTime }
    }

    var isLastDay: Bool {
        selectedDayIndex == tripDays.count - 1
    }

    // MARK: - Fun Day Subtitle

    var daySubtitle: String {
        let roundCount = completedRoundsForDay.count
        let eventCount = eventsForDay.count
        let roastCount = awards.filter(\.isRoast).count

        if roundCount == 0 && eventCount == 0 {
            return "Recovery day. Some of you need it. 😎"
        } else if roundCount > 1 {
            return "Double-header day — gluttons for punishment ⛳️⛳️"
        } else if roundCount == 1 {
            if roastCount >= 3 { return "A lot of people got exposed today 👀" }
            if roastCount == 0 { return "Clean day — nobody embarrassed themselves... barely ⛳️" }
            return "Another day, another round of questionable decisions ⛳️"
        } else {
            return "No golf, but the trash talk never stops 🎉"
        }
    }
}
