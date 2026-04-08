import Foundation

// MARK: - SettingsViewModel

/// 설정 화면의 상태를 관리하는 ViewModel.
/// Swift 6: @MainActor + @Observable. SwiftUI import 금지.
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - State

    private(set) var isLiveActivityEnabled: Bool = true

    private(set) var alarmKitAuthStatus: String = "확인 중..."
    private(set) var appVersion: String = ""
    private(set) var buildNumber: String = ""
    private(set) var isLoading: Bool = false

    // MARK: - Dependencies

    private let liveActivityManager: LiveActivityManager?
    private let alarmStore: AlarmStore

    init(liveActivityManager: LiveActivityManager? = nil, alarmStore: AlarmStore) {
        self.liveActivityManager = liveActivityManager
        self.alarmStore = alarmStore
        loadAppInfo()
    }

    // MARK: - Load

    /// 설정값을 비동기적으로 로드한다.
    func loadSettings() async {
        isLoading = true
        defer { isLoading = false }

        // Live Activity 상태 로드
        if #available(iOS 17.0, *), let manager = liveActivityManager {
            isLiveActivityEnabled = await manager.isLiveActivityEnabled
        }

        // AlarmKit 권한 상태 확인 (iOS 26+)
        await loadAlarmKitAuthStatus()
    }

    // MARK: - Live Activity Setting

    /// Live Activity 활성화/비활성화를 설정하고 LiveActivityManager에 동기화한다.
    func setLiveActivityEnabled(_ enabled: Bool) async {
        isLiveActivityEnabled = enabled
        await syncLiveActivitySetting(enabled)
    }

    // MARK: - Private

    /// Live Activity 설정을 LiveActivityManager에 동기화한다.
    private func syncLiveActivitySetting(_ enabled: Bool) async {
        if #available(iOS 17.0, *), let manager = liveActivityManager {
            await manager.setLiveActivityEnabled(enabled)
            if enabled {
                let nextAlarm = await alarmStore.nextAlarm
                await manager.updateActivity(nextAlarm: nextAlarm)
            } else {
                await manager.endActivity()
            }
            AppLogger.info("Live Activity setting synced: \(enabled)", category: .settings)
        }
    }

    /// AlarmKit 권한 상태를 확인한다.
    private func loadAlarmKitAuthStatus() async {
        if #available(iOS 26.0, *) {
            let service = AlarmKitService()
            let authorized = await service.requestPermission()
            alarmKitAuthStatus = authorized ? "허용됨" : "허용 안 됨"
        } else {
            alarmKitAuthStatus = "iOS 26 이상 필요"
        }
    }

    /// Bundle에서 앱 버전 및 빌드 번호를 읽는다.
    private func loadAppInfo() {
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
