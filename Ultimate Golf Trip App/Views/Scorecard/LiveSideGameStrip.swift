import SwiftUI

/// Horizontal strip of compact "live state" chips for each active side game in the current round.
/// Surfaces skins-carrying / snake-holder / nassau-state info directly on the live scorecard so
/// players don't have to dig into the Side Games tab mid-round.
///
/// Tap a chip → opens the existing `SideGameDetailView` for that game.
struct LiveSideGameStrip: View {
    let round: Round
    @Environment(AppState.self) private var appState

    @State private var sideGameVM: SideGameViewModel?
    @State private var presentedGame: SideGame?

    var body: some View {
        let games = activeGamesForRound()
        if games.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(games, id: \.id) { game in
                        Button {
                            presentedGame = game
                        } label: {
                            chip(for: game)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
            .sheet(item: $presentedGame) { game in
                if let vm = ensureSideGameVM() {
                    NavigationStack {
                        SideGameDetailView(viewModel: vm, game: game)
                    }
                }
            }
        }
    }

    // MARK: - Data

    /// Side games that are active AND either scoped to this round or trip-wide. Filtered to
    /// games actually relevant to the current playing-group view (if scoped).
    private func activeGamesForRound() -> [SideGame] {
        guard let trip = appState.currentTrip else { return [] }
        return trip.sideGames
            .filter { $0.isActive }
            .filter { $0.round == nil || $0.round?.id == round.id }
    }

    /// Re-use a single SideGameViewModel for the strip's lifetime so the detail sheet
    /// has stable state.
    private func ensureSideGameVM() -> SideGameViewModel? {
        if sideGameVM == nil {
            sideGameVM = SideGameViewModel(appState: appState)
        }
        return sideGameVM
    }

    // MARK: - Chip rendering

    private func chip(for game: SideGame) -> some View {
        let state = LiveSideGameStateEngine.state(for: game, round: round)
        let a11y: String = {
            var parts = [state.title]
            if let scope = state.scopeLabel { parts.append(scope) }
            parts.append(state.subtitle)
            return parts.joined(separator: ". ")
        }()
        return HStack(spacing: 6) {
            Image(systemName: state.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(state.title)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.textPrimary)
                    if let scope = state.scopeLabel {
                        Text("· \(scope)")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Text(state.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 44)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
        .accessibilityHint("Opens side game details.")
    }
}

// MARK: - State derivation

/// Derives a compact "live state" tuple for a side game, suitable for a chip.
/// Stays separate from the view so it's testable and reusable (e.g., for a future
/// Dynamic Island / lock-screen widget).
enum LiveSideGameStateEngine {
    struct State {
        let title: String          // "Skins", "Snake", "Nassau" …
        let subtitle: String       // "$15 carrying" / "Sam holds" / "0 pts so far"
        let icon: String           // SF Symbol
        let scopeLabel: String?    // Group name when scoped; nil otherwise
    }

    static func state(for game: SideGame, round: Round) -> State {
        let scope = scopeLabel(for: game, round: round)
        let liveResults = liveResults(for: game, round: round)
        switch game.type {
        case .skins:
            return skinsState(game: game, round: round, results: liveResults, scope: scope)
        case .nassau:
            return nassauState(game: game, results: liveResults, scope: scope)
        case .snake:
            return snakeState(game: game, round: round, results: liveResults, scope: scope)
        case .rabbit:
            return State(
                title: game.type.rawValue,
                subtitle: rabbitSubtitle(results: liveResults),
                icon: "hare.fill",
                scopeLabel: scope
            )
        case .wolf:
            return State(
                title: "Wolf",
                subtitle: "Tap to manage",
                icon: "pawprint.fill",
                scopeLabel: scope
            )
        case .closestToPin, .longDrive, .greenies, .dots, .arnies, .sandies, .barkies:
            return State(
                title: game.type.rawValue,
                subtitle: eventGameSubtitle(game: game),
                icon: defaultIcon(for: game.type),
                scopeLabel: scope
            )
        }
    }

    // MARK: - Live (non-persisted) result derivation

    /// Run the appropriate SideGameEngine function against current scorecards without
    /// writing to the game's persisted `results`. Lets the strip reflect mid-round state
    /// without forcing the user to tap a "recalculate" affordance.
    private static func liveResults(for game: SideGame, round: Round) -> [SideGameResult] {
        guard let course = round.course else { return game.results }

        let baseIds = Set(game.participantIds)
        let effectiveIds: Set<UUID> = {
            guard let groupId = game.playingGroupId,
                  let group = round.playingGroups.first(where: { $0.id == groupId }) else {
                return baseIds
            }
            return baseIds.intersection(Set(group.playerIds))
        }()

        let processed = ScoringEngine.processRound(round: round, course: course)
        let processedCards = processed.scorecards.filter { effectiveIds.contains($0.playerId) }
        let rawCards = round.scorecards.filter { card in
            guard let pid = card.player?.id else { return false }
            return effectiveIds.contains(pid)
        }

        switch game.type {
        case .skins:
            return SideGameEngine.calculateSkins(
                scorecards: processedCards,
                stakes: game.stakes,
                holes: course.holes
            )
        case .nassau:
            return SideGameEngine.calculateNassau(
                scorecards: processedCards,
                stakes: game.stakes
            )
        case .snake:
            return SideGameEngine.calculateSnake(
                scorecards: rawCards,
                stakes: game.stakes,
                holeCount: course.holes.count
            )
        case .rabbit:
            return SideGameEngine.calculateRabbit(
                scorecards: processedCards,
                stakes: game.stakes,
                holes: course.holes
            )
        default:
            // Event-declared games (CTP, LD, Wolf, etc.) aren't score-derived — fall back
            // to whatever the user has recorded.
            return game.results
        }
    }

    // MARK: - Per-type derivations

    private static func skinsState(
        game: SideGame,
        round: Round,
        results: [SideGameResult],
        scope: String?
    ) -> State {
        let resolved = results.filter { !$0.isCarryOver }
        let won = resolved.count
        let carryHole = results.last(where: { $0.isCarryOver })?.holeNumber
        let perSkin = String(format: "%.0f", game.stakes)
        let subtitle: String = {
            if let carry = carryHole {
                return "\(perSkin) pt carry · thru \(carry)"
            }
            if won > 0 {
                return "\(won) skin\(won == 1 ? "" : "s") won"
            }
            return "Awaiting first skin"
        }()
        _ = round
        return State(
            title: "Skins",
            subtitle: subtitle,
            icon: "rosette",
            scopeLabel: scope
        )
    }

    private static func nassauState(
        game: SideGame,
        results: [SideGameResult],
        scope: String?
    ) -> State {
        _ = game
        let total = results.reduce(0.0) { $0 + $1.amount }
        let subtitle: String = {
            if results.isEmpty { return "Front 9 in play" }
            if total == 0 { return "\(results.count) segment\(results.count == 1 ? "" : "s") played" }
            return "\(String(format: "%.0f", total)) pts settled"
        }()
        return State(
            title: "Nassau",
            subtitle: subtitle,
            icon: "flag.checkered",
            scopeLabel: scope
        )
    }

    private static func snakeState(
        game: SideGame,
        round: Round,
        results: [SideGameResult],
        scope: String?
    ) -> State {
        _ = game
        // The current holder is the player who 3-putted most recently.
        let holder = results
            .filter { !$0.isCarryOver }
            .compactMap { $0.winnerId }
            .last
        let holderName: String? = holder.flatMap { id in
            round.trip?.players.first(where: { $0.id == id })?.name
        }
        let subtitle: String = {
            if let name = holderName { return "\(name) holds 🐍" }
            // Round didn't track putts → snake can't run; surface that.
            if !round.trackPutts { return "Putts off — snake idle" }
            return "Nobody 3-putted yet"
        }()
        return State(
            title: "Snake",
            subtitle: subtitle,
            icon: "tortoise.fill",
            scopeLabel: scope
        )
    }

    private static func rabbitSubtitle(results: [SideGameResult]) -> String {
        let lastHolderId = results.compactMap { $0.winnerId }.last
        if lastHolderId != nil { return "Rabbit in play" }
        return "Awaiting first hole"
    }

    private static func eventGameSubtitle(game: SideGame) -> String {
        if game.designatedHoles.isEmpty {
            return "Per-hole event"
        }
        let count = game.designatedHoles.count
        let won = game.results.count
        return "\(won)/\(count) holes settled"
    }

    private static func defaultIcon(for type: SideGameType) -> String {
        switch type {
        case .closestToPin: return "scope"
        case .longDrive: return "arrow.up.forward.app"
        case .greenies: return "leaf.fill"
        case .dots, .arnies, .sandies, .barkies: return "circle.dotted"
        case .wolf: return "pawprint.fill"
        default: return "gamecontroller.fill"
        }
    }

    // MARK: - Scope

    private static func scopeLabel(for game: SideGame, round: Round) -> String? {
        guard let groupId = game.playingGroupId,
              let group = round.playingGroups.first(where: { $0.id == groupId }) else {
            return nil
        }
        return group.name
    }
}
