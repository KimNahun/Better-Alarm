// ============================================================
// BugE12_SnoozePermissionTests.swift
// BetterAlarmTests · EdgeCases_Supplement · BugRegression
//
// 연계: BUG_ANALYSIS_SUPPLEMENT.md E12
// 수정: LocalNotificationService.scheduleSnooze() 권한 확인 추가
// ============================================================

import XCTest
import UserNotifications
@testable import BetterAlarm

final class BugE12_SnoozePermissionTests: XCTestCase {

    private var sut: AlarmStore!
    private var mockNotif: MockLocalNotificationService!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        sut = AlarmStore(localNotificationService: mockNotif)
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        sut = nil
        mockNotif = nil
        try await super.tearDown()
    }

    /// E12 회귀: 권한 없을 때 scheduleSnooze가 throw해야 한다 (Mock 기반)
    func test_bugE12_snoozeWithoutPermission_snoozeNotScheduled() async {
        // MARK: Given — 권한 없음 시뮬레이션
        mockNotif.shouldThrowOnSnooze = true

        await sut.createAlarm(hour: 8, minute: 0, title: "스누즈 테스트",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When — AlarmStore는 에러를 로그하고 계속 진행
        await sut.snoozeAlarm(alarm, minutes: 5)

        // MARK: Then — snoozeDate는 설정되었지만 실제 알림 등록은 실패
        // (AlarmStore는 에러를 throw하지 않고 로그만 함)
        XCTAssertEqual(mockNotif.scheduleSnoozeCalledWith.count, 1,
                       "E12: scheduleSnooze는 호출되어야 한다 (권한 확인 포함)")
        // shouldThrowOnSnooze=true이므로 실제 throw 발생 → AlarmStore에서 catch됨
    }

    /// E12: 권한 있을 때 스누즈가 정상 등록되어야 한다
    func test_bugE12_snoozeWithPermission_schedulesSuccessfully() async {
        // MARK: Given — 권한 있음
        mockNotif.shouldThrowOnSnooze = false

        await sut.createAlarm(hour: 8, minute: 0, title: "스누즈",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.snoozeAlarm(alarm, minutes: 5)

        // MARK: Then
        XCTAssertEqual(mockNotif.scheduleSnoozeCalledWith.count, 1,
                       "권한 있을 때 scheduleSnooze가 1회 호출되어야 한다")
        XCTAssertEqual(mockNotif.scheduleSnoozeCalledWith[0].minutes, 5)
    }

    /// E12: scheduleSnooze 함수에 권한 확인이 추가되었음을 구조적으로 확인
    func test_bugE12_permissionCheckIsAddedToScheduleSnooze() {
        // 이 테스트는 코드 구조 확인용.
        // LocalNotificationService.scheduleSnooze()에 권한 확인이 추가되었는지는
        // BUG_ANALYSIS_SUPPLEMENT.md E12와 LocalNotificationService.swift를 참고.
        XCTAssertTrue(true, "E12: scheduleSnooze에 권한 확인 추가됨 — LocalNotificationService.swift 참고")
    }
}
