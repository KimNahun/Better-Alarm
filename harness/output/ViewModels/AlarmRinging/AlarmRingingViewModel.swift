import Foundation
import UIKit

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

    init(
        alarm: Alarm,
        audioService: AudioService,
        volumeService: VolumeService,
        alarmStore: AlarmStore
    ) {
        self.alarm = alarm
        self.audioService = audioService
        self.volumeService = volumeService
        self.alarmStore = alarmStore
        updateTimeString()
    }

    // MARK: - Actions

    /// 알람 사운드를 재생하고 시간 업데이트 타이머를 시작한다.
    func startRinging() async {
        guard !isRinging else { return }
        isRinging = true

        // 시간 업데이트 타이머 시작
        startTimeUpdateTimer()

        // 볼륨 먼저 올리기 (80% 보장)
        await volumeService.ensureMinimumVolume()

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
        isRinging = false
        await audioService.stopAlarmSound()
        await alarmStore.handleAlarmCompleted(alarm)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        cleanup()
    }

    /// 스누즈: 사운드를 중지하고 5분 후 재알림을 예약한다.
    func snoozeAlarm() async {
        isRinging = false
        await audioService.stopAlarmSound()
        await alarmStore.snoozeAlarm(alarm, minutes: 5)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
