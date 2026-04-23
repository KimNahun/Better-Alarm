import Foundation

// MARK: - AlarmRingingViewModel

/// 알람 울림 화면의 상태를 관리하는 ViewModel.
/// Swift 6: @MainActor + @Observable 필수.
/// SwiftUI import 금지 -- UI 타입(Color, Font 등) 소유 불가.
@MainActor
@Observable
final class AlarmRingingViewModel {
    // MARK: - State

    private(set) var currentTimeString: String = ""
    private(set) var isRinging: Bool = false

    let alarm: Alarm

    // MARK: - Dependencies

    private let audioService: AudioService
    private let volumeService: VolumeService
    private let alarmStore: AlarmStore
    private var timerTask: Task<Void, Never>?

    /// 햅틱 피드백 클로저 — View 레이어에서 HapticManager를 주입한다.
    private let onStopHaptic: @MainActor () -> Void
    private let onSnoozeHaptic: @MainActor () -> Void

    init(
        alarm: Alarm,
        audioService: AudioService,
        volumeService: VolumeService,
        alarmStore: AlarmStore,
        onStopHaptic: @escaping @MainActor () -> Void = {},
        onSnoozeHaptic: @escaping @MainActor () -> Void = {}
    ) {
        self.alarm = alarm
        self.audioService = audioService
        self.volumeService = volumeService
        self.alarmStore = alarmStore
        self.onStopHaptic = onStopHaptic
        self.onSnoozeHaptic = onSnoozeHaptic
        updateTimeString()
    }

    // MARK: - Actions

    /// 알람 사운드를 재생하고 시간 업데이트 타이머를 시작한다.
    func startRinging() async {
        guard !isRinging else { return }
        isRinging = true

        // 시간 업데이트 타이머 시작
        startTimeUpdateTimer()

        // 백그라운드 무음 루프가 실행 중이면 먼저 종료 (세션 충돌 방지)
        await audioService.stopSilentLoop()

        // 볼륨 먼저 올리기 (80% 보장) + 볼륨 가드 시작
        await volumeService.ensureMinimumVolume()
        await volumeService.startVolumeGuard()

        // 백그라운드에서 이미 재생 중이면 중복 재생 방지
        let alreadyPlaying = await audioService.isAlarmPlaying
        guard !alreadyPlaying else {
            AppLogger.info("Alarm already playing from background, skipping re-play", category: .alarm)
            return
        }

        // 사운드 재생
        do {
            try await audioService.playAlarmSound(
                soundName: alarm.soundName,
                isSilent: alarm.isSilentAlarm,
                loop: true
            )
            AppLogger.info("Alarm ringing started: \(alarm.displayTitle)", category: .alarm)
        } catch {
            AppLogger.error("Failed to play alarm sound: \(error)", category: .alarm)
        }
    }

    /// 알람을 정지하고 완료 처리한다.
    func stopAlarm() async {
        AppLogger.info("Alarm stopped by user: '\(alarm.displayTitle)'", category: .alarm)
        isRinging = false
        await volumeService.stopVolumeGuard()
        await audioService.stopAlarmSound()
        await alarmStore.handleAlarmCompleted(alarm)
        onStopHaptic()
        cleanup()
    }

    /// 스누즈: 사운드를 중지하고 5분 후 재알림을 예약한다.
    func snoozeAlarm() async {
        AppLogger.info("Alarm snoozed by user: '\(alarm.displayTitle)' — rescheduling in 5min", category: .alarm)
        isRinging = false
        await volumeService.stopVolumeGuard()
        await audioService.stopAlarmSound()
        await alarmStore.snoozeAlarm(alarm, minutes: 5)
        onSnoozeHaptic()
        cleanup()
    }

    /// 타이머 및 리소스 정리.
    func cleanup() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Private

    private func updateTimeString() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        currentTimeString = KoreanDateFormatters.timeDisplayString(hour: hour, minute: minute)
    }

    private func startTimeUpdateTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                updateTimeString()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
