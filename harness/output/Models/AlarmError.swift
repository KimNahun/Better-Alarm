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
            return "알람을 사용하려면 알림 권한이 필요합니다. 설정에서 권한을 허용해주세요."
        case .scheduleFailed(let reason):
            return "알람 등록에 실패했습니다: \(reason)"
        case .soundNotFound(let name):
            return "사운드 파일을 찾을 수 없습니다: \(name)"
        case .earphoneNotConnected:
            return "조용한 알람을 사용하려면 이어폰을 연결해주세요."
        case .alarmKitUnavailable:
            return "이 기능은 iOS 26 이상에서만 사용할 수 있습니다."
        }
    }
}
