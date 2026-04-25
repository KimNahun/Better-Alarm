import Foundation

// MARK: - AlarmError

/// BetterAlarm 도메인 에러 타입
enum AlarmError: Error, LocalizedError, Sendable {
    /// 알림/AlarmKit 권한 없음
    case notAuthorized
    /// 알람 스케줄링 실패
    case scheduleFailed(String)
    /// 사운드 파일 없음
    case soundNotFound(String)
    /// 조용한 알람: 이어폰 미연결
    case earphoneNotConnected
    /// iOS 26 미만에서 AlarmKit 시도
    case alarmKitUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return String(localized: "error_not_authorized")
        case .scheduleFailed(let reason):
            return String(format: NSLocalizedString("error_schedule_failed_format", comment: ""), reason)
        case .soundNotFound(let name):
            return String(format: NSLocalizedString("error_sound_not_found_format", comment: ""), name)
        case .earphoneNotConnected:
            return String(localized: "error_earphone_not_connected")
        case .alarmKitUnavailable:
            return String(localized: "error_alarmkit_unavailable")
        }
    }
}
