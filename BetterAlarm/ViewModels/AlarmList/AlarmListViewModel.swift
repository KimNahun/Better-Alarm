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

    /// 알람 활성화/비활성화 토글
    func toggleAlarm(_ alarm: Alarm, enabled: Bool) async {
        await store.toggleAlarm(alarm, enabled: enabled)
        await refreshState()
        showToastMessage(enabled ? "알람이 켜졌습니다" : "알람이 꺼졌습니다")
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

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }

    // MARK: - Private

    private func refreshState() async {
        let allAlarms = await store.alarms
        // 비활성화된 1회성 알람은 목록에서 숨김
        alarms = allAlarms.filter { alarm in
            if !alarm.isEnabled {
                switch alarm.schedule {
                case .once, .specificDate:
                    return false // 1회성 알람은 꺼지면 숨김
                case .weekly:
                    return true  // 주간 반복은 꺼져있어도 표시
                }
            }
            return true
        }
        nextAlarmDisplayString = await store.nextAlarmDisplayString
    }
}
