import Foundation
import UserNotifications

// MARK: - SettingsViewModel

/// 설정 화면의 상태를 관리하는 ViewModel.
/// Swift 6: @MainActor + @Observable. SwiftUI import 금지.
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - State

    private(set) var isLiveActivityEnabled: Bool = true

    private(set) var alarmKitAuthStatus: String = "확인 중..."
    private(set) var notificationAuthStatus: String = "확인 중..."
    private(set) var lockScreenWidgetStatus: String = "확인 중..."
    private(set) var appVersion: String = ""
    private(set) var buildNumber: String = ""
    private(set) var isLoading: Bool = false

    // MARK: - Dependencies

    private let liveActivityManager: LiveActivityManager?
    private let alarmStore: AlarmStore
    private let alarmKitService: (any AlarmKitServiceProtocol)?
    var themeManager: AppThemeManager?

    init(
        liveActivityManager: LiveActivityManager? = nil,
        alarmStore: AlarmStore,
        alarmKitService: (any AlarmKitServiceProtocol)? = nil,
        themeManager: AppThemeManager? = nil
    ) {
        self.liveActivityManager = liveActivityManager
        self.alarmStore = alarmStore
        self.alarmKitService = alarmKitService
        self.themeManager = themeManager
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

        // 권한 상태 확인
        await refreshPermissions()
    }

    // MARK: - Live Activity Setting

    /// Live Activity 활성화/비활성화를 설정하고 LiveActivityManager에 동기화한다.
    func setLiveActivityEnabled(_ enabled: Bool) async {
        isLiveActivityEnabled = enabled
        await syncLiveActivitySetting(enabled)
    }

    // MARK: - Refresh Permissions

    /// 권한 상태를 실제로 읽기 (요청 안 함)
    func refreshPermissions() async {
        // 알림 권한 상태 확인
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        switch notificationSettings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationAuthStatus = "허용됨"
        case .denied:
            notificationAuthStatus = "허용 안 됨"
        case .notDetermined:
            notificationAuthStatus = "미설정"
        @unknown default:
            notificationAuthStatus = "알 수 없음"
        }

        // AlarmKit 권한 상태 확인 (요청 없이)
        await loadAlarmKitAuthStatus()

        // Lock Screen Widget (ActivityKit) 상태 확인
        if #available(iOS 17.0, *) {
            lockScreenWidgetStatus = isLiveActivityEnabled ? "허용됨" : "허용 안 됨"
        } else {
            lockScreenWidgetStatus = "iOS 17 이상 필요"
        }
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

    /// AlarmKit 권한 상태를 확인한다 (요청 없이).
    private func loadAlarmKitAuthStatus() async {
        if let service = alarmKitService {
            let authorized = await service.checkPermission()
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
