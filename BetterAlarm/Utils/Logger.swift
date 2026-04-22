import Foundation
import os

/// BetterAlarm 앱 전용 로거 (os.Logger 기반)
///
/// - 로그 ON/OFF: `AppLogger.isLoggingEnabled = false`
/// - DEBUG 빌드에서만 동작 (Release 빌드 = 완전 무동작)
/// - Xcode Console에서 메시지 클릭 → Jump to Source 지원
enum AppLogger {

    // MARK: - 로그 ON/OFF 토글 (이 값만 바꾸면 전체 로그 ON/OFF)
    nonisolated(unsafe) static var isLoggingEnabled: Bool = true

    // MARK: - 카테고리

    enum Category: String, CaseIterable {
        case lifecycle  = "lifecycle"
        case ui         = "ui"
        case action     = "action"
        case alarm      = "alarm"
        case store      = "store"
        case alarmKit   = "alarmKit"
        case liveActivity = "liveActivity"
        case settings   = "settings"
        case permission = "permission"
        case navigation = "navigation"
    }

    // MARK: - os.Logger 인스턴스 (카테고리별)

    private static let subsystem = "com.nahun.BetterAlarm"

    private static func logger(for category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    // MARK: - 핵심 로그 메서드

    static func debug(
        _ message: String,
        category: Category,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
#if DEBUG
        guard isLoggingEnabled else { return }
        let loc = "\(file):\(line)"
        logger(for: category).debug("[\(loc, privacy: .public)] \(function, privacy: .public) — \(message, privacy: .public)")
#endif
    }

    static func info(
        _ message: String,
        category: Category,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
#if DEBUG
        guard isLoggingEnabled else { return }
        let loc = "\(file):\(line)"
        logger(for: category).info("[\(loc, privacy: .public)] \(function, privacy: .public) — \(message, privacy: .public)")
#endif
    }

    static func warning(
        _ message: String,
        category: Category,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
#if DEBUG
        guard isLoggingEnabled else { return }
        let loc = "\(file):\(line)"
        logger(for: category).warning("[\(loc, privacy: .public)] \(function, privacy: .public) — \(message, privacy: .public)")
#endif
    }

    static func error(
        _ message: String,
        category: Category,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
#if DEBUG
        guard isLoggingEnabled else { return }
        let loc = "\(file):\(line)"
        logger(for: category).error("[\(loc, privacy: .public)] \(function, privacy: .public) — \(message, privacy: .public)")
#endif
    }

    // MARK: - 알람 편의 메서드

    static func alarmCreated(_ alarm: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        info("Alarm created: \(alarm)", category: .alarm, file: file, function: function, line: line)
    }

    static func alarmUpdated(_ alarm: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        info("Alarm updated: \(alarm)", category: .alarm, file: file, function: function, line: line)
    }

    static func alarmDeleted(_ alarm: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        info("Alarm deleted: \(alarm)", category: .alarm, file: file, function: function, line: line)
    }

    static func alarmToggled(_ alarm: String, enabled: Bool, file: String = #fileID, function: String = #function, line: Int = #line) {
        info("Alarm toggled: \(alarm) enabled=\(enabled)", category: .alarm, file: file, function: function, line: line)
    }

    static func alarmScheduled(_ alarm: String, triggerDate: Date?, file: String = #fileID, function: String = #function, line: Int = #line) {
        let dateStr = triggerDate.map { "\($0)" } ?? "nil"
        info("Alarm scheduled: \(alarm) at \(dateStr)", category: .alarmKit, file: file, function: function, line: line)
    }

    // MARK: - UI 액션 편의 메서드

    static func buttonTapped(_ buttonName: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        info("Button tapped: \(buttonName)", category: .action, file: file, function: function, line: line)
    }

    static func switchToggled(_ switchName: String, value: Bool, file: String = #fileID, function: String = #function, line: Int = #line) {
        info("Switch toggled: \(switchName) = \(value)", category: .action, file: file, function: function, line: line)
    }

    // MARK: - Lifecycle 편의 메서드

    static func viewDidLoad(_ viewName: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        info("\(viewName) viewDidLoad", category: .lifecycle, file: file, function: function, line: line)
    }
}
