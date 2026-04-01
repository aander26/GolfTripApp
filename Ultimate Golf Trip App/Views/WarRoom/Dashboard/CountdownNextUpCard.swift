import SwiftUI

struct CountdownNextUpCard: View {
    let event: WarRoomEvent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let remaining = event.dateTime.timeIntervalSince(context.date)
            let isUrgent = remaining > 0 && remaining < 3600
            let isPast = remaining <= 0

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("NEXT UP")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.textOnPrimary.opacity(0.8))
                        .tracking(0.8)
                    Spacer()
                    if isPast {
                        Text("Happening Now")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.textOnPrimary)
                    } else {
                        Text(countdownText(remaining: remaining))
                            .font(isUrgent ? .headline.bold() : .subheadline.bold())
                            .foregroundStyle(Theme.textOnPrimary)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: event.type.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(Theme.textOnPrimary)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text(event.formattedTime)
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Theme.textOnPrimary.opacity(0.8))

                            if !event.location.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin")
                                        .font(.caption)
                                    Text(event.location)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                                .foregroundStyle(Theme.textOnPrimary.opacity(0.8))
                            }
                        }
                    }

                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isUrgent ? Color.orange : Theme.primary)
            )
            .shadow(color: (isUrgent ? Color.orange : Theme.primary).opacity(0.3), radius: 8, y: 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next up: \(event.title) at \(event.formattedTime)")
        }
    }

    private func countdownText(remaining: TimeInterval) -> String {
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "Starts in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "Starts in \(minutes)m"
        } else {
            return "Starting now"
        }
    }
}
