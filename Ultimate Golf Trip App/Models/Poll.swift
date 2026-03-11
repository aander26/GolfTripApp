import Foundation
import SwiftData

@Model
final class Poll {
    var id: UUID
    var question: String
    var options: [PollOption]
    var createdBy: UUID?
    var createdAt: Date
    var isActive: Bool
    var allowMultipleVotes: Bool

    // Relationships
    @Relationship(inverse: \Trip.polls)
    var trip: Trip?

    init(
        id: UUID = UUID(),
        question: String,
        options: [PollOption] = [],
        createdBy: UUID? = nil,
        createdAt: Date = Date(),
        isActive: Bool = true,
        allowMultipleVotes: Bool = false
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.isActive = isActive
        self.allowMultipleVotes = allowMultipleVotes
    }

    // MARK: - Computed Properties

    var totalVotes: Int {
        options.reduce(0) { $0 + $1.voterIds.count }
    }

    var leadingOption: PollOption? {
        options.max(by: { $0.voterIds.count < $1.voterIds.count })
    }

    func hasVoted(playerId: UUID) -> Bool {
        options.contains { $0.voterIds.contains(playerId) }
    }

    func toggleVote(optionId: UUID, playerId: UUID) {
        guard let index = options.firstIndex(where: { $0.id == optionId }) else { return }

        let wasAlreadyVoted = options[index].voterIds.contains(playerId)

        if !allowMultipleVotes {
            // Remove all existing votes for this player
            for i in options.indices {
                options[i].voterIds.removeAll { $0 == playerId }
            }
        }

        // Toggle: if they were already on this option, leave it removed; otherwise add
        if wasAlreadyVoted {
            // In multi-vote mode, we haven't removed yet, so remove now
            if allowMultipleVotes {
                options[index].voterIds.removeAll { $0 == playerId }
            }
            // In single-vote mode, already removed above — done
        } else {
            options[index].voterIds.append(playerId)
        }
    }
}

// Stays as Codable struct — small value type stored inline by SwiftData
struct PollOption: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var voterIds: [UUID]

    init(
        id: UUID = UUID(),
        text: String,
        voterIds: [UUID] = []
    ) {
        self.id = id
        self.text = text
        self.voterIds = voterIds
    }

    var voteCount: Int {
        voterIds.count
    }
}
