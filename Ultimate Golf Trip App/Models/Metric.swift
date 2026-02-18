import Foundation
import SwiftData

@Model
final class Metric {
    var id: UUID
    var name: String
    var icon: String
    var unit: String
    var trackingTypeRaw: String
    var categoryRaw: String
    var higherIsBetter: Bool

    // Relationships
    var trip: Trip?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "📊",
        unit: String = "",
        trackingType: TrackingType = .cumulative,
        category: MetricCategory = .onCourse,
        higherIsBetter: Bool = true
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.unit = unit
        self.trackingTypeRaw = trackingType.rawValue
        self.categoryRaw = category.rawValue
        self.higherIsBetter = higherIsBetter
    }

    // MARK: - Computed Properties

    var trackingType: TrackingType {
        get { TrackingType(rawValue: trackingTypeRaw) ?? .cumulative }
        set { trackingTypeRaw = newValue.rawValue }
    }

    var category: MetricCategory {
        get { MetricCategory(rawValue: categoryRaw) ?? .onCourse }
        set { categoryRaw = newValue.rawValue }
    }

    var formattedUnit: String {
        unit.isEmpty ? "" : " \(unit)"
    }

    // MARK: - Preset On-Course Metrics (templates — not persisted, used to seed new trips)

    static let presetOnCourse: [Metric] = [
        Metric(name: "Birdies", icon: "🐦", unit: "birdies", trackingType: .perRound, category: .onCourse, higherIsBetter: true),
        Metric(name: "Total Putts", icon: "🏌️", unit: "putts", trackingType: .perRound, category: .onCourse, higherIsBetter: false),
        Metric(name: "Fairways Hit", icon: "🎯", unit: "fairways", trackingType: .perRound, category: .onCourse, higherIsBetter: true),
        Metric(name: "Greens in Regulation", icon: "🟢", unit: "GIR", trackingType: .perRound, category: .onCourse, higherIsBetter: true),
        Metric(name: "Sand Saves", icon: "🏖️", unit: "saves", trackingType: .perRound, category: .onCourse, higherIsBetter: true),
        Metric(name: "3-Putts", icon: "😬", unit: "3-putts", trackingType: .perRound, category: .onCourse, higherIsBetter: false),
        Metric(name: "Penalty Strokes", icon: "🚫", unit: "penalties", trackingType: .perRound, category: .onCourse, higherIsBetter: false),
        Metric(name: "Up & Downs", icon: "⬆️", unit: "up & downs", trackingType: .perRound, category: .onCourse, higherIsBetter: true),
        Metric(name: "Water Balls", icon: "💧", unit: "balls", trackingType: .perRound, category: .onCourse, higherIsBetter: false),
        Metric(name: "Lost Balls", icon: "🔍", unit: "balls", trackingType: .perRound, category: .onCourse, higherIsBetter: false)
    ]

    // MARK: - Preset Off-Course Metrics

    static let presetOffCourse: [Metric] = [
        Metric(name: "Beers Consumed", icon: "🍺", unit: "beers", trackingType: .perDay, category: .offCourse, higherIsBetter: true),
        Metric(name: "Hours Slept", icon: "😴", unit: "hours", trackingType: .perDay, category: .offCourse, higherIsBetter: false),
        Metric(name: "Steps Walked", icon: "👟", unit: "steps", trackingType: .perDay, category: .offCourse, higherIsBetter: true),
        Metric(name: "Naps Taken", icon: "💤", unit: "naps", trackingType: .perDay, category: .offCourse, higherIsBetter: true),
        Metric(name: "Money Spent at Bar", icon: "💸", unit: "dollars", trackingType: .perDay, category: .offCourse, higherIsBetter: true),
        Metric(name: "Minutes Late", icon: "⏰", unit: "minutes", trackingType: .cumulative, category: .offCourse, higherIsBetter: false),
        Metric(name: "Complaints", icon: "😤", unit: "complaints", trackingType: .cumulative, category: .offCourse, higherIsBetter: false),
        Metric(name: "Dad Jokes Told", icon: "🤣", unit: "jokes", trackingType: .cumulative, category: .offCourse, higherIsBetter: true)
    ]
}
