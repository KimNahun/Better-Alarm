// ============================================================
// SettingsViewModelTests.swift
// BetterAlarmTests · ViewModels
//
// 테스트 대상: SettingsViewModel
//   - 초기 상태 검증
//   - appVersion / buildNumber 로드
//   - loadSettings() isLoading 전환
//   - setLiveActivityEnabled 상태 반영
//   - AlarmKit 없을 때 "iOS 26 이상 필요" 텍스트
//   - E11 회귀: #if canImport(ActivityKit) 가드
// ============================================================

import XCTest
@testable import BetterAlarm

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var store: AlarmStore!
    private var mockNotif: MockLocalNotificationService!
    private var mockAlarmKit: MockAlarmKitService!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        mockAlarmKit = MockAlarmKitService()
        store = AlarmStore(
            localNotificationService: mockNotif,
            alarmKitService: mockAlarmKit
        )
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        store = nil
        mockNotif = nil
        mockAlarmKit = nil
        try await super.tearDown()
    }

    // MARK: - 초기 상태

    func test_init_defaultState() {
        let sut = SettingsViewModel(alarmStore: store)

        XCTAssertTrue(sut.isLiveActivityEnabled, "기본값: isLiveActivityEnabled = true")
        XCTAssertFalse(sut.isLoading, "초기 isLoading = false")
        XCTAssertEqual(sut.alarmKitAuthStatus, "확인 중...", "초기 alarmKitAuthStatus = '확인 중...'")
        XCTAssertEqual(sut.notificationAuthStatus, "확인 중...", "초기 notificationAuthStatus = '확인 중...'")
    }

    // MARK: - appVersion / buildNumber

    /// Bundle에서 버전 정보가 로드되어야 한다 (빈 문자열이면 안 됨)
    func test_init_appVersionAndBuildNumberLoaded() {
        let sut = SettingsViewModel(alarmStore: store)

        // Bundle.main 값 없으면 fallback "1.0.0" / "1" 반환
        XCTAssertFalse(sut.appVersion.isEmpty, "appVersion이 비어있으면 안 된다")
        XCTAssertFalse(sut.buildNumber.isEmpty, "buildNumber가 비어있으면 안 된다")
    }

    // MARK: - AlarmKit 없을 때

    /// alarmKitService가 nil이면 "iOS 26 이상 필요"로 표시되어야 한다
    func test_loadSettings_noAlarmKitService_showsiOS26Required() async {
        let sut = SettingsViewModel(
            alarmStore: store,
            alarmKitService: nil
        )

        await sut.loadSettings()

        XCTAssertEqual(sut.alarmKitAuthStatus, "iOS 26 이상 필요",
                       "alarmKitService nil → 'iOS 26 이상 필요'")
    }

    /// alarmKitService가 있고 권한 있으면 "허용됨"이어야 한다
    func test_loadSettings_withAlarmKitAuthorized_showsAuthorized() async {
        mockAlarmKit.permissionGranted = true
        let sut = SettingsViewModel(
            alarmStore: store,
            alarmKitService: mockAlarmKit
        )

        await sut.loadSettings()

        XCTAssertEqual(sut.alarmKitAuthStatus, "허용됨",
                       "AlarmKit 권한 있을 때 '허용됨'")
    }

    /// alarmKitService가 있고 권한 없으면 "허용 안 됨"이어야 한다
    func test_loadSettings_withAlarmKitDenied_showsDenied() async {
        mockAlarmKit.permissionGranted = false
        let sut = SettingsViewModel(
            alarmStore: store,
            alarmKitService: mockAlarmKit
        )

        await sut.loadSettings()

        XCTAssertEqual(sut.alarmKitAuthStatus, "허용 안 됨",
                       "AlarmKit 권한 없을 때 '허용 안 됨'")
    }

    // MARK: - isLoading 전환

    /// loadSettings() 완료 후 isLoading = false여야 한다
    func test_loadSettings_completedLoading_isLoadingFalse() async {
        let sut = SettingsViewModel(
            alarmStore: store,
            alarmKitService: nil
        )

        await sut.loadSettings()

        XCTAssertFalse(sut.isLoading, "loadSettings 완료 후 isLoading = false")
    }

    // MARK: - setLiveActivityEnabled

    /// setLiveActivityEnabled(false) → isLiveActivityEnabled = false
    func test_setLiveActivityEnabled_false_updatesState() async {
        let sut = SettingsViewModel(
            liveActivityManager: nil,  // nil이면 LiveActivity 동기화 없이 상태만 변경
            alarmStore: store
        )

        await sut.setLiveActivityEnabled(false)

        XCTAssertFalse(sut.isLiveActivityEnabled,
                       "setLiveActivityEnabled(false) 후 isLiveActivityEnabled = false")
    }

    /// setLiveActivityEnabled(true) → isLiveActivityEnabled = true
    func test_setLiveActivityEnabled_true_updatesState() async {
        let sut = SettingsViewModel(
            liveActivityManager: nil,
            alarmStore: store
        )

        // 먼저 false로
        await sut.setLiveActivityEnabled(false)
        XCTAssertFalse(sut.isLiveActivityEnabled)

        // 다시 true로
        await sut.setLiveActivityEnabled(true)
        XCTAssertTrue(sut.isLiveActivityEnabled,
                      "setLiveActivityEnabled(true) 후 isLiveActivityEnabled = true")
    }

    // MARK: - E11 회귀: ActivityKit 가드

    /// E11 회귀: SettingsViewModel이 iOS 16에서도 초기화되어야 한다 (크래시 없음)
    func test_bugE11_settingsViewModelInit_noCrash() {
        // SettingsViewModel.swift에 #if canImport(ActivityKit) 가드 추가됨.
        // 이 테스트가 통과하면 iOS 16에서도 초기화 크래시 없음을 의미.
        let sut = SettingsViewModel(alarmStore: store)
        XCTAssertNotNil(sut, "E11: SettingsViewModel 초기화 크래시 없어야 한다")
    }

    // MARK: - themeManager

    /// themeManager 주입 시 참조가 유지되어야 한다
    func test_themeManager_injected_retained() {
        let themeManager = AppThemeManager()
        let sut = SettingsViewModel(
            alarmStore: store,
            themeManager: themeManager
        )
        XCTAssertNotNil(sut.themeManager, "themeManager가 주입되어야 한다")
    }

    /// themeManager 미주입 시 nil이어야 한다
    func test_themeManager_notInjected_isNil() {
        let sut = SettingsViewModel(alarmStore: store)
        XCTAssertNil(sut.themeManager, "themeManager 미주입 시 nil이어야 한다")
    }
}
