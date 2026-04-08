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
        alarms = await store.alarms
        nextAlarmDisplayString = await store.nextAlarmDisplayString
    }
}
