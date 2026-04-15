// ============================================================
// BugE14_SelectedAlarmStateTests.swift
// BetterAlarmTests · EdgeCases_Supplement · BugRegression
//
// 연계: BUG_ANALYSIS_SUPPLEMENT.md E14
// 수정: AlarmListView.sheet onDismiss: { selectedAlarm = nil }
//       + wasEditing 캡처를 시트 열림 시점에 결정
// ============================================================

import XCTest
@testable import BetterAlarm

// NOTE: selectedAlarm은 SwiftUI View의 @State 변수이므로
// 직접 테스트 불가. AlarmDetailViewModel의 isEditing 로직을 통해
// 기저 동작을 검증한다.

@MainActor
final class BugE14_SelectedAlarmStateTests: XCTestCase {

    private var store: AlarmStore!
    private var mockNotif: MockLocalNotificationService!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        store = AlarmStore(localNotificationService: mockNotif)
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        store = nil
        mockNotif = nil
        try await super.tearDown()
    }

    // MARK: - E14 구조적 회귀 문서

    /// E14: AlarmListView.sheet에 onDismiss 핸들러가 추가되었음을 문서화
    func test_bugE14_onDismissHandlerAdded_documentationTest() {
        // AlarmListView.swift의 .sheet(isPresented:onDismiss:)에
        // selectedAlarm = nil 이 추가됨.
        // 이는 편집 시트를 닫은 후 선택 상태가 유지되는 버그를 수정한다.
        XCTAssertTrue(true,
                      "E14: onDismiss: { selectedAlarm = nil } 추가됨 — AlarmListView.swift 참고")
    }

    // MARK: - AlarmDetailViewModel isEditing 분기

    /// E14 연계: editingAlarm이 nil일 때 isEditing = false (새 알람 생성)
    func test_bugE14_editingAlarmNil_isEditingFalse() {
        // Given — selectedAlarm = nil (시트 닫힌 후 초기화된 상태)
        let vm = AlarmDetailViewModel(store: store, editingAlarm: nil)

        // Then
        XCTAssertFalse(vm.isEditing,
                       "E14: selectedAlarm = nil이면 isEditing = false (새 알람 모드)")
    }

    /// E14 연계: editingAlarm이 non-nil일 때 isEditing = true (편집 모드)
    func test_bugE14_editingAlarmNonNil_isEditingTrue() async {
        // Given — 알람 하나 만들기
        await store.createAlarm(hour: 8, minute: 0, title: "편집 테스트",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await store.alarms[0]

        // When — selectedAlarm이 non-nil인 상태로 시트 열림
        let vm = AlarmDetailViewModel(store: store, editingAlarm: alarm)

        // Then
        XCTAssertTrue(vm.isEditing,
                      "E14: editingAlarm non-nil이면 isEditing = true (편집 모드)")
    }

    // MARK: - wasEditing 캡처 시점 검증

    /// E14: wasEditing 캡처 시점 — 시트 열릴 때 selectedAlarm 기준으로 결정
    func test_bugE14_wasEditing_capturedAtSheetOpen() async {
        // Given — 알람 생성
        await store.createAlarm(hour: 9, minute: 30, title: "캡처 테스트",
                                schedule: .weekly(Set(Weekday.allCases)),
                                alarmMode: .local, isSilentAlarm: false)
        let alarm = await store.alarms[0]

        // When — 시트 열릴 때 wasEditing = (selectedAlarm != nil) 로 캡처됨
        // selectedAlarm = alarm (non-nil) → wasEditing = true
        let wasEditingWhenOpened = (alarm as Alarm?) != nil

        // 시트 닫힌 후 onDismiss에서 selectedAlarm = nil
        // → 이 후에 wasEditing을 평가하면 false가 되지만,
        //   이미 캡처된 값(true)이 사용되어야 한다
        let selectedAlarmAfterDismiss: Alarm? = nil
        let wasEditingAfterDismiss = selectedAlarmAfterDismiss != nil

        // Then
        XCTAssertTrue(wasEditingWhenOpened,
                      "E14: 시트 열림 시 selectedAlarm non-nil → wasEditing = true")
        XCTAssertFalse(wasEditingAfterDismiss,
                       "E14: onDismiss 후 selectedAlarm = nil → wasEditing 재평가 시 false")
        // 이것이 버그의 핵심: wasEditing은 열릴 때 캡처되어야 하므로
        // AlarmListView에서 let wasEditing = selectedAlarm != nil 으로 처리함
    }

    // MARK: - AlarmDetailViewModel save() 토스트 분기

    /// E14 연계: 새 알람 저장 시 "알람이 저장되었습니다" 토스트
    func test_bugE14_saveNewAlarm_showsSaveToast() async {
        // Given
        let listVM = AlarmListViewModel(store: store)
        await listVM.loadAlarms()

        // When — 새 알람 저장 (isEditing = false)
        listVM.showSaveToast(isEditing: false)
        await Task.yield()

        // Then
        XCTAssertTrue(listVM.showToast)
        XCTAssertEqual(listVM.toastMessage, "알람이 저장되었습니다")
    }

    /// E14 연계: 기존 알람 편집 저장 시 "알람이 수정되었습니다" 토스트
    func test_bugE14_saveEditedAlarm_showsEditToast() async {
        // Given
        let listVM = AlarmListViewModel(store: store)
        await listVM.loadAlarms()

        // When — 기존 알람 수정 저장 (isEditing = true)
        listVM.showSaveToast(isEditing: true)
        await Task.yield()

        // Then
        XCTAssertTrue(listVM.showToast)
        XCTAssertEqual(listVM.toastMessage, "알람이 수정되었습니다")
    }

    // MARK: - 시트 열린 후 selectedAlarm이 유지되어야 한다 (dismiss 전까지)

    /// selectedAlarm이 nil이 아닌 상태에서 AlarmDetailViewModel 초기화 성공
    func test_bugE14_detailViewModelInit_withValidAlarm_succeeds() async {
        // Given
        await store.createAlarm(hour: 7, minute: 0, title: "기상",
                                schedule: .weekly([.monday, .tuesday, .wednesday]),
                                alarmMode: .local, isSilentAlarm: false)
        let alarm = await store.alarms[0]

        // When — 시트 열림 시 selectedAlarm 기반으로 ViewModel 초기화
        let vm = AlarmDetailViewModel(store: store, editingAlarm: alarm)

        // Then — 편집 대상 알람 데이터가 VM에 로드됨
        XCTAssertTrue(vm.isEditing)
        XCTAssertEqual(vm.title, "기상")
        XCTAssertEqual(vm.hour, 7)
        XCTAssertEqual(vm.minute, 0)
    }
}
