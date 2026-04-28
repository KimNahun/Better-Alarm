import Foundation
import UserNotifications
// E11 수정: ActivityKit은 iOS 16.1+ 전용. 최소 배포 타깃 iOS 16.0에서 unconditional import는
// 동적 링커 실패 가능. #if canImport 로 가드하여 iOS 16.0 크래시 방지.
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - SettingsViewModel

/// 설정 화면의 상태를 관리하는 ViewModel.
/// Swift 6: @MainActor + @Observable. SwiftUI import 금지.
/// PersonalColorDesignSystem import 금지 — 테마 관리는 AppThemeManager를 통해 캡슐화.
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - State

    private(set) var isLiveActivityEnabled: Bool = true

    private(set) var alarmKitAuthStatus: String = String(localized: "settings_permission_loading")
    private(set) var notificationAuthStatus: String = String(localized: "settings_permission_loading")
    private(set) var lockScreenWidgetStatus: String = String(localized: "settings_permission_loading")
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

        AppLogger.info("Loading settings", category: .settings)

        // Live Activity 상태 로드
        if #available(iOS 17.0, *), let manager = liveActivityManager {
            isLiveActivityEnabled = await manager.isLiveActivityEnabled
            AppLogger.debug("Live Activity enabled state loaded: \(isLiveActivityEnabled)", category: .settings)
        }

        // 권한 상태 확인
        await refreshPermissions()
    }

    // MARK: - Live Activity Setting

    /// Live Activity 활성화/비활성화를 설정하고 LiveActivityManager에 동기화한다.
    func setLiveActivityEnabled(_ enabled: Bool) async {
        AppLogger.info("Live Activity setting changed: \(enabled)", category: .settings)
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
            notificationAuthStatus = String(localized: "settings_permission_authorized")
        case .denied:
            notificationAuthStatus = String(localized: "settings_permission_denied")
        case .notDetermined:
            notificationAuthStatus = String(localized: "settings_permission_not_determined")
        @unknown default:
            notificationAuthStatus = String(localized: "settings_permission_unknown")
        }
        AppLogger.info("Notification permission status: \(notificationAuthStatus)", category: .permission)

        // AlarmKit 권한 상태 확인 (요청 없이)
        await loadAlarmKitAuthStatus()

        // Lock Screen Widget (ActivityKit) 실제 권한 상태 확인
        if #available(iOS 17.0, *) {
            let info = ActivityAuthorizationInfo()
            lockScreenWidgetStatus = info.areActivitiesEnabled
                ? String(localized: "settings_permission_authorized")
                : String(localized: "settings_permission_denied")
        } else {
            lockScreenWidgetStatus = String(localized: "settings_requires_ios17")
        }
        AppLogger.info("Lock Screen Widget status: \(lockScreenWidgetStatus)", category: .permission)
        AppLogger.info("AlarmKit status: \(alarmKitAuthStatus)", category: .permission)
    }

    // MARK: - Private

    /// Live Activity 설정을 LiveActivityManager에 동기화한다.
    private func syncLiveActivitySetting(_ enabled: Bool) async {
        if #available(iOS 17.0, *), let manager = liveActivityManager {
            await manager.setLiveActivityEnabled(enabled)
            if enabled {
                // R8-3: AlarmStore의 단일 진입점을 통해 가장 가까운 알람으로 동기화
                await alarmStore.syncLiveActivity()
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
            alarmKitAuthStatus = authorized
                ? String(localized: "settings_permission_authorized")
                : String(localized: "settings_permission_denied")
        } else {
            alarmKitAuthStatus = String(localized: "settings_requires_ios26")
        }
    }

    /// Bundle에서 앱 버전 및 빌드 번호를 읽는다.
    private func loadAppInfo() {
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
