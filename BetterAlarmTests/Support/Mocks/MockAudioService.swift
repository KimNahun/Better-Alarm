// ============================================================
// MockAudioService.swift
// BetterAlarmTests · Support/Mocks
// ============================================================

import Foundation
@testable import BetterAlarm

final class MockAudioService: @unchecked Sendable {

    // MARK: - 호출 기록 (Spy)
    private(set) var playCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var lastSoundName: String?
    private(set) var lastIsSilent: Bool?

    // MARK: - 동작 제어 (Stub)
    var shouldThrowOnPlay = false
    var isEarphoneConnectedResult = false

    // MARK: - AudioService 인터페이스 미러링

    func playAlarmSound(soundName: String, isSilent: Bool, loop: Bool) async throws {
        playCallCount += 1
        lastSoundName = soundName
        lastIsSilent = isSilent
        if shouldThrowOnPlay {
            throw AlarmError.earphoneNotConnected
        }
    }

    func stopAlarmSound() async {
        stopCallCount += 1
    }

    func isEarphoneConnected() -> Bool {
        isEarphoneConnectedResult
    }

    // MARK: - 테스트 헬퍼

    func reset() {
        playCallCount = 0
        stopCallCount = 0
        lastSoundName = nil
        lastIsSilent = nil
        shouldThrowOnPlay = false
        isEarphoneConnectedResult = false
    }
}
