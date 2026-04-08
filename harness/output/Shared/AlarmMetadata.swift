import Foundation

// MARK: - BetterAlarmMetadata (iOS 26+)

/// AlarmKit이 요구하는 커스텀 메타데이터 타입.
/// nonisolated struct로 구현 (AlarmMetadata 프로토콜 요구사항).
@available(iOS 26.0, *)
nonisolated struct BetterAlarmMetadata: AlarmMetadata {}
