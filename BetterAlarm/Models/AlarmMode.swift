import Foundation

// MARK: - AlarmMode

/// 알람 모드를 정의하는 enum.
/// - alarmKit: iOS 26+ 전용. AlarmKit을 사용하여 앱이 꺼진 상태에서도 알람이 울린다.
/// - local: iOS 17+. UNUserNotificationCenter 기반. 앱 포그라운드/백그라운드 모두 지원.
enum AlarmMode: String, Codable, Sendable, CaseIterable {
    case alarmKit
    case local

    var displayName: String {
        switch self {
        case .alarmKit: return "AlarmKit (앱 꺼진 상태에서도 울림)"
        case .local: return "로컬 알림"
        }
    }
}
