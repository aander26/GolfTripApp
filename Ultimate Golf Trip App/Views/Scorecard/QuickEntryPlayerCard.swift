import SwiftUI

struct QuickEntryPlayerCard: View {
    let player: Player
    let par: Int
    let dragOffset: CGFloat
    let isDragging: Bool

    /// Score relative to par derived from the drag offset
    var scoreToPar: Int {
        scoreFromOffset(dragOffset)
    }

    var strokes: Int {
        max(1, par + scoreToPar)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Score label
            Text(scoreLabel)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(scoreLabelColor)
                .contentTransition(.numericText())

            // Strokes number
            Text("\(strokes)")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            // Hint
            if !isDragging {
                Text("Swipe up or down")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .transition(.opacity)
            } else {
                Text("Release to confirm")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score: \(strokes), \(scoreLabel)")
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200, idealHeight: 260)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isDragging ? scoreLabelColor.opacity(0.4) : Theme.border, lineWidth: isDragging ? 3 : 2)
        )
        .shadow(color: (isDragging ? scoreLabelColor : .black).opacity(0.1), radius: isDragging ? 12 : 4, y: 2)
    }

    // MARK: - Computed

    private var cardBackground: some ShapeStyle {
        Theme.cardBackground
    }

    private var scoreLabel: String {
        switch scoreToPar {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double"
        case 3: return "Triple"
        default: return "+\(scoreToPar)"
        }
    }

    private var scoreLabelColor: Color {
        switch scoreToPar {
        case ...(-2): return .eagle
        case -1: return .birdie
        case 0: return Theme.textPrimary
        case 1: return .bogey
        default: return .doubleBogey
        }
    }

    // MARK: - Score Mapping

    /// Maps a vertical drag offset (points) to a score-to-par value.
    /// Negative offset (drag up) = under par, positive (drag down) = over par.
    static let thresholdPerStroke: CGFloat = 60

    private func scoreFromOffset(_ offset: CGFloat) -> Int {
        let raw = offset / Self.thresholdPerStroke
        let clamped = max(-3, min(6, Int(raw.rounded())))
        // Ensure strokes never go below 1
        let minScoreToPar = 1 - par
        return max(minScoreToPar, clamped)
    }
}
