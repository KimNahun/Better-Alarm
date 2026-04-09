import SwiftUI
import PersonalColorDesignSystem

// MARK: - AlarmRowView

/// 알람 목록의 개별 행 컴포넌트.
/// GlassCardView 컴포넌트 사용, PersonalColorDesignSystem 토큰 사용 필수.
struct AlarmRowView: View {
    let alarm: Alarm
    let onToggle: (Bool) -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: 0) {
                // 알람 타입 구분선
                RoundedRectangle(cornerRadius: 1)
                    .fill(alarmTypeColor)
                    .frame(width: 2)
                    .padding(.vertical, 12)

                HStack(spacing: 16) {
                    // 시간 + 제목
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alarm.timeString)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.pTextPrimary)
                            .accessibilityLabel("알람 시각: \(alarm.timeString)")

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
                                Text("다음 1회 건너뜀")
                                    .font(.caption)
                                    .foregroundStyle(Color.pWarning)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.pWarning.opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            if alarm.alarmMode == .alarmKit {
                                Image(systemName: "bell.and.waves.left.and.right.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.pAccentPrimary)
                                    .accessibilityLabel("AlarmKit 모드")
                            }

                            if alarm.isSnoozed {
                                Text("스누즈 중")
                                    .font(.caption)
                                    .foregroundStyle(Color.pAccentSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.pAccentSecondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            if alarm.isSilentAlarm {
                                Image(systemName: "headphones")
                                    .font(.caption)
                                    .foregroundStyle(Color.pAccentSecondary)
                                    .accessibilityLabel("조용한 알람")
                            }
                        }
                    }

                    Spacer()

                    // 활성화 토글
                    Toggle("", isOn: Binding(
                        get: { alarm.isEnabled },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                    .tint(Color.pAccentPrimary)
                    .accessibilityLabel("\(alarm.displayTitle) 알람 \(alarm.isEnabled ? "비활성화" : "활성화")")
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
        case .weekly: return Color.pAccentPrimary
        case .once: return Color.pAccentSecondary
        case .specificDate: return Color.pSuccess
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
                            Label("건너뛰기 취소", systemImage: "arrow.uturn.backward")
                        }
                        .tint(Color.pWarning)
                    } else {
                        Button {
                            onSkip()
                            HapticManager.impact(.medium)
                        } label: {
                            Label("1회 건너뛰기", systemImage: "forward.fill")
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
