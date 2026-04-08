import Foundation

// MARK: - AlarmDetailViewModel

/// 알람 생성/편집 화면의 상태를 관리하는 ViewModel.
/// Swift 6: @MainActor + @Observable. SwiftUI import 금지.
@MainActor
@Observable
final class AlarmDetailViewModel {
    // MARK: - Editable State

    var hour: Int = 8
    var minute: Int = 0
    var title: String = ""
    var selectedWeekdays: Set<Weekday> = []
    var scheduleType: ScheduleType = .once
    var specificDate: Date = Date()
    var alarmMode: AlarmMode = .local
    var isSilentAlarm: Bool = false
    var soundName: String = "default"

    // MARK: - Toast / Alert State

    private(set) var showAlarmKitUnavailableToast: Bool = false
    private(set) var toastMessage: String = ""
    private(set) var earphoneWarning: String? = nil
    private(set) var isSaving: Bool = false
    private(set) var saveError: String? = nil

    // MARK: - Mode

    enum ScheduleType: String, CaseIterable, Sendable {
        case once = "1회"
        case weekly = "주간 반복"
        case specificDate = "특정 날짜"
    }

    // MARK: - Dependencies

    private let store: AlarmStore
    private let audioService: AudioService
    private let editingAlarm: Alarm?

    var isEditing: Bool { editingAlarm != nil }

    init(store: AlarmStore, audioService: AudioService = AudioService(), editingAlarm: Alarm? = nil) {
        self.store = store
        self.audioService = audioService
        self.editingAlarm = editingAlarm
        if let alarm = editingAlarm {
            populateFromAlarm(alarm)
        }
    }

    // MARK: - Populate

    private func populateFromAlarm(_ alarm: Alarm) {
        hour = alarm.hour
        minute = alarm.minute
        title = alarm.title
        soundName = alarm.soundName
        alarmMode = alarm.alarmMode
        isSilentAlarm = alarm.isSilentAlarm
        switch alarm.schedule {
        case .once:
            scheduleType = .once
        case .weekly(let days):
            scheduleType = .weekly
            selectedWeekdays = days
        case .specificDate(let date):
            scheduleType = .specificDate
            specificDate = date
        }
    }

    // MARK: - AlarmMode 토글 (iOS 버전 체크)

    /// "앱이 꺼진 상태에서도 알람 받기" 토글 처리.
    /// iOS 26 미만이면 토글을 ON으로 바꾸지 않고 토스트 메시지를 표시한다.
    func toggleAlarmMode(wantsAlarmKit: Bool) {
        if wantsAlarmKit {
            if #available(iOS 26, *) {
                alarmMode = .alarmKit
                // alarmKit 모드에서는 조용한 알람 비활성화
                isSilentAlarm = false
            } else {
                // iOS 26 미만: 토글 ON 거부 + 토스트 표시
                alarmMode = .local
                toastMessage = AlarmError.alarmKitUnavailable.errorDescription
                    ?? "이 기능은 iOS 26 이상에서만 사용할 수 있습니다."
                showAlarmKitUnavailableToast = true
            }
        } else {
            alarmMode = .local
        }
    }

    /// 토스트 표시 후 dismissal 처리
    func dismissToast() {
        showAlarmKitUnavailableToast = false
        toastMessage = ""
    }

    // MARK: - Silent Alarm 유효성 검사

    /// 조용한 알람 토글 ON 시도 시 이어폰 연결 여부 확인
    func validateSilentAlarm(enabled: Bool) async {
        guard enabled else {
            isSilentAlarm = false
            earphoneWarning = nil
            return
        }
        guard alarmMode != .alarmKit else {
            // alarmKit 모드에서는 조용한 알람 비활성화
            isSilentAlarm = false
            earphoneWarning = nil
            return
        }
        let connected = await audioService.isEarphoneConnected()
        if connected {
            isSilentAlarm = true
            earphoneWarning = nil
        } else {
            isSilentAlarm = false
            earphoneWarning = "이어폰이 연결되어 있지 않습니다. 조용한 알람은 이어폰 연결 후 사용할 수 있습니다."
        }
    }

    func clearEarphoneWarning() {
        earphoneWarning = nil
    }

    func clearSaveError() {
        saveError = nil
    }

    // MARK: - Save

    /// 편집 내용을 저장한다. 신규 생성 또는 기존 알람 업데이트.
    func save() async {
        isSaving = true
        defer { isSaving = false }
        saveError = nil

        let schedule = buildSchedule()

        if let alarm = editingAlarm {
            await store.updateAlarm(
                alarm,
                hour: hour,
                minute: minute,
                title: title,
                schedule: schedule,
                soundName: soundName,
                alarmMode: alarmMode,
                isSilentAlarm: isSilentAlarm
            )
        } else {
            await store.createAlarm(
                hour: hour,
                minute: minute,
                title: title,
                schedule: schedule,
                soundName: soundName,
                alarmMode: alarmMode,
                isSilentAlarm: isSilentAlarm
            )
        }
    }

    // MARK: - Private Helpers

    private func buildSchedule() -> AlarmSchedule {
        switch scheduleType {
        case .once:
            return .once
        case .weekly:
            return selectedWeekdays.isEmpty ? .once : .weekly(selectedWeekdays)
        case .specificDate:
            return .specificDate(specificDate)
        }
    }
}
