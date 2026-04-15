// ============================================================
// MockLocalNotificationService.swift
// BetterAlarmTests · Support/Mocks
// ============================================================

import Foundation
import UserNotifications
@testable import BetterAlarm

final class MockLocalNotificationService: LocalNotificationServiceProtocol, @unchecked Sendable {

    // MARK: - 호출 기록 (Spy)
    private(set) var scheduleAlarmCallCount = 0
    private(set) var scheduleAlarmCalledWith: [Alarm] = []
    private(set) var cancelAlarmCalledWith: [Alarm] = []
    private(set) var cancelAllCallCount = 0
    private(set) var scheduleSnoozeCalledWith: [(alarm: Alarm, minutes: Int)] = []
    private(set) var backgroundReminderScheduled = false
    private(set) var backgroundReminderCancelled = false
    private(set) var requestPermissionCallCount = 0

    // MARK: - 동작 제어 (Stub)
    var shouldThrowOnSchedule = false
    var shouldThrowOnSnooze = false
    var permissionGranted = true

    // MARK: - LocalNotificationServiceProtocol

    func requestPermission() async -> Bool {
        requestPermissionCallCount += 1
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
    }

    func cancelAllAlarms() async {
        cancelAllCallCount += 1
    }

    func scheduleSnooze(for alarm: Alarm, minutes: Int) async throws {
        scheduleSnoozeCalledWith.append((alarm, minutes))
        if shouldThrowOnSnooze {
            throw AlarmError.notAuthorized
        }
    }

    func scheduleBackgroundReminder(for alarm: Alarm) async {
        backgroundReminderScheduled = true
    }

    func cancelBackgroundReminder() async {
        backgroundReminderCancelled = true
    }

    // MARK: - 테스트 헬퍼

    func reset() {
        scheduleAlarmCallCount = 0
        scheduleAlarmCalledWith = []
        cancelAlarmCalledWith = []
        cancelAllCallCount = 0
        scheduleSnoozeCalledWith = []
        backgroundReminderScheduled = false
        backgroundReminderCancelled = false
        requestPermissionCallCount = 0
        shouldThrowOnSchedule = false
        shouldThrowOnSnooze = false
    }
}
