import SwiftUI
import PersonalColorDesignSystem

// MARK: - AlarmRingingView

/// 알람 울림 전체 화면. PGradientBackground + 시간 표시 + 정지/스누즈 버튼.
/// MVVM: View는 UI 선언만. 비즈니스 로직은 ViewModel로.
struct AlarmRingingView: View {
    @State private var viewModel: AlarmRingingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pThemeColors) private var theme

    init(
        alarm: Alarm,
        audioService: AudioService,
        volumeService: VolumeService,
        alarmStore: AlarmStore
    ) {
        _viewModel = State(initialValue: AlarmRingingViewModel(
            alarm: alarm,
            audioService: audioService,
            volumeService: volumeService,
            alarmStore: alarmStore,
            onStopHaptic: { HapticManager.notification(.success) },
            onSnoozeHaptic: { HapticManager.impact() }
        ))
    }

    var body: some View {
        ZStack {
            PGradientBackground()

            VStack(spacing: 0) {
                Spacer()

                // 현재 시간
                timeDisplay

                Spacer()
                    .frame(height: 24)

                // 알람 제목
                alarmTitleDisplay

                Spacer()

                // 버튼 영역
                buttonArea

                Spacer()
                    .frame(height: 60)
            }
            .padding(.horizontal, 32)
        }
        .task {
            await viewModel.startRinging()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: - Subviews

    private var timeDisplay: some View {
        Text(viewModel.currentTimeString)
            .font(.system(.largeTitle, design: .rounded, weight: .ultraLight))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .foregroundStyle(Color.pTextPrimary)
            .accessibilityLabel("현재 시각: \(viewModel.currentTimeString)")
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var alarmTitleDisplay: some View {
        Text(viewModel.alarm.displayTitle)
            .font(.title.weight(.semibold))
            .foregroundStyle(Color.pTextPrimary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .accessibilityLabel("알람 이름: \(viewModel.alarm.displayTitle)")
    }

    private var buttonArea: some View {
        VStack(spacing: 20) {
            // 정지 버튼 (큰 원형)
            Button {
                Task {
                    await viewModel.stopAlarm()
                    dismiss()
                }
            } label: {
                Text("정지")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(theme.accentPrimary)
                    .clipShape(Circle())
            }
            .accessibilityLabel("알람 정지")
            .accessibilityHint("알람을 끕니다")

            // 스누즈 버튼 (작은 캡슐형 아웃라인)
            Button {
                Task {
                    await viewModel.snoozeAlarm()
                    dismiss()
                }
            } label: {
                Text("스누즈 (5분)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.accentSecondary)
                    .frame(minWidth: 160, minHeight: 48)
                    .overlay(
                        Capsule()
                            .stroke(theme.accentSecondary, lineWidth: 1.5)
                    )
            }
            .accessibilityLabel("스누즈")
            .accessibilityHint("5분 후 다시 알람이 울립니다")
        }
    }
}
