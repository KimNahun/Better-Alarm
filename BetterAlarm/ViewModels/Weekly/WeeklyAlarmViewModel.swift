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
    }

    /// 알람 삭제
    func deleteAlarm(_ alarm: Alarm) async {
        await store.deleteAlarm(alarm)
        await refreshState()
    }

    /// 다음 1회 건너뛰기
    func skipOnceAlarm(_ alarm: Alarm) async {
        await store.skipOnceAlarm(alarm)
        await refreshState()
    }

    /// 건너뛰기 취소
    func clearSkip(_ alarm: Alarm) async {
        await store.clearSkipOnceAlarm(alarm)
        await refreshState()
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
