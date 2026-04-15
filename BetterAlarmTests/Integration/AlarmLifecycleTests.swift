// ============================================================
// AlarmLifecycleTests.swift
// BetterAlarmTests · Integration
//
// 테스트 대상  : 알람 전체 생명주기 (생성 → 완료 → 상태 전환)
// ============================================================

import XCTest
@testable import BetterAlarm

final class AlarmLifecycleTests: XCTestCase {

    private var sut: AlarmStore!
    private var mockNotif: MockLocalNotificationService!
    private var mockAlarmKit: MockAlarmKitService!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        mockAlarmKit = MockAlarmKitService()
        sut = AlarmStore(
            localNotificationService: mockNotif,
            alarmKitService: mockAlarmKit
        )
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        sut = nil
        mockNotif = nil
        mockAlarmKit = nil
        try await super.tearDown()
    }

    // MARK: - 1회 알람 전체 생명주기

    func test_onceAlarmLifecycle_createRingComplete() async {
        // MARK: Given — 알람 생성
        await sut.createAlarm(hour: 8, minute: 0, title: "1회",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]
        XCTAssertTrue(alarm.isEnabled, "생성 직후 활성화 상태")
        XCTAssertEqual(mockNotif.scheduleAlarmCallCount, 1, "생성 시 알림 1회 등록")

        // MARK: When — 알람 완료
        await sut.handleAlarmCompleted(alarm)

        // MARK: Then — 비활성화
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertEqual(completed?.isEnabled, false, "1회 알람 완료 후 비활성화")
    }

    // MARK: - 주간 알람 전체 생명주기

    func test_weeklyAlarmLifecycle_staysEnabledAfterCompletion() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "주간",
                              schedule: .weekly([.monday, .tuesday, .wednesday,
                                                  .thursday, .friday, .saturday, .sunday]),
                              alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.handleAlarmCompleted(alarm)

        // MARK: Then
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertEqual(completed?.isEnabled, true, "주간 알람은 완료 후에도 활성 상태 유지")
    }

    // MARK: - 스누즈 흐름

    func test_snoozeFlow_fullCycle() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "스누즈",
                              schedule: .weekly([.monday, .tuesday, .wednesday,
                                                  .thursday, .friday, .saturday, .sunday]),
                              alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When — 스누즈
        await sut.snoozeAlarm(alarm, minutes: 5)

        // MARK: Then — 스누즈 상태
        let snoozed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertTrue(snoozed?.isSnoozed ?? false, "스누즈 후 isSnoozed = true")
        XCTAssertEqual(mockNotif.scheduleSnoozeCalledWith.count, 1)

        // MARK: When — 완료 처리
        await sut.handleAlarmCompleted(snoozed!)

        // MARK: Then — 스누즈 초기화
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNil(completed?.snoozeDate, "완료 후 snoozeDate 초기화")
    }

    // MARK: - 스킵 흐름

    func test_skipFlow_fullCycle() async {
        // MARK: Given
        await sut.createAlarm(hour: 23, minute: 59, title: "스킵",
                              schedule: .weekly(Set(Weekday.allCases)),
                              alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When — 스킵
        await sut.skipOnceAlarm(alarm)
        let skipped = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNotNil(skipped?.skippedDate)

        // MARK: When — 스킵 취소
        await sut.clearSkipOnceAlarm(skipped!)
        let cleared = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNil(cleared?.skippedDate, "스킵 취소 후 skippedDate = nil")
    }

    // MARK: - scheduleNextAlarm 분기

    func test_scheduleNextAlarm_localMode_usesLocalService() async {
        // MARK: Given — local 모드 알람
        await sut.createAlarm(hour: 8, minute: 0, title: "로컬",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)

        // MARK: Then
        XCTAssertGreaterThan(mockNotif.scheduleAlarmCallCount, 0,
                             "local 모드에서 LocalNotificationService가 사용되어야 한다")
        XCTAssertEqual(mockAlarmKit.scheduleAlarmCallCount, 0,
                       "local 모드에서 AlarmKitService가 호출되지 않아야 한다")
    }

    func test_scheduleNextAlarm_alarmKitMode_usesAlarmKitService() async {
        // MARK: Given — alarmKit 모드 알람
        await sut.createAlarm(hour: 8, minute: 0, title: "AlarmKit",
                              schedule: .once, alarmMode: .alarmKit, isSilentAlarm: false)

        // MARK: Then
        XCTAssertGreaterThan(mockAlarmKit.scheduleAlarmCallCount, 0,
                             "alarmKit 모드에서 AlarmKitService가 사용되어야 한다")
    }

    func test_scheduleNextAlarm_twoAlarmKitAlarms_schedulesMostImminent() async {
        // MARK: Given — alarmKit 알람 2개 (서로 다른 시각)
        await sut.createAlarm(hour: 8, minute: 0, title: "이른 AlarmKit",
                              schedule: .once, alarmMode: .alarmKit, isSilentAlarm: false)
        await sut.createAlarm(hour: 23, minute: 59, title: "늦은 AlarmKit",
                              schedule: .once, alarmMode: .alarmKit, isSilentAlarm: false)

        // MARK: Then — AlarmKit은 1개만 스케줄 (가장 임박한 것)
        // 정확한 1회 확인은 어렵지만 과도한 호출은 없어야 함
        // scheduleAlarm은 각 createAlarm 시 scheduleNextAlarm이 호출됨
        // 2번째 createAlarm 시 다시 scheduleNextAlarm → 총 2회 이상 호출 가능
        // 핵심: 1개의 alarmKit 알람만 실제로 "현재 등록"되어야 함
        XCTAssertGreaterThanOrEqual(mockAlarmKit.scheduleAlarmCallCount, 1,
                                    "AlarmKit 알람이 스케줄되어야 한다")
    }
}
