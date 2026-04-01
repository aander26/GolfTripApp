import SwiftUI

struct DailyRecapView: View {
    @Bindable var viewModel: DailyRecapViewModel

    var body: some View {
        if viewModel.tripDays.isEmpty {
            ContentUnavailableView("No Trip Days Yet", systemImage: "calendar.badge.exclamationmark", description: Text("Daily recaps will appear once your trip has started."))
                .navigationTitle("Daily Recap")
                .navigationBarTitleDisplayMode(.inline)
        } else {
        ScrollView {
            VStack(spacing: 20) {
                dayPicker
                dayHeader
                commentarySection
                gloryAwardsSection
                roastAwardsSection
                roundResultsSection
                matchPlaySection
                challengeHighlightsSection
                tomorrowPreviewSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .navigationTitle("Daily Recap")
        .navigationBarTitleDisplayMode(.inline)
        } // end else
    }

    // MARK: - Day Picker

    private var dayPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.tripDays.enumerated()), id: \.offset) { index, day in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedDayIndex = index
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text("Day \(index + 1)")
                                    .font(.caption.bold())
                                Text(shortDate(day))
                                    .font(.system(size: 9))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(viewModel.selectedDayIndex == index ? Theme.primary : Theme.cardBackground)
                            .foregroundStyle(viewModel.selectedDayIndex == index ? .white : Theme.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(viewModel.selectedDayIndex == index ? Color.clear : Theme.border, lineWidth: 1)
                            )
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.selectedDayIndex) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        VStack(spacing: 6) {
            Text("Day \(viewModel.dayNumber) Recap")
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)

            Text(viewModel.formattedDayDate)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

            Text(viewModel.daySubtitle)
                .font(.callout)
                .foregroundStyle(Theme.primary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Commentary

    @ViewBuilder
    private var commentarySection: some View {
        let lines = viewModel.commentary
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines) { line in
                    Text(line.text)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Glory Awards

    @ViewBuilder
    private var gloryAwardsSection: some View {
        let glory = viewModel.awards.filter { !$0.isRoast }
        if !glory.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("HALL OF FAME")
                    .sectionHeader()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(glory) { award in
                            RecapAwardCard(award: award)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Roast Awards

    @ViewBuilder
    private var roastAwardsSection: some View {
        let roasts = viewModel.awards.filter(\.isRoast)
        if !roasts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("WALL OF SHAME")
                    .sectionHeader()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(roasts) { award in
                            RecapAwardCard(award: award)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Round Results

    @ViewBuilder
    private var roundResultsSection: some View {
        let rounds = viewModel.completedRoundsForDay
        if !rounds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("ROUND RESULTS")
                    .sectionHeader()

                ForEach(rounds) { round in
                    roundCard(round)
                }
            }
        }
    }

    private func roundCard(_ round: Round) -> some View {
        let entries = viewModel.leaderboard(for: round)

        return VStack(alignment: .leading, spacing: 10) {
            // Course header
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundStyle(Theme.primary)
                Text(round.course?.name ?? "Unknown Course")
                    .font(.headline)
                Spacer()
                Text(round.format.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.primaryLight)
                    .clipShape(Capsule())
            }

            // Mini leaderboard (top 4)
            ForEach(Array(entries.prefix(4).enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 10) {
                    Text(positionEmoji(index + 1))
                        .font(.body)
                        .frame(width: 28)
                        .accessibilityLabel(positionAccessibilityLabel(index + 1))

                    Text(entry.playerName)
                        .font(.subheadline)
                        .fontWeight(index == 0 ? .bold : .regular)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(entry.totalNet) net")
                            .font(.subheadline.bold())
                        Text(entry.formattedScoreToPar)
                            .font(.caption2)
                            .foregroundStyle(scoreColor(entry.netScoreToPar))
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .cardStyle()
    }

    // MARK: - Match Play

    @ViewBuilder
    private var matchPlaySection: some View {
        let matchRounds = viewModel.completedRoundsForDay.compactMap { round -> (Round, RoundTeamMatchResult)? in
            guard let result = viewModel.matchResults(for: round) else { return nil }
            return (round, result)
        }

        if !matchRounds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("MATCH PLAY")
                    .sectionHeader()

                ForEach(matchRounds, id: \.0.id) { round, result in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.roundLabel)
                            .font(.caption.bold())
                            .foregroundStyle(Theme.primary)

                        // Team scores
                        if !result.teamScores.isEmpty {
                            HStack(spacing: 16) {
                                ForEach(result.teamScores, id: \.teamId) { teamScore in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(teamScore.teamColor.color)
                                            .frame(width: 10, height: 10)
                                        Text(teamScore.teamName)
                                            .font(.subheadline.bold())
                                        Text("\(teamScore.totalNetScore)")
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                            }
                        }

                        // Individual match results
                        ForEach(result.individualMatches, id: \.player1Id) { match in
                            HStack(spacing: 6) {
                                Image(systemName: "figure.golf")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.primary)
                                Text(match.displayText)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }

                        // Nines match results
                        ForEach(result.ninesMatches, id: \.player1Id) { match in
                            HStack(spacing: 6) {
                                Image(systemName: "figure.golf")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.primary)
                                Text(match.displayText)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .cardStyle()
                }
            }
        }
    }

    // MARK: - Challenge Highlights

    @ViewBuilder
    private var challengeHighlightsSection: some View {
        let highlights = viewModel.challengeHighlights
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("CHALLENGES SETTLED")
                    .sectionHeader()

                ForEach(highlights) { highlight in
                    HStack(spacing: 12) {
                        Image(systemName: highlight.emoji)
                            .font(.title3)
                            .foregroundStyle(Theme.primary)
                            .frame(width: 36, height: 36)
                            .background(Theme.primaryLight)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(highlight.name)
                                .font(.subheadline.bold())
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                Text(highlight.winnerName)
                                    .font(.caption)
                                    .foregroundStyle(Theme.primary)
                            }
                        }

                        Spacer()

                        if !highlight.stake.isEmpty {
                            Text(highlight.stake)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.primaryLight)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                    .cardStyle()
                }
            }
        }
    }

    // MARK: - Tomorrow Preview

    @ViewBuilder
    private var tomorrowPreviewSection: some View {
        if viewModel.isLastDay {
            VStack(spacing: 8) {
                Text("🏆")
                    .font(.system(size: 40))
                Text("Final Day!")
                    .font(.headline)
                    .foregroundStyle(Theme.primary)
                Text("Make it count.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            let events = viewModel.tomorrowEvents
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("UP TOMORROW")
                        .sectionHeader()

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(events) { event in
                            HStack(spacing: 12) {
                                Image(systemName: event.type.icon)
                                    .font(.caption)
                                    .foregroundStyle(eventColor(for: event.type))
                                    .frame(width: 30, height: 30)
                                    .background(eventColor(for: event.type).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    HStack(spacing: 6) {
                                        Text(event.formattedTime)
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                        if !event.location.isEmpty {
                                            Text(event.location)
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }

                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .cardStyle()
                }
            }
        }
    }

    // MARK: - Helpers

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func positionAccessibilityLabel(_ position: Int) -> String {
        switch position {
        case 1: return "First place"
        case 2: return "Second place"
        case 3: return "Third place"
        default: return "Position \(position)"
        }
    }

    private func positionEmoji(_ position: Int) -> String {
        switch position {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(position)."
        }
    }

    private func scoreColor(_ scoreToPar: Int) -> Color {
        if scoreToPar < 0 { return .birdie }
        if scoreToPar == 0 { return .par }
        return .bogey
    }
}

#Preview {
    NavigationStack {
        DailyRecapView(viewModel: SampleData.makeDailyRecapViewModel())
    }
    .environment(SampleData.makeAppState())
}
