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
        var isEmpty: Bool
        
        init(nextAlarmTime: String, nextAlarmDate: String, alarmTitle: String, isSkipped: Bool, isEmpty: Bool = false) {
            self.nextAlarmTime = nextAlarmTime
            self.nextAlarmDate = nextAlarmDate
            self.alarmTitle = alarmTitle
            self.isSkipped = isSkipped
            self.isEmpty = isEmpty
        }
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
    static let emptyGray = Color(red: 0.5, green: 0.5, blue: 0.55)
}

// MARK: - Live Activity Widget

struct BetterAlarmWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - 최소화 (길게 누르면 나타남)
                DynamicIslandExpandedRegion(.leading) {
                    Text(" ")
                        .font(.system(size: 1))
                        .foregroundColor(.clear)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(" ")
                        .font(.system(size: 1))
                        .foregroundColor(.clear)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(" ")
                        .font(.system(size: 1))
                        .foregroundColor(.clear)
                }
            } compactLeading: {
                // 최소한의 투명 요소
                Text(" ")
                    .font(.system(size: 1))
                    .foregroundColor(.clear)
            } compactTrailing: {
                // 최소한의 투명 요소
                Text(" ")
                    .font(.system(size: 1))
                    .foregroundColor(.clear)
            } minimal: {
                // 최소한의 투명 요소
                Text(" ")
                    .font(.system(size: 1))
                    .foregroundColor(.clear)
            }
            .keylineTint(.clear)
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.backgroundDark, .backgroundPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if context.state.isEmpty {
                emptyStateContent
            } else {
                alarmContent
            }
        }
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.white)
    }
    
    // MARK: - Empty State Content

    private var emptyStateContent: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.emptyGray.opacity(0.2))
                    .frame(width: 46, height: 46)

                Image(systemName: "alarm")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.emptyGray)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("설정된 알람 없음")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.emptyGray)

                Text("알람을 추가해주세요")
                    .font(.caption)
                    .foregroundColor(.emptyGray.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
    
    // MARK: - Alarm Content

    private var alarmContent: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentLavender, .accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: "alarm.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("다음 알람")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentLavender)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(context.state.nextAlarmTime)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.85)

                    Text(context.state.nextAlarmDate)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Text(context.state.alarmTitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            VStack {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.15))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

// MARK: - Previews

#Preview("With Alarm", as: .content, using: AlarmActivityAttributes(alarmId: "preview")) {
   BetterAlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오전 7:30",
        nextAlarmDate: "내일",
        alarmTitle: "출근 알람",
        isSkipped: false,
        isEmpty: false
    )
}

#Preview("Skipped", as: .content, using: AlarmActivityAttributes(alarmId: "preview")) {
   BetterAlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오전 7:30",
        nextAlarmDate: "1월 22일",
        alarmTitle: "출근 알람",
        isSkipped: true,
        isEmpty: false
    )
}

#Preview("Empty State", as: .content, using: AlarmActivityAttributes(alarmId: "empty")) {
   BetterAlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "--:--",
        nextAlarmDate: "설정된 알람 없음",
        alarmTitle: "알람을 추가해주세요",
        isSkipped: false,
        isEmpty: true
    )
}
