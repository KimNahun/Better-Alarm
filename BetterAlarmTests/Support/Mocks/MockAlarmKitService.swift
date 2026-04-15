// ============================================================
// MockAlarmKitService.swift
// BetterAlarmTests · Support/Mocks
// ============================================================

import Foundation
@testable import BetterAlarm

final class MockAlarmKitService: AlarmKitServiceProtocol, @unchecked Sendable {

    // MARK: - 호출 기록 (Spy)
    private(set) var scheduleAlarmCallCount = 0
    private(set) var scheduleAlarmCalledWith: [Alarm] = []
    private(set) var cancelAlarmCalledWith: [Alarm] = []
    private(set) var stopAllAlarmsCallCount = 0
    private(set) var snoozeCallCount = 0
    private(set) var snoozeCalledWithID: [String] = []
    private(set) var requestPermissionCallCount = 0
    private(set) var checkPermissionCallCount = 0

    // MARK: - 동작 제어 (Stub)
    var isAvailable = true
    var shouldThrowOnSchedule = false
    var permissionGranted = true

    // MARK: - AlarmKitServiceProtocol

    func requestPermission() async -> Bool {
        requestPermissionCallCount += 1
        return permissionGranted
    }

    func checkPermission() async -> Bool {
        checkPermissionCallCount += 1
        return permissionGranted
    }

    func scheduleAlarm(for alarm: Alarm) async throws {
        scheduleAlarmCallCount += 1
        scheduleAlarmCalledWith.append(alarm)
        if shouldThrowOnSchedule {
            throw AlarmError.notAuthorized
        }
    }

    func cancelAlarm(for alarm: Alarm) async {
        cancelAlarmCalledWith.append(alarm)
        // E7 fix 반영: 실제 AlarmKitService.cancelAlarm은 stopAllAlarms에 위임
        await stopAllAlarms()
    }

    func stopAllAlarms() async {
        stopAllAlarmsCallCount += 1
    }

    func snoozeAlarm(id alarmIDString: String) async {
        snoozeCallCount += 1
        snoozeCalledWithID.append(alarmIDString)
    }

    // MARK: - 테스트 헬퍼

    func reset() {
        scheduleAlarmCallCount = 0
        scheduleAlarmCalledWith = []
        cancelAlarmCalledWith = []
        stopAllAlarmsCallCount = 0
        snoozeCallCount = 0
        snoozeCalledWithID = []
        requestPermissionCallCount = 0
        checkPermissionCallCount = 0
        shouldThrowOnSchedule = false
    }
}
