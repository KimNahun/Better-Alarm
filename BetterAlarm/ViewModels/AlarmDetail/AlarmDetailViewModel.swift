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
        case once = "once"
        case weekly = "weekly"
        case specificDate = "specificDate"

        /// 로케일 인지형 표시 이름 (UI에서 사용)
        var displayName: String {
            switch self {
            case .once:         return String(localized: "alarm_detail_schedule_once")
            case .weekly:       return String(localized: "alarm_detail_schedule_weekly")
            case .specificDate: return String(localized: "alarm_detail_schedule_specific_date")
            }
        }
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
            AppLogger.info("AlarmDetailViewModel init — editing: '\(alarm.displayTitle)'", category: .ui)
        } else {
            AppLogger.info("AlarmDetailViewModel init — creating new alarm", category: .ui)
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
                AppLogger.info("AlarmMode set to .alarmKit", category: .ui)
            } else {
                alarmMode = .local
                toastMessage = AlarmError.alarmKitUnavailable.errorDescription
                    ?? String(localized: "toast_alarmkit_unavailable")
                showAlarmKitUnavailableToast = true
                AppLogger.warning("AlarmKit requested but iOS < 26 — showing unavailable toast", category: .ui)
            }
        } else {
            alarmMode = .local
            AppLogger.info("AlarmMode set to .local", category: .ui)
        }
    }

    func dismissToast() {
        showAlarmKitUnavailableToast = false
        toastMessage = ""
    }

    // MARK: - ScheduleType 변경 시 iOS 버전 체크

    /// specificDate 선택 시 iOS 26 미만이면 .once로 되돌리고 토스트를 표시한다.
    func handleScheduleTypeChange() {
        if scheduleType == .specificDate {
            if #available(iOS 26, *) {
                // iOS 26+: AlarmKit 기반이므로 alarmMode를 alarmKit으로 강제
                alarmMode = .alarmKit
                AppLogger.info("ScheduleType .specificDate → forcing .alarmKit mode", category: .ui)
            } else {
                scheduleType = .once
                toastMessage = String(localized: "alarm_detail_specific_date_unavailable")
                showAlarmKitUnavailableToast = true
                AppLogger.warning("ScheduleType .specificDate unavailable on iOS < 26 — reverting to .once", category: .ui)
            }
        } else {
            AppLogger.debug("ScheduleType changed to \(scheduleType.rawValue)", category: .ui)
        }
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
            AppLogger.debug("Silent alarm disabled", category: .ui)
            return
        }
        guard alarmMode != .alarmKit else {
            isSilentAlarm = false
            earphoneWarning = nil
            AppLogger.debug("Silent alarm rejected — AlarmKit mode is active", category: .ui)
            return
        }
        isSilentAlarm = true
        let connected = await audioService.isEarphoneConnected()
        if connected {
            earphoneWarning = nil
            AppLogger.info("Silent alarm enabled — earphone connected", category: .ui)
        } else {
            earphoneWarning = String(localized: "alarm_detail_earphone_warning")
            AppLogger.warning("Silent alarm enabled but earphone not connected", category: .ui)
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
        AppLogger.info("Deleting alarm from detail: '\(alarm.displayTitle)'", category: .alarm)
        await store.deleteAlarm(alarm)
    }

    // MARK: - Save

    func save() async {
        // 주간 알람은 최소 1개 이상의 요일이 선택되어야 저장 가능
        guard !(scheduleType == .weekly && selectedWeekdays.isEmpty) else {
            AppLogger.warning("Save blocked — weekly alarm with no weekdays selected", category: .alarm)
            return
        }

        isSaving = true
        defer { isSaving = false }
        saveError = nil

        let schedule = buildSchedule()

        if let alarm = editingAlarm {
            AppLogger.info("Saving alarm update: '\(title.isEmpty ? "(no title)" : title)' \(hour):\(String(format: "%02d", minute)) schedule=\(scheduleType.rawValue) mode=\(alarmMode)", category: .alarm)
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
            actionToastMessage = String(localized: "toast_alarm_updated")
        } else {
            AppLogger.info("Saving new alarm: '\(title.isEmpty ? "(no title)" : title)' \(hour):\(String(format: "%02d", minute)) schedule=\(scheduleType.rawValue) mode=\(alarmMode) silent=\(isSilentAlarm)", category: .alarm)
            await store.createAlarm(
                hour: hour,
                minute: minute,
                title: title,
                schedule: schedule,
                soundName: soundName,
                alarmMode: alarmMode,
                isSilentAlarm: isSilentAlarm
            )
            actionToastMessage = String(localized: "toast_alarm_saved")
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
