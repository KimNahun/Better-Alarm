import Foundation

/// BetterAlarm 앱 전용 로거
/// 로그 ON/OFF는 `isEnabled`를 변경하면 됩니다.
enum AppLogger {

    // MARK: - 로그 ON/OFF 토글 (이 값만 바꾸면 전체 로그 ON/OFF)
    static var isEnabled: Bool = true

    // MARK: - 로그 카테고리
    enum Category: String {
        case lifecycle = "LIFECYCLE"
        case ui = "UI"
        case action = "ACTION"
        case alarm = "ALARM"
        case store = "STORE"
        case alarmKit = "ALARMKIT"
        case liveActivity = "ACTIVITY"
        case settings = "SETTINGS"
        case permission = "PERMISSION"
        case navigation = "NAV"
    }

    // MARK: - 로그 레벨
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    // MARK: - 메인 로그 함수

    static func log(
        _ message: String,
        category: Category,
        level: Level = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }

        let fileName = (file as NSString).lastPathComponent
        let timestamp = Self.timestamp()

        print("[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] \(fileName):\(line) \(function) - \(message)")
    }

    // MARK: - 편의 함수들

    static func debug(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .debug, file: file, function: function, line: line)
    }

    static func info(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .info, file: file, function: function, line: line)
    }

    static func warning(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .warning, file: file, function: function, line: line)
    }

    static func error(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .error, file: file, function: function, line: line)
    }

    // MARK: - UI 액션 로그

    static func buttonTapped(_ buttonName: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("Button tapped: \(buttonName)", category: .action, level: .info, file: file, function: function, line: line)
    }

    static func switchToggled(_ switchName: String, value: Bool, file: String = #file, function: String = #function, line: Int = #line) {
        log("Switch toggled: \(switchName) = \(value)", category: .action, level: .info, file: file, function: function, line: line)
    }

    static func cellSelected(_ cellInfo: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("Cell selected: \(cellInfo)", category: .action, level: .info, file: file, function: function, line: line)
    }

    // MARK: - Lifecycle 로그

    static func viewDidLoad(_ viewName: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("\(viewName) viewDidLoad", category: .lifecycle, level: .info, file: file, function: function, line: line)
    }

    static func viewWillAppear(_ viewName: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("\(viewName) viewWillAppear", category: .lifecycle, level: .debug, file: file, function: function, line: line)
    }

    static func viewDidAppear(_ viewName: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("\(viewName) viewDidAppear", category: .lifecycle, level: .debug, file: file, function: function, line: line)
    }

    static func viewWillDisappear(_ viewName: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("\(viewName) viewWillDisappear", category: .lifecycle, level: .debug, file: file, function: function, line: line)
    }

    // MARK: - 알람 관련 로그

    static func alarmCreated(_ alarm: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("Alarm created: \(alarm)", category: .alarm, level: .info, file: file, function: function, line: line)
    }

    static func alarmUpdated(_ alarm: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("Alarm updated: \(alarm)", category: .alarm, level: .info, file: file, function: function, line: line)
    }

    static func alarmDeleted(_ alarm: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("Alarm deleted: \(alarm)", category: .alarm, level: .info, file: file, function: function, line: line)
    }

    static func alarmToggled(_ alarm: String, enabled: Bool, file: String = #file, function: String = #function, line: Int = #line) {
        log("Alarm toggled: \(alarm) enabled=\(enabled)", category: .alarm, level: .info, file: file, function: function, line: line)
    }

    static func alarmScheduled(_ alarm: String, triggerDate: Date?, file: String = #file, function: String = #function, line: Int = #line) {
        let dateStr = triggerDate.map { "\($0)" } ?? "nil"
        log("Alarm scheduled: \(alarm) at \(dateStr)", category: .alarmKit, level: .info, file: file, function: function, line: line)
    }

    // MARK: - Helper

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
