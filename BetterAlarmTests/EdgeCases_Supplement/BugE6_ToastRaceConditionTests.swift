// ============================================================
// BugE6_ToastRaceConditionTests.swift
// BetterAlarmTests · EdgeCases_Supplement · BugRegression
//
// 연계: BUG_ANALYSIS_SUPPLEMENT.md E6
// 수정: showToastMessage에서 showToast = false → Task { showToast = true } 분리
// ============================================================

import XCTest
@testable import BetterAlarm

@MainActor
final class BugE6_ToastRaceConditionTests: XCTestCase {

    private var store: AlarmStore!
    private var mockNotif: MockLocalNotificationService!
    private var sut: AlarmListViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        store = AlarmStore(localNotificationService: mockNotif)
        sut = AlarmListViewModel(store: store)
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        sut = nil
        store = nil
        mockNotif = nil
        try await super.tearDown()
    }

    // MARK: - E6 핵심 회귀: 동일 메시지 연속 호출

    /// E6 회귀: 같은 메시지로 showToastMessage를 연속 2회 호출해도 두 번째에 토스트가 갱신된다
    func test_bugE6_sameMessageTwice_toastRefreshes() async {
        // MARK: Given
        let message = "알람이 삭제되었습니다"

        // MARK: When — 첫 번째 호출
        sut.showToastMessage(message)
        XCTAssertFalse(sut.showToast, "showToast는 즉시 false여야 한다 (Task 실행 전)")
        XCTAssertEqual(sut.toastMessage, message)

        // Task가 실행되길 기다림
        await Task.yield()

        XCTAssertTrue(sut.showToast, "yield 후 showToast가 true여야 한다")

        // MARK: When — 두 번째 호출 (같은 메시지)
        sut.showToastMessage(message)
        XCTAssertFalse(sut.showToast, "두 번째 호출 직후 showToast가 다시 false여야 한다 (리셋)")
        XCTAssertEqual(sut.toastMessage, message)

        await Task.yield()

        // MARK: Then
        XCTAssertTrue(sut.showToast,
                      "E6: 두 번째 동일 메시지 호출 후에도 showToast가 true여야 한다")
    }

    /// E6 회귀: 서로 다른 메시지로 빠르게 연속 호출해도 마지막 메시지가 표시된다
    func test_bugE6_differentMessagesTwice_lastMessageDisplayed() async {
        // MARK: Given
        let firstMessage = "알람이 저장되었습니다"
        let secondMessage = "알람이 수정되었습니다"

        // MARK: When — 연속 두 호출
        sut.showToastMessage(firstMessage)
        sut.showToastMessage(secondMessage)

        // MARK: Then — 메시지가 두 번째 것으로 업데이트됨
        XCTAssertEqual(sut.toastMessage, secondMessage,
                       "E6: 마지막 메시지가 toastMessage에 반영되어야 한다")

        await Task.yield()

        XCTAssertTrue(sut.showToast,
                      "E6: 연속 호출 후에도 showToast가 true여야 한다")
        XCTAssertEqual(sut.toastMessage, secondMessage,
                       "E6: 마지막 메시지 유지")
    }

    /// E6 회귀: showToastMessage 호출 직후 showToast는 반드시 false여야 한다 (false→true 전환 보장)
    func test_bugE6_showToastMessage_immediateFalseBeforeYield() {
        // MARK: Given — 이미 showToast = true 상태 시뮬레이션
        sut.showToastMessage("첫 번째")
        // showToast는 Task 실행 전이므로 false

        // MARK: When — 두 번째 호출
        sut.showToastMessage("두 번째")

        // MARK: Then — 새 Task 시작 전 showToast는 false
        XCTAssertFalse(sut.showToast,
                       "E6: 두 번째 showToastMessage 직후 showToast는 false여야 한다 (onChange 발동 보장)")
        XCTAssertEqual(sut.toastMessage, "두 번째")
    }

    // MARK: - AlarmListViewModel 행동 통해 토스트 레이스 검증

    /// E6 연계: deleteAlarm → showToastMessage 경로 통합 회귀
    func test_bugE6_deleteAlarm_thenDeleteAgain_toastShowsEachTime() async {
        // MARK: Given — 알람 2개 생성
        await store.createAlarm(hour: 8, minute: 0, title: "첫 번째",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await store.createAlarm(hour: 9, minute: 0, title: "두 번째",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()

        let first = sut.alarms[0]
        let second = sut.alarms[1]

        // MARK: When — 첫 번째 삭제
        await sut.deleteAlarm(first)
        await Task.yield()
        XCTAssertTrue(sut.showToast, "첫 번째 삭제 후 toast 표시")
        XCTAssertEqual(sut.toastMessage, "알람이 삭제되었습니다")

        // MARK: When — 두 번째 삭제 (같은 메시지 재호출)
        await sut.deleteAlarm(second)
        // 즉시: false로 리셋됨
        XCTAssertFalse(sut.showToast, "E6: 두 번째 삭제 직후 toast reset")

        await Task.yield()

        // MARK: Then — 토스트 재표시
        XCTAssertTrue(sut.showToast,
                      "E6: 두 번째 삭제 후에도 toast가 다시 표시되어야 한다")
    }

    // MARK: - dismissToast

    /// dismissToast 호출 후 showToast = false, toastMessage 초기화
    func test_bugE6_dismissToast_clearsState() async {
        // MARK: Given
        sut.showToastMessage("테스트")
        await Task.yield()
        XCTAssertTrue(sut.showToast)

        // MARK: When
        sut.dismissToast()

        // MARK: Then
        XCTAssertFalse(sut.showToast, "dismissToast 후 showToast = false")
        XCTAssertEqual(sut.toastMessage, "", "dismissToast 후 toastMessage 초기화")
    }
}
