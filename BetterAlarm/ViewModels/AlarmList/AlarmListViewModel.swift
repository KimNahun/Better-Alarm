import Foundation

// MARK: - AlarmListViewModel

/// 알람 목록 화면의 상태를 관리하는 ViewModel.
/// Swift 6: @MainActor + @Observable 필수.
/// SwiftUI import 금지 — UI 타입(Color, Font 등) 소유 불가.
@MainActor
@Observable
final class AlarmListViewModel {
    // MARK: - State

    private(set) var alarms: [Alarm] = []
    private(set) var nextAlarmDisplayString: String?
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var showToast: Bool = false
    private(set) var toastMessage: String = ""
    private(set) var pendingDisableAlarm: Alarm? = nil
    private(set) var togglingAlarmID: UUID? = nil

    // MARK: - Dependencies

    private let store: AlarmStore

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
        await store.toggleAlarm(alarm, enabled: enabled)
        await refreshState()
        showToastMessage(enabled ? "알람이 켜졌습니다" : "알람이 꺼졌습니다")
    }

    /// 이번만 스킵 (isEnabled는 유지)
    func skipOnceAndDisable(_ alarm: Alarm) async {
        AppLogger.info("Skip-once selected for weekly alarm: '\(alarm.displayTitle)'", category: .action)
        await store.skipOnceAlarm(alarm)
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
        await store.deleteAlarm(alarm)
        await refreshState()
        showToastMessage("알람이 삭제되었습니다")
    }

    /// 다음 1회 건너뛰기
    func skipOnceAlarm(_ alarm: Alarm) async {
        await store.skipOnceAlarm(alarm)
        await refreshState()
        showToastMessage("다음 1회 건너뜁니다")
    }

    /// 건너뛰기 취소
    func clearSkip(_ alarm: Alarm) async {
        await store.clearSkipOnceAlarm(alarm)
        await refreshState()
        showToastMessage("건너뛰기가 취소되었습니다")
    }

    func dismissToast() {
        showToast = false
        toastMessage = ""
    }

    func showSaveToast(isEditing: Bool) {
        showToastMessage(isEditing ? "알람이 수정되었습니다" : "알람이 저장되었습니다")
    }

    func showDeleteToast() {
        showToastMessage("알람이 삭제되었습니다")
    }

    func showToastMessage(_ message: String) {
        // E6 수정: false→true 전환을 Task로 분리해 SwiftUI 배치 업데이트 경쟁 조건 방지.
        // 동일 메시지 재호출 시에도 false→true 전환이 새 런루프에서 발생하므로 onChange가 확실히 발동.
        toastMessage = message
        showToast = false
        Task { @MainActor [weak self] in
            self?.showToast = true
        }
    }

    // MARK: - Private

    private func refreshState() async {
        let allAlarms = await store.alarms
        alarms = allAlarms
        nextAlarmDisplayString = await store.nextAlarmDisplayString
    }
}
