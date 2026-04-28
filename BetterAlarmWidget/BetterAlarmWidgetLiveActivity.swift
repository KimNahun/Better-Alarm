import ActivityKit
import WidgetKit
import SwiftUI
import PersonalColorDesignSystem

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
        var themeName: String       // PTheme.rawValue — 위젯 테마 색상 동기화

        init(
            nextAlarmTime: String,
            nextAlarmDate: String,
            alarmTitle: String,
            isSkipped: Bool,
            isEmpty: Bool = false,
            themeName: String = "summer"
        ) {
            self.nextAlarmTime = nextAlarmTime
            self.nextAlarmDate = nextAlarmDate
            self.alarmTitle = alarmTitle
            self.isSkipped = isSkipped
            self.isEmpty = isEmpty
            self.themeName = themeName
        }
    }

    var alarmId: String
}

// MARK: - Theme Palette

/// 위젯에서 사용하는 테마 색상 팔레트.
/// PersonalColorDesignSystem.PTheme.summer.colors 를 단일 출처로 직접 참조한다.
struct WidgetTheme {
    let backgroundFrom: Color
    let backgroundTo: Color
    let accentFrom: Color
    let accentTo: Color
    let labelAccent: Color

    /// 색상 선택 기능 제거 — 항상 Summer 팔레트를 반환한다.
    /// 매개변수는 호환을 위해 유지하지만 무시된다.
    static func palette(for themeName: String) -> WidgetTheme {
        let c = PTheme.summer.colors
        return WidgetTheme(
            backgroundFrom: c.backgroundTop,
            backgroundTo:   c.backgroundBottom,
            accentFrom:     c.accentPrimary,
            accentTo:       c.accentSecondary,
            labelAccent:    c.accentPrimary
        )
    }
}

// MARK: - Live Activity Widget

struct BetterAlarmWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
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
                Text(" ")
                    .font(.system(size: 1))
                    .foregroundColor(.clear)
            } compactTrailing: {
                Text(" ")
                    .font(.system(size: 1))
                    .foregroundColor(.clear)
            } minimal: {
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

    private var theme: WidgetTheme {
        WidgetTheme.palette(for: context.state.themeName)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundFrom, theme.backgroundTo],
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

    // MARK: - Empty State

    private var emptyStateContent: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.accentFrom.opacity(0.15))
                    .frame(width: 46, height: 46)

                Image(systemName: "alarm")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(theme.accentFrom.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("설정된 알람 없음")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))

                Text("알람을 추가해주세요")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.30))
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
                            colors: [theme.accentFrom, theme.accentTo],
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
                HStack(spacing: 6) {
                    Text("다음 알람")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.labelAccent)

                    if context.state.isSkipped {
                        Text("건너뛰기")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.20))
                            .clipShape(Capsule())
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(context.state.nextAlarmTime)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.85)

                    Text(context.state.nextAlarmDate)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.60))
                }

                if !context.state.alarmTitle.isEmpty {
                    Text(context.state.alarmTitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.80))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 18))
                .foregroundColor(theme.accentFrom.opacity(0.25))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

// MARK: - Previews

#Preview("Winter", as: .content, using: AlarmActivityAttributes(alarmId: "preview")) {
    BetterAlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오전 7:30",
        nextAlarmDate: "5월 1일",
        alarmTitle: "출근 알람",
        isSkipped: false,
        themeName: "winter"
    )
}

#Preview("Summer", as: .content, using: AlarmActivityAttributes(alarmId: "preview")) {
    BetterAlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오전 7:30",
        nextAlarmDate: "5월 1일",
        alarmTitle: "출근 알람",
        isSkipped: false,
        themeName: "summer"
    )
}

#Preview("Spring", as: .content, using: AlarmActivityAttributes(alarmId: "preview")) {
    BetterAlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오전 8:00",
        nextAlarmDate: "4월 28일",
        alarmTitle: "아침 운동",
        isSkipped: false,
        themeName: "spring"
    )
}

#Preview("Autumn", as: .content, using: AlarmActivityAttributes(alarmId: "preview")) {
    BetterAlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "오후 2:00",
        nextAlarmDate: "1월 22일",
        alarmTitle: "회의",
        isSkipped: true,
        themeName: "autumn"
    )
}

#Preview("Empty", as: .content, using: AlarmActivityAttributes(alarmId: "empty")) {
    BetterAlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState(
        nextAlarmTime: "--:--",
        nextAlarmDate: "",
        alarmTitle: "",
        isSkipped: false,
        isEmpty: true,
        themeName: "winter"
    )
}
