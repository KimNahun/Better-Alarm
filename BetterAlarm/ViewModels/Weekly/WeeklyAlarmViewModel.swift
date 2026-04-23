import Foundation

// MARK: - WeeklyAlarmViewModel

/// 주간 알람 화면의 상태를 관리하는 ViewModel.
/// AlarmStore에서 .weekly 스케줄만 필터링하여 표시.
/// Swift 6: @MainActor + @Observable. SwiftUI import 금지.
/// 공통 토글/삭제/건너뛰기 로직은 AlarmToggleHandling 프로토콜에서 제공.
@MainActor
@Observable
final class WeeklyAlarmViewModel: AlarmToggleHandling {
    // MARK: - State

    private(set) var weeklyAlarms: [Alarm] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    var selectedDay: Weekday? = nil
    var showToast: Bool = false
    var toastMessage: String = ""
    var pendingDisableAlarm: Alarm? = nil
    var togglingAlarmID: UUID? = nil

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
    var alarmToggleStore: AlarmStore { store }

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

    // MARK: - AlarmToggleHandling

    func refreshState() async {
        let allAlarms = await store.alarms
        weeklyAlarms = allAlarms.filter { alarm in
            if case .weekly = alarm.schedule { return true }
            return false
        }
    }
}
