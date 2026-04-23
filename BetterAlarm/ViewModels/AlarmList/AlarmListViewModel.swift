import Foundation

// MARK: - AlarmToggleHandling

/// 알람 토글·삭제·건너뛰기 등 공통 조작 로직을 정의하는 프로토콜.
/// AlarmListViewModel, WeeklyAlarmViewModel이 공유한다.
@MainActor
protocol AlarmToggleHandling: AnyObject {
    var showToast: Bool { get set }
    var toastMessage: String { get set }
    var pendingDisableAlarm: Alarm? { get set }
    var togglingAlarmID: UUID? { get set }
    var alarmToggleStore: AlarmStore { get }

    /// 하위 클래스가 구현: 알람 목록 상태를 새로고침한다.
    func refreshState() async
}

extension AlarmToggleHandling {
    /// 토글 요청 처리: 주간 알람 끄기 시 다이얼로그 표시
    func requestToggle(_ alarm: Alarm, enabled: Bool) {
        if !enabled, case .weekly = alarm.schedule {
            AppLogger.info("Weekly alarm disable requested — showing action sheet: '\(alarm.displayTitle)'", category: .action)
            pendingDisableAlarm = alarm
        } else {
            Task { await toggleAlarm(alarm, enabled: enabled) }
        }
    }

    /// 알람 활성화/비활성화 토글
    func toggleAlarm(_ alarm: Alarm, enabled: Bool) async {
        togglingAlarmID = alarm.id
        defer { togglingAlarmID = nil }
        await alarmToggleStore.toggleAlarm(alarm, enabled: enabled)
        await refreshState()
        showToastMessage(enabled ? "알람이 켜졌습니다" : "알람이 꺼졌습니다")
    }

    /// 이번만 스킵 (isEnabled는 유지)
    func skipOnceAndDisable(_ alarm: Alarm) async {
        AppLogger.info("Skip-once selected for weekly alarm: '\(alarm.displayTitle)'", category: .action)
        await alarmToggleStore.skipOnceAlarm(alarm)
        pendingDisableAlarm = nil
        await refreshState()
        showToastMessage("다음 1회 건너뜁니다")
    }

    /// 완전히 끄기
    func confirmDisable(_ alarm: Alarm) async {
        AppLogger.info("Confirm disable selected for weekly alarm: '\(alarm.displayTitle)'", category: .action)
        await toggleAlarm(alarm, enabled: false)
        pendingDisableAlarm = nil
    }

    /// 다이얼로그 취소
    func cancelDisable() {
        AppLogger.debug("Disable action sheet cancelled", category: .action)
        pendingDisableAlarm = nil
    }

    /// 알람 삭제
    func deleteAlarm(_ alarm: Alarm) async {
        await alarmToggleStore.deleteAlarm(alarm)
        await refreshState()
        showToastMessage("알람이 삭제되었습니다")
    }

    /// 다음 1회 건너뛰기
    func skipOnceAlarm(_ alarm: Alarm) async {
        await alarmToggleStore.skipOnceAlarm(alarm)
        await refreshState()
        showToastMessage("다음 1회 건너뜁니다")
    }

    /// 건너뛰기 취소
    func clearSkip(_ alarm: Alarm) async {
        await alarmToggleStore.clearSkipOnceAlarm(alarm)
        await refreshState()
        showToastMessage("건너뛰기가 취소되었습니다")
    }

    func dismissToast() {
        showToast = false
        toastMessage = ""
    }

    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = false
        Task { @MainActor [weak self] in
            self?.showToast = true
        }
    }
}

// MARK: - AlarmListViewModel

/// 알람 목록 화면의 상태를 관리하는 ViewModel.
/// Swift 6: @MainActor + @Observable 필수.
/// SwiftUI import 금지 — UI 타입(Color, Font 등) 소유 불가.
@MainActor
@Observable
final class AlarmListViewModel: AlarmToggleHandling {
    // MARK: - State

    private(set) var alarms: [Alarm] = []
    private(set) var nextAlarmDisplayString: String?
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    var showToast: Bool = false
    var toastMessage: String = ""
    var pendingDisableAlarm: Alarm? = nil
    var togglingAlarmID: UUID? = nil

    // MARK: - Dependencies

    private let store: AlarmStore
    var alarmToggleStore: AlarmStore { store }

    init(store: AlarmStore = AlarmStore()) {
        self.store = store
    }

    // MARK: - Actions

    /// 저장된 알람 목록을 로드한다.
    func loadAlarms() async {
        isLoading = true
        defer { isLoading = false }
        await store.loadAlarms()
        await refreshState()
    }

    func showSaveToast(isEditing: Bool) {
        showToastMessage(isEditing ? "알람이 수정되었습니다" : "알람이 저장되었습니다")
    }

    func showDeleteToast() {
        showToastMessage("알람이 삭제되었습니다")
    }

    // MARK: - AlarmToggleHandling

    func refreshState() async {
        let allAlarms = await store.alarms
        alarms = allAlarms
        nextAlarmDisplayString = await store.nextAlarmDisplayString
    }
}
