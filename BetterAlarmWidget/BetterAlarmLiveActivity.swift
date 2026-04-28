import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Alarm Activity Attributes (Shared with main app)

// MARK: - Live Activity Widget

struct BetterAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenAlarmView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "alarm.fill")
                            .foregroundColor(.cyan)
                        Text("다음 알람")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.nextAlarmDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.nextAlarmTime)
                            .font(.system(size: 32, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)

                        if !context.state.alarmTitle.isEmpty {
                            Text(context.state.alarmTitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if context.state.isSkipped {
                            Text("이번만 건너뛰기")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                // Compact leading
                Image(systemName: "alarm.fill")
                    .foregroundColor(.cyan)
            } compactTrailing: {
                // Compact trailing
                Text(context.state.nextAlarmTime)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
            } minimal: {
                // Minimal view
                Image(systemName: "alarm.fill")
                    .foregroundColor(.cyan)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenAlarmView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Alarm icon with glow effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "alarm.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("다음 알람")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if context.state.isSkipped {
                        Text("건너뛰기")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(context.state.nextAlarmTime)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)

                HStack {
                    Text(context.state.nextAlarmDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !context.state.alarmTitle.isEmpty {
                        Text("• \(context.state.alarmTitle)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: AlarmActivityAttributes(alarmId: "preview")) {
    BetterAlarmLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오전 7:30",
        nextAlarmDate: "5월 1일",
        alarmTitle: "기상 알람",
        isSkipped: false
    )

    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오후 2:00",
        nextAlarmDate: "1월 15일 (월)",
        alarmTitle: "회의",
        isSkipped: true
    )
}
