import Foundation

// MARK: - WeeklyAlarmViewModel

/// 주간 알람 화면의 상태를 관리하는 ViewModel.
/// AlarmStore에서 .weekly 스케줄만 필터링하여 표시.
/// Swift 6: @MainActor + @Observable. SwiftUI import 금지.
@MainActor
@Observable
final class WeeklyAlarmViewModel {
    // MARK: - State

    private(set) var weeklyAlarms: [Alarm] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    var selectedDay: Weekday? = nil
    private(set) var showToast: Bool = false
    private(set) var toastMessage: String = ""

    // MARK: - Computed

    var filteredAlarms: [Alarm] {
        guard let day = selectedDay else { return weeklyAlarms }
        return weeklyAlarms.filter { alarm in
            if case .weekly(let days) = alarm.schedule {
                return days.contains(day)
            }
            return false
        }
    }

    // MARK: - Dependencies

    private let store: AlarmStore

    init(store: AlarmStore) {
        self.store = store
    }

    // MARK: - Actions

    /// 주간 반복 알람 목록을 로드한다.
    func loadAlarms() async {
        isLoading = true
        defer { isLoading = false }

        await store.loadAlarms()
        await refreshState()
        AppLogger.info("Weekly alarms loaded: \(weeklyAlarms.count)", category: .store)
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
        weeklyAlarms = allAlarms.filter { alarm in
            if case .weekly = alarm.schedule { return true }
            return false
        }
    }
}
