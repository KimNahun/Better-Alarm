import SwiftUI
import PersonalColorDesignSystem

// MARK: - AlarmRowView

/// 알람 목록의 개별 행 컴포넌트.
/// GlassCardView 컴포넌트 사용, PersonalColorDesignSystem 토큰 사용 필수.
struct AlarmRowView: View {
    let alarm: Alarm
    let onToggle: (Bool) -> Void
    var onTap: (() -> Void)? = nil
    @Environment(\.pThemeColors) private var theme

    var body: some View {
        GlassCard {
            HStack(spacing: 0) {
                // 알람 타입 구분선
                RoundedRectangle(cornerRadius: 1)
                    .fill(alarmTypeColor)
                    .frame(width: 2)
                    .padding(.vertical, 12)

                HStack(spacing: 16) {
                    // 시간 + 제목 (탭 영역)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alarm.timeString)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.pTextPrimary)
                            .accessibilityLabel(Text("alarm_row_time_a11y \(alarm.timeString)"))

                        Text(alarm.displayTitle)
                            .font(.body)
                            .foregroundStyle(Color.pTextSecondary)
                            .lineLimit(1)

                        // 반복 설명
                        HStack(spacing: 6) {
                            Text(alarm.repeatDescriptionWithoutSkip)
                                .font(.caption)
                                .foregroundStyle(Color.pTextSecondary)

                            if alarm.isSkippingNext {
                                Text("alarm_row_skipping_next")
                                    .font(.caption)
                                    .foregroundStyle(Color.pWarning)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.pWarning.opacity(0.15))
                                    .clipShape(Capsule())
                                    .minimumScaleFactor(0.85)
                            }

                            if alarm.alarmMode == .alarmKit {
                                Image(systemName: "bell.and.waves.left.and.right.fill")
                                    .font(.caption)
                                    .foregroundStyle(theme.accentPrimary)
                                    .accessibilityLabel(Text("alarm_row_alarmkit_a11y"))
                            }

                            if alarm.isSnoozed {
                                Text("alarm_row_snoozed")
                                    .font(.caption)
                                    .foregroundStyle(theme.accentSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.accentSecondary.opacity(0.15))
                                    .clipShape(Capsule())
                                    .minimumScaleFactor(0.85)
                            }

                            if alarm.isSilentAlarm {
                                Image(systemName: "headphones")
                                    .font(.caption)
                                    .foregroundStyle(theme.accentSecondary)
                                    .accessibilityLabel(Text("alarm_row_silent_a11y"))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap?()
                    }

                    // 활성화 토글
                    // R8-1: "다음 1회만 끄기"가 활성화되어 있으면 시각적으로 OFF로 표시.
                    // (alarm.isEnabled && !alarm.isSkippingNext) 가 토글의 시각 상태.
                    PToggle("", isOn: Binding(
                        get: { alarm.isEnabled && !alarm.isSkippingNext },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                    .accessibilityLabel(Text("alarm_row_toggle_a11y_format \(alarm.displayTitle) \((alarm.isEnabled && !alarm.isSkippingNext) ? String(localized: "alarm_row_toggle_disable") : String(localized: "alarm_row_toggle_enable"))"))
                    .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var alarmTypeColor: Color {
        switch alarm.schedule {
        case .weekly: return theme.accentPrimary
        case .once: return theme.accentSecondary
        case .specificDate: return theme.success
        }
    }
}

// MARK: - AlarmSwipeActions ViewModifier

/// AlarmListView와 WeeklyAlarmView에서 공유하는 swipe actions.
/// 코드 중복 제거를 위해 ViewModifier로 분리.
struct AlarmSwipeActionsModifier: ViewModifier {
    let alarm: Alarm
    let onDelete: () -> Void
    let onSkip: () -> Void
    let onClearSkip: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                if alarm.isWeeklyAlarm && alarm.isEnabled {
                    if alarm.isSkippingNext {
                        Button {
                            onClearSkip()
                        } label: {
                            Label("alarm_row_swipe_clear_skip", systemImage: "arrow.uturn.backward")
                        }
                        .tint(Color.pWarning)
                    } else {
                        Button {
                            onSkip()
                            HapticManager.impact(.medium)
                        } label: {
                            Label("alarm_row_swipe_skip_once", systemImage: "forward.fill")
                        }
                        .tint(Color.pAccentSecondary)
                    }
                }
            }
    }
}

extension View {
    func alarmSwipeActions(
        alarm: Alarm,
        onDelete: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onClearSkip: @escaping () -> Void
    ) -> some View {
        modifier(AlarmSwipeActionsModifier(
            alarm: alarm,
            onDelete: onDelete,
            onSkip: onSkip,
            onClearSkip: onClearSkip
        ))
    }
}
