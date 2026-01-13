//
//  BetterAlarmWidgetLiveActivity.swift
//  BetterAlarmWidget
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Alarm Activity Attributes
// This definition must exist in both main app and widget targets
// as they are separate compilation units

struct AlarmActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var nextAlarmTime: String
        var nextAlarmDate: String
        var alarmTitle: String
        var isSkipped: Bool
    }

    var alarmId: String
}

// MARK: - Theme Colors

private extension Color {
    static let accentLavender = Color(red: 0.7, green: 0.5, blue: 1.0)
    static let accentPink = Color(red: 1.0, green: 0.6, blue: 0.7)
    static let skipOrange = Color(red: 1.0, green: 0.75, blue: 0.4)
    static let backgroundDark = Color(red: 0.08, green: 0.08, blue: 0.15)
    static let backgroundPurple = Color(red: 0.12, green: 0.1, blue: 0.22)
    static let glassWhite = Color.white.opacity(0.1)
    static let glassBorder = Color.white.opacity(0.2)
}

// MARK: - Live Activity Widget

struct BetterAlarmWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        // Alarm icon with gradient background
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.accentLavender, .accentPink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: "alarm.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.nextAlarmDate)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.6))

                            Text(context.state.nextAlarmTime)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if context.state.isSkipped {
                            HStack(spacing: 4) {
                                Image(systemName: "forward.fill")
                                    .font(.caption2)
                                Text("스킵")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.skipOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.skipOrange.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.alarmTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))

                        Spacer()
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.accentLavender, .accentPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)

                    Image(systemName: "alarm.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                Text(context.state.nextAlarmTime)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.accentLavender)
            } minimal: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.accentLavender, .accentPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "alarm.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .keylineTint(.accentLavender)
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [.backgroundDark, .backgroundPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Content
            HStack(spacing: 16) {
                // Alarm icon with gradient circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.accentLavender, .accentPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "alarm.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Title and skip badge row
                    HStack(spacing: 8) {
                        Text("다음 알람")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentLavender)

                        if context.state.isSkipped {
                            HStack(spacing: 3) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 8))
                                Text("1회 스킵")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.skipOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.skipOrange.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }

                    // Time and date row
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(context.state.nextAlarmTime)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(context.state.nextAlarmDate)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Alarm title
                    Text(context.state.alarmTitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer()

                // Decorative element
                VStack {
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.15))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Previews

#Preview("Notification", as: .content, using: AlarmActivityAttributes(alarmId: "preview")) {
   BetterAlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오전 7:30",
        nextAlarmDate: "내일",
        alarmTitle: "출근 알람",
        isSkipped: false
    )
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오전 7:30",
        nextAlarmDate: "1월 15일",
        alarmTitle: "출근 알람",
        isSkipped: true
    )
}
