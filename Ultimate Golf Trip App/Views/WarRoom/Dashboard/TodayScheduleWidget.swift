import SwiftUI

struct TodayScheduleWidget: View {
    let events: [WarRoomEvent]
    let players: [Player]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Schedule")
                .sectionHeader()

            if events.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "sun.max")
                            .font(.title2)
                            .foregroundStyle(Theme.textSecondary)
                        Text("Nothing scheduled today")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
                .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        let isCurrent = event.isHappeningNow
                        let isNext = !event.isPast && !event.isHappeningNow && isNextUpcoming(event)

                        HStack(spacing: 12) {
                            // Time
                            Text(event.formattedTime)
                                .font(.caption.bold())
                                .foregroundStyle(event.isPast ? Theme.textSecondary : Theme.textPrimary)
                                .frame(width: 58, alignment: .trailing)

                            // Color dot
                            Circle()
                                .fill(eventColor(for: event.type))
                                .frame(width: 8, height: 8)

                            // Title
                            Text(event.title)
                                .font(.subheadline.weight(isCurrent || isNext ? .bold : .regular))
                                .foregroundStyle(event.isPast ? Theme.textSecondary : Theme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            if event.isPast {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.success)
                            } else if isCurrent {
                                Text("NOW")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Theme.textOnPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.primary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            (isCurrent || isNext)
                                ? Theme.primaryMuted
                                : Color.clear
                        )
                        .opacity(event.isPast ? 0.7 : 1.0)

                        if index < events.count - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .cardStyle(padded: false)
            }
        }
    }

    private func isNextUpcoming(_ event: WarRoomEvent) -> Bool {
        let upcoming = events.filter { !$0.isPast && !$0.isHappeningNow }
            .sorted { $0.dateTime < $1.dateTime }
        return upcoming.first?.id == event.id
    }
}
