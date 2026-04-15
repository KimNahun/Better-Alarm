// ============================================================
// BugE7_AlarmKitDeleteCancellationTests.swift
// BetterAlarmTests · EdgeCases_Supplement · BugRegression
//
// 연계: BUG_ANALYSIS_SUPPLEMENT.md E7
// 수정: AlarmKitService.cancelAlarm(for:) → stopAllAlarms() 위임
// ============================================================

import XCTest
@testable import BetterAlarm

final class BugE7_AlarmKitDeleteCancellationTests: XCTestCase {

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

    /// E7 회귀: AlarmKit 모드 알람 삭제 시 stopAllAlarms가 호출되어야 한다
    func test_bugE7_deleteAlarmKitAlarm_callsStopAll() async {
        // MARK: Given
        await store.createAlarm(hour: 8, minute: 0, title: "AlarmKit 알람",
                                schedule: .once, alarmMode: .alarmKit, isSilentAlarm: false)
        let alarm = await store.alarms[0]

        // MARK: When
        await store.deleteAlarm(alarm)

        // MARK: Then — stopAllAlarms가 호출되어야 한다 (cancelAlarm → stopAllAlarms 위임)
        XCTAssertGreaterThan(
            mockAlarmKit.stopAllAlarmsCallCount, 0,
            "E7: AlarmKit 알람 삭제 시 stopAllAlarms가 호출되어야 한다"
        )
    }

    /// E7 회귀: AlarmKit 알람이 2개일 때 첫 번째 삭제도 올바르게 취소되어야 한다
    func test_bugE7_deleteFirstAlarmKit_cancelIsNotLimitedToCurrentID() async {
        // MARK: Given — AlarmKit 알람 2개 생성
        await store.createAlarm(hour: 8, minute: 0, title: "첫 번째",
                                schedule: .once, alarmMode: .alarmKit, isSilentAlarm: false)
        await store.createAlarm(hour: 9, minute: 0, title: "두 번째",
                                schedule: .once, alarmMode: .alarmKit, isSilentAlarm: false)
        let alarms = await store.alarms
        let firstAlarm = alarms.first!

        // MARK: When — 첫 번째 삭제
        await store.deleteAlarm(firstAlarm)

        // MARK: Then — 취소 호출이 발생해야 함
        XCTAssertGreaterThan(
            mockAlarmKit.stopAllAlarmsCallCount, 0,
            "E7: 첫 번째 AlarmKit 알람 삭제 시에도 취소가 호출되어야 한다"
        )

        // 목록에서 제거됨 확인
        let remaining = await store.alarms
        XCTAssertFalse(remaining.contains { $0.id == firstAlarm.id },
                       "삭제된 알람은 목록에서 제거되어야 한다")
    }

    /// local 모드 알람 삭제는 AlarmKit 취소를 호출하지 않아야 한다
    func test_deleteLocalAlarm_doesNotCallAlarmKitCancel() async {
        // MARK: Given
        await store.createAlarm(hour: 8, minute: 0, title: "로컬",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await store.alarms[0]
        let beforeCount = mockAlarmKit.stopAllAlarmsCallCount

        // MARK: When
        await store.deleteAlarm(alarm)

        // MARK: Then
        XCTAssertEqual(
            mockAlarmKit.stopAllAlarmsCallCount, beforeCount,
            "local 모드 알람 삭제 시 AlarmKit 취소가 호출되지 않아야 한다"
        )
    }
}
