import Foundation
import SwiftData

@Model
final class MetricEntry {
    var id: UUID
    var value: Double
    var date: Date
    var notes: String

    // Relationships
    var metric: Metric?
    var member: Player?
    var round: Round?
    var trip: Trip?

    init(
        id: UUID = UUID(),
        metric: Metric? = nil,
        member: Player? = nil,
        value: Double,
        round: Round? = nil,
        date: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.metric = metric
        self.member = member
        self.value = value
        self.round = round
        self.date = date
        self.notes = notes
    }

    // MARK: - Backward-compat UUID accessors

    var metricId: UUID? { metric?.id }
    var memberId: UUID? { member?.id }
    var roundId: UUID? { round?.id }

    // MARK: - Computed Properties

    var formattedValue: String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
