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
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.isEmpty {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.emptyGray.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "alarm")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.emptyGray)
                            }
                            
                            Text("알람 없음")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.emptyGray)
                        }
                    } else {
                        HStack(spacing: 10) {
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
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.isEmpty && context.state.isSkipped {
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

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isEmpty {
                        Text("알람을 추가해주세요")
                            .font(.caption)
                            .foregroundColor(.emptyGray)
                            .padding(.top, 4)
                    } else {
                        HStack {
                            Text(context.state.alarmTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))

                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .fill(
                            context.state.isEmpty
                                ? AnyShapeStyle(Color.emptyGray.opacity(0.3))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [.accentLavender, .accentPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                        .frame(width: 24, height: 24)

                    Image(systemName: context.state.isEmpty ? "alarm" : "alarm.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(context.state.isEmpty ? .emptyGray : .white)
                }
            } compactTrailing: {
                if context.state.isEmpty {
                    Text("--:--")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.emptyGray)
                } else {
                    Text(context.state.nextAlarmTime)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(context.state.isSkipped ? .skipOrange : .accentLavender)
                }
            } minimal: {
                ZStack {
                    Circle()
                        .fill(
                            context.state.isEmpty
                                ? AnyShapeStyle(Color.emptyGray.opacity(0.3))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [.accentLavender, .accentPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )

                    Image(systemName: context.state.isEmpty ? "alarm" : "alarm.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(context.state.isEmpty ? .emptyGray : .white)
                }
            }
            .keylineTint(context.state.isEmpty ? .emptyGray : .accentLavender)
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
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.emptyGray.opacity(0.2))
                    .frame(width: 52, height: 52)
                
                Image(systemName: "alarm")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.emptyGray)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("설정된 알람 없음")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.emptyGray)
                
                Text("알람을 추가해주세요")
                    .font(.subheadline)
                    .foregroundColor(.emptyGray.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Alarm Content
    
    private var alarmContent: some View {
        HStack(spacing: 16) {
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
                HStack(spacing: 8) {
                    Text("다음 알람")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentLavender)

                    if context.state.isSkipped {
                        HStack(spacing: 3) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 8))
                            Text("건너뛰기")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.skipOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.skipOrange.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(context.state.nextAlarmTime)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(context.state.nextAlarmDate)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))
                }

                Text(context.state.alarmTitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            VStack {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.15))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
