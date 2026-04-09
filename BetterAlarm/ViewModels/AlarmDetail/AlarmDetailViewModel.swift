import Foundation

// MARK: - AlarmDetailViewModel

/// 알람 생성/편집 화면의 상태를 관리하는 ViewModel.
/// Swift 6: @MainActor + @Observable. SwiftUI import 금지.
@MainActor
@Observable
final class AlarmDetailViewModel {
    // MARK: - Editable State

    var isPM: Bool        // true = 오후, false = 오전
    var displayHour: Int  // 1~12
    var minute: Int
    var title: String = ""
    var selectedWeekdays: Set<Weekday> = []
    var scheduleType: ScheduleType = .once
    var specificDate: Date = Date()
    var alarmMode: AlarmMode = .local
    var isSilentAlarm: Bool = false
    var soundName: String = "default"

    /// 24시간 형식의 hour (0-23). AlarmStore에 저장할 때 사용.
    var hour: Int {
        if displayHour == 12 {
            return isPM ? 12 : 0
        }
        return isPM ? displayHour + 12 : displayHour
    }

    // MARK: - Toast / Alert State

    private(set) var showAlarmKitUnavailableToast: Bool = false
    private(set) var toastMessage: String = ""
    private(set) var showActionToast: Bool = false
    private(set) var actionToastMessage: String = ""
    private(set) var earphoneWarning: String? = nil
    private(set) var isSaving: Bool = false
    private(set) var isDeleting: Bool = false
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

    init(store: AlarmStore, audioService: AudioService = AudioService(volumeService: VolumeService()), editingAlarm: Alarm? = nil) {
        self.store = store
        self.audioService = audioService
        self.editingAlarm = editingAlarm

        // 기본값: 현재 시간 + 1분
        let now = Date().addingTimeInterval(60)
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        self.isPM = currentHour >= 12
        self.displayHour = currentHour == 0 ? 12 : (currentHour > 12 ? currentHour - 12 : currentHour)
        self.minute = currentMinute

        if let alarm = editingAlarm {
            populateFromAlarm(alarm)
        }
    }

    // MARK: - Populate

    private func populateFromAlarm(_ alarm: Alarm) {
        let h = alarm.hour
        isPM = h >= 12
        displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
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

    func toggleAlarmMode(wantsAlarmKit: Bool) {
        if wantsAlarmKit {
            if #available(iOS 26, *) {
                alarmMode = .alarmKit
                isSilentAlarm = false
            } else {
                alarmMode = .local
                toastMessage = AlarmError.alarmKitUnavailable.errorDescription
                    ?? "이 기능은 iOS 26 이상에서만 사용할 수 있습니다."
                showAlarmKitUnavailableToast = true
            }
        } else {
            alarmMode = .local
        }
    }

    func dismissToast() {
        showAlarmKitUnavailableToast = false
        toastMessage = ""
    }

    func dismissActionToast() {
        showActionToast = false
        actionToastMessage = ""
    }

    // MARK: - Silent Alarm 유효성 검사

    func validateSilentAlarm(enabled: Bool) async {
        guard enabled else {
            isSilentAlarm = false
            earphoneWarning = nil
            return
        }
        guard alarmMode != .alarmKit else {
            isSilentAlarm = false
            earphoneWarning = nil
            return
        }
        isSilentAlarm = true
        let connected = await audioService.isEarphoneConnected()
        if connected {
            earphoneWarning = nil
        } else {
            earphoneWarning = "이어폰이 연결되어 있지 않습니다. 알람 시각에 이어폰을 연결해주세요."
        }
    }

    func clearEarphoneWarning() {
        earphoneWarning = nil
    }

    func clearSaveError() {
        saveError = nil
    }

    // MARK: - Delete

    func deleteAlarm() async {
        guard let alarm = editingAlarm else { return }
        isDeleting = true
        defer { isDeleting = false }
        await store.deleteAlarm(alarm)
    }

    // MARK: - Save

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
            actionToastMessage = "알람이 수정되었습니다"
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
            actionToastMessage = "알람이 저장되었습니다"
        }
        showActionToast = true
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
