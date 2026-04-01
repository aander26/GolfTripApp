import SwiftUI
import UIKit
import Combine

// MARK: - Bold Links Theme (Light + Dark)

enum Theme {
    // MARK: Helpers

    /// Creates an adaptive color that resolves per the current interface style.
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    // MARK: Backgrounds

    static var background: Color {
        adaptive(
            light: rgb(0.953, 0.957, 0.965),   // #F3F4F6
            dark:  rgb(0.059, 0.078, 0.098)     // #0F1419
        )
    }

    static var backgroundDark: Color {
        adaptive(
            light: rgb(0.067, 0.094, 0.153),   // #111827
            dark:  rgb(0.039, 0.059, 0.078)     // #0A0F14
        )
    }

    static var cardBackground: Color {
        adaptive(
            light: .white,
            dark:  rgb(0.102, 0.137, 0.196)     // #1A2332
        )
    }

    // MARK: Primary accent (emerald)

    static var primary: Color {
        adaptive(
            light: rgb(0.063, 0.725, 0.506),   // #10B981
            dark:  rgb(0.204, 0.827, 0.600)     // #34D399
        )
    }

    static var primaryDark: Color {
        adaptive(
            light: rgb(0.020, 0.588, 0.412),   // #059669
            dark:  rgb(0.063, 0.725, 0.506)     // #10B981
        )
    }

    static var primaryLight: Color {
        adaptive(
            light: rgb(0.820, 0.980, 0.898),   // #D1FAE5
            dark:  rgb(0.024, 0.306, 0.231)     // #064E3B
        )
    }

    static var primaryMuted: Color {
        adaptive(
            light: UIColor(red: 0.063, green: 0.725, blue: 0.506, alpha: 0.1),
            dark:  UIColor(red: 0.204, green: 0.827, blue: 0.600, alpha: 0.15)
        )
    }

    // MARK: Text

    static var textPrimary: Color {
        adaptive(
            light: rgb(0.067, 0.094, 0.153),   // #111827
            dark:  rgb(0.910, 0.925, 0.941)     // #E8ECF0
        )
    }

    static var textSecondary: Color {
        adaptive(
            light: rgb(0.420, 0.447, 0.498),   // #6B7280
            dark:  rgb(0.533, 0.600, 0.651)     // #8899A6
        )
    }

    static let textOnPrimary = Color.white

    static let defaultPlayerColor: PlayerColor = .blue

    // MARK: Avatar accent colors (vibrant in both modes)

    static let avatar1 = Color(red: 0.063, green: 0.725, blue: 0.506)            // emerald
    static let avatar2 = Color(red: 0.545, green: 0.361, blue: 0.965)            // violet
    static let avatar3 = Color(red: 0.976, green: 0.451, blue: 0.086)            // orange
    static let avatar4 = Color(red: 0.024, green: 0.714, blue: 0.831)            // cyan

    // MARK: Status (vibrant in both modes)

    static let success = Color(red: 0.063, green: 0.725, blue: 0.506)            // #10B981
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)            // #F59E0B
    static let error = Color(red: 0.937, green: 0.267, blue: 0.267)              // #EF4444

    // MARK: Borders

    static var border: Color {
        adaptive(
            light: rgb(0.898, 0.906, 0.922),   // #E5E7EB
            dark:  rgb(0.165, 0.227, 0.290)     // #2A3A4A
        )
    }

    static var borderStrong: Color {
        adaptive(
            light: rgb(0.820, 0.835, 0.859),   // #D1D5DB
            dark:  rgb(0.227, 0.290, 0.353)     // #3A4A5A
        )
    }
}

// MARK: - Legacy Color Aliases (backward compatible)

extension Color {
    // Primary accent — mapped to emerald
    static let golfGreen = Theme.primary
    static let fairwayGreen = Theme.primaryDark

    // Score colors — high contrast for Bold Links
    static let birdie = Color(red: 0.937, green: 0.267, blue: 0.267)             // #EF4444 red
    static let eagle = Color(red: 0.961, green: 0.620, blue: 0.043)              // #F59E0B amber
    static let bogey = Color(red: 0.235, green: 0.388, blue: 0.847)              // #3B63D8 blue
    static let doubleBogey = Color(red: 0.545, green: 0.361, blue: 0.965)        // #8B5CF6 violet
    static let par = Theme.textPrimary

    // Backgrounds
    static let scorecardBg = Theme.background
}

extension ShapeStyle where Self == Color {
    static var golfGreen: Color { Theme.primary }
    static var fairwayGreen: Color { Theme.primaryDark }
    static var birdie: Color { Color.birdie }
    static var eagle: Color { Color.eagle }
    static var bogey: Color { Color.bogey }
    static var doubleBogey: Color { Color.doubleBogey }
}

// MARK: - Themed List Modifier

/// Strips the default List/Form background so Theme.background shows through.
struct ThemedListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

extension View {
    func themedList() -> some View {
        modifier(ThemedListStyle())
    }
}

// MARK: - Card Style Modifier

struct CardStyle: ViewModifier {
    var padded: Bool = true

    func body(content: Content) -> some View {
        content
            .if(padded) { view in view.padding() }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.border, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

extension View {
    func cardStyle(padded: Bool = true) -> some View {
        modifier(CardStyle(padded: padded))
    }

    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Section Header Style

struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

extension View {
    func sectionHeader() -> some View {
        modifier(SectionHeaderStyle())
    }
}

// MARK: - Primary Button Style

struct BoldPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.textOnPrimary)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Theme.primary)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct BoldSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Theme.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.primary, lineWidth: 2))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Score Color

extension HoleScore {
    var scoreColor: Color {
        guard strokes > 0 else { return Theme.textSecondary }
        switch scoreToPar {
        case ...(-2): return .eagle
        case -1: return .birdie
        case 0: return .par
        case 1: return .bogey
        case 2: return .doubleBogey
        default: return .doubleBogey
        }
    }

    var netScoreColor: Color {
        guard netStrokes > 0 else { return Theme.textSecondary }
        switch netScoreToPar {
        case ...(-2): return .eagle
        case -1: return .birdie
        case 0: return .par
        case 1: return .bogey
        case 2: return .doubleBogey
        default: return .doubleBogey
        }
    }
}

// MARK: - Cached DateFormatters

/// Reusable cached DateFormatters. DateFormatter is expensive to create;
/// these statics are created once and shared across the app.
enum CachedFormatters {
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static let weekdayShortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()
}

// MARK: - Date Extensions

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var shortFormatted: String {
        CachedFormatters.shortDate.string(from: self)
    }

    var timeFormatted: String {
        CachedFormatters.time.string(from: self)
    }
}

// MARK: - Minute Timer for Time-Sensitive Views

/// A view modifier that triggers a re-render every minute.
/// Attach to views displaying relative times (e.g. "5m ago", "upcoming").
struct MinuteTimerModifier: ViewModifier {
    @State private var tick = false

    func body(content: Content) -> some View {
        content
            .onAppear { tick.toggle() }
            .onReceive(
                Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            ) { _ in
                tick.toggle()
            }
            .id(tick)
    }
}

extension View {
    /// Re-renders the view every minute to keep relative timestamps fresh.
    func refreshEveryMinute() -> some View {
        modifier(MinuteTimerModifier())
    }
}

// MARK: - View Modifiers

struct ScoreCircleModifier: ViewModifier {
    let scoreToPar: Int
    let isCompleted: Bool

    func body(content: Content) -> some View {
        if !isCompleted {
            content
        } else {
            switch scoreToPar {
            case ...(-2):
                content
                    .background(
                        Circle()
                            .stroke(Color.eagle, lineWidth: 2)
                            .background(Circle().stroke(Color.eagle, lineWidth: 2).padding(3))
                    )
            case -1:
                content
                    .background(Circle().stroke(Color.birdie, lineWidth: 2))
            case 0:
                content
            case 1:
                content
                    .background(Rectangle().stroke(Color.bogey, lineWidth: 2))
            default:
                content
                    .background(
                        Rectangle()
                            .stroke(Color.doubleBogey, lineWidth: 2)
                            .background(Rectangle().stroke(Color.doubleBogey, lineWidth: 2).padding(3))
                    )
            }
        }
    }
}

extension View {
    func scoreIndicator(scoreToPar: Int, isCompleted: Bool) -> some View {
        modifier(ScoreCircleModifier(scoreToPar: scoreToPar, isCompleted: isCompleted))
    }
}
