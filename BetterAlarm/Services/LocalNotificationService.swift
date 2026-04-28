import Foundation
import UserNotifications

// MARK: - LocalNotificationServiceProtocol

protocol LocalNotificationServiceProtocol: Sendable {
    func requestPermission() async -> Bool
    func scheduleAlarm(for alarm: Alarm, withRepeatingAlerts: Bool) async throws
    func scheduleSnooze(for alarm: Alarm, minutes: Int) async throws
    func cancelAlarm(for alarm: Alarm) async
    func cancelAllAlarms() async
    func scheduleBackgroundReminder(for alarm: Alarm) async
    func cancelBackgroundReminder() async
}

extension LocalNotificationServiceProtocol {
    /// 기본값: withRepeatingAlerts = true (기존 동작 호환)
    func scheduleAlarm(for alarm: Alarm) async throws {
        try await scheduleAlarm(for: alarm, withRepeatingAlerts: true)
    }
}

// MARK: - LocalNotificationService

/// UNUserNotificationCenter 기반 로컬 알림 스케줄링 서비스.
/// local 모드 알람에서 사용.
/// Swift 6: actor로 구현.
actor LocalNotificationService: LocalNotificationServiceProtocol {
    private let notificationCenter = UNUserNotificationCenter.current()
    private let backgroundReminderIdentifier = "com.nahun.BetterAlarm.backgroundReminder"

    /// 알람 카테고리 ID (Notification Actions 지원)
    static let alarmCategoryIdentifier = "ALARM_CATEGORY"

    // MARK: - Repeat Configuration

    /// 알람이 울릴 때 발송되는 푸시 알림 총 횟수 (메인 1회 + 반복 4회 = 5회).
    private let alarmRepeatCount = 5
    /// 반복 알림 사이의 간격(초).
    private let alarmRepeatInterval: TimeInterval = 10

    /// 알람 알림에 사용하는 identifier 공통 prefix.
    /// - 형식: `alarm.<alarmId>.<index>` (index: 0...alarmRepeatCount-1)
    private static let alarmIdentifierPrefix = "alarm."

    /// 특정 알람의 i번째 알림에 부여할 identifier를 생성한다.
    private func notificationIdentifier(for alarm: Alarm, index: Int) -> String {
        "\(Self.alarmIdentifierPrefix)\(alarm.id.uuidString).\(index)"
    }

    /// 특정 알람의 모든 알림 identifier prefix.
    private func notificationIdentifierPrefix(for alarm: Alarm) -> String {
        "\(Self.alarmIdentifierPrefix)\(alarm.id.uuidString)."
    }

    // MARK: - Notification Sound Helper

    /// 알람의 사운드 설정에 따라 UNNotificationSound를 반환한다.
    /// "default" → 번들 내 default_alarm_long.wav (30초 알람음)
    /// 커스텀 → {soundName}.mp3
    private func notificationSound(for alarm: Alarm) -> UNNotificationSound? {
        // 🔇 테스트용 무음 모드 — AudioService.testSilentMode와 연동
        if AudioService.testSilentMode { return nil }

        if alarm.soundName == "default" {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: "default_alarm_long.wav"))
        } else {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(alarm.soundName).mp3"))
        }
    }

    // MARK: - Category Registration

    /// 알람 알림 카테고리(정지/스누즈 액션)를 등록한다. 앱 시작 시 1회 호출.
    func registerAlarmCategory() {
        let stopAction = UNNotificationAction(
            identifier: "STOP_ACTION",
            title: String(localized: "notif_action_stop"),
            options: [.destructive, .authenticationRequired]
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: String(localized: "notif_action_snooze_5min"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.alarmCategoryIdentifier,
            actions: [stopAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        notificationCenter.setNotificationCategories([category])
        AppLogger.info("Alarm notification category registered", category: .alarm)
    }

    // MARK: - Permission

    /// 알림 권한을 요청한다.
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            AppLogger.info("Notification permission request → \(granted ? "granted" : "denied")", category: .permission)
            return granted
        } catch {
            AppLogger.error("Notification permission request failed: \(error)", category: .permission)
            return false
        }
    }

    // MARK: - Schedule

    /// 알람을 UNCalendarNotificationTrigger로 등록한다.
    ///
    /// 알람 시각이 되면 정확히 `alarmRepeatCount`회(기본 5회)의 푸시 알림이 발송된다.
    /// - 1번째 알림: 알람 시각 정각 (offset 0초)
    /// - 2~5번째 알림: 알람 시각 + (i × `alarmRepeatInterval`)초 (기본 10초 간격)
    ///
    /// - Parameters:
    ///   - alarm: 스케줄할 알람
    ///   - withRepeatingAlerts: true이면 5회 발송, false이면 1회만 발송 (기본 true).
    ///     UNNotification 64개 제한이 빡빡할 때 임박하지 않은 알람에 false를 사용.
    func scheduleAlarm(for alarm: Alarm, withRepeatingAlerts: Bool = true) async throws {
        guard alarm.isEnabled else {
            AppLogger.debug("scheduleAlarm skipped (disabled): '\(alarm.displayTitle)'", category: .alarm)
            return
        }

        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            AppLogger.error("scheduleAlarm denied — notification not authorized: '\(alarm.displayTitle)'", category: .alarm)
            throw AlarmError.notAuthorized
        }

        // 기존 알람 알림(반복 5건 포함) 모두 제거
        await cancelAlarm(for: alarm)

        guard let triggerDate = alarm.nextTriggerDate() else {
            AppLogger.error("scheduleAlarm failed — cannot compute trigger date: '\(alarm.displayTitle)'", category: .alarm)
            throw AlarmError.scheduleFailed(String(localized: "error_next_trigger_unavailable"))
        }

        // 발송 횟수: true → 5회, false → 1회
        let totalCount = withRepeatingAlerts ? alarmRepeatCount : 1

        var addedCount = 0
        for index in 0..<totalCount {
            let content = UNMutableNotificationContent()
            content.title = alarm.displayTitle
            content.body = index == 0
                ? String(localized: "notif_alarm_body_default")
                : String(localized: "notif_alarm_body_repeating")
            content.sound = notificationSound(for: alarm)
            content.userInfo = ["alarmID": alarm.id.uuidString]
            content.categoryIdentifier = Self.alarmCategoryIdentifier
            content.interruptionLevel = .timeSensitive

            let fireDate = triggerDate.addingTimeInterval(alarmRepeatInterval * TimeInterval(index))

            // 첫 번째 알림은 분 단위 정확도로 충분(달력 트리거), 이후는 초 단위 정확도가 필요.
            let components: DateComponents = index == 0
                ? Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                : Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: alarm, index: index),
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
                addedCount += 1
            } catch {
                AppLogger.error("Failed to add notification request[\(index)] for '\(alarm.displayTitle)': \(error)", category: .alarm)
                if index == 0 {
                    // 첫 알림 실패는 치명적 — 부분 등록된 알림 정리 후 throw
                    await cancelAlarm(for: alarm)
                    throw AlarmError.scheduleFailed(error.localizedDescription)
                }
            }
        }

        AppLogger.info("Notification scheduled: '\(alarm.displayTitle)' id=\(alarm.id.uuidString) at \(triggerDate) (\(addedCount)/\(totalCount) alerts)", category: .alarm)
    }

    // MARK: - Cancel

    /// 특정 알람의 모든 알림(메인 + 반복)을 취소한다.
    /// `alarm.<alarmId>.<index>` prefix 매칭으로 일괄 취소하여 인덱스 누락이 없도록 한다.
    func cancelAlarm(for alarm: Alarm) async {
        let prefix = notificationIdentifierPrefix(for: alarm)

        // 1) 인덱스 기반 식별자 명시 취소 (현재 스킴: 0...alarmRepeatCount-1)
        let indexedIdentifiers = (0..<alarmRepeatCount).map { notificationIdentifier(for: alarm, index: $0) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: indexedIdentifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: indexedIdentifiers)

        // 2) prefix 매칭으로 한 번 더 정리 (이전 버전 잔존 알림 / 향후 인덱스 변경 대비)
        let pending = await notificationCenter.pendingNotificationRequests()
        let pendingMatched = pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
        if !pendingMatched.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: pendingMatched)
        }
        let delivered = await notificationCenter.deliveredNotifications()
        let deliveredMatched = delivered.map { $0.request.identifier }.filter { $0.hasPrefix(prefix) }
        if !deliveredMatched.isEmpty {
            notificationCenter.removeDeliveredNotifications(withIdentifiers: deliveredMatched)
        }

        // 3) 레거시 호환: 이전 스킴에서 메인 알림이 alarm.id.uuidString을 그대로 사용 / 반복은 "<id>-repeat-<n>" 사용
        let legacyMain = alarm.id.uuidString
        let legacyRepeat = (1...30).map { "\(alarm.id.uuidString)-repeat-\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [legacyMain] + legacyRepeat)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [legacyMain] + legacyRepeat)

        AppLogger.debug("Notification cancelled: '\(alarm.displayTitle)' id=\(alarm.id.uuidString)", category: .alarm)
    }

    /// 모든 알람 알림을 취소한다.
    func cancelAllAlarms() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    // MARK: - Background Reminder (기능 6)

    /// 앱이 백그라운드/종료될 때 "알람이 설정되어 있습니다" 즉시 알림 1건 등록.
    /// 본문에는 다음 알람의 날짜(M월 d일/M월 d일 (요일))와 시각을 함께 포함.
    func scheduleBackgroundReminder(for alarm: Alarm) async {
        let triggerDate = alarm.effectiveNextTriggerDate() ?? Date()
        let timeStr = triggerDate.formatted(date: .omitted, time: .shortened)

        let calendar = Calendar.current
        let dateTimeStr: String
        if calendar.isDateInToday(triggerDate) {
            // "오늘 오전 8:00"
            dateTimeStr = String(format: NSLocalizedString("next_alarm_format_today", comment: ""), timeStr)
        } else if calendar.isDateInTomorrow(triggerDate) {
            // "내일 오전 8:00"
            dateTimeStr = String(format: NSLocalizedString("next_alarm_format_tomorrow", comment: ""), timeStr)
        } else {
            // "5월 1일 (목) 오전 8:00"
            let dateStr = triggerDate.formatted(.dateTime.month().day().weekday(.abbreviated))
            dateTimeStr = String(format: NSLocalizedString("next_alarm_format_date", comment: ""), dateStr, timeStr)
        }

        AppLogger.info("Background reminder scheduled for '\(alarm.displayTitle)' at \(dateTimeStr)", category: .alarm)
        let content = UNMutableNotificationContent()
        content.title = alarm.displayTitle
        content.body = String(format: NSLocalizedString("notif_background_reminder_format", comment: ""), dateTimeStr)
        content.sound = .default

        // 즉시 발송 (1초 후)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: backgroundReminderIdentifier,
            content: content,
            trigger: trigger
        )

        try? await notificationCenter.add(request)
    }

    /// 포그라운드 복귀 시 백그라운드 리마인더를 취소한다.
    func cancelBackgroundReminder() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [backgroundReminderIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [backgroundReminderIdentifier])
    }

    // MARK: - Snooze (기능 12)

    /// 스누즈 알림을 지정된 분 뒤에 울리도록 예약한다.
    /// 알람 시각과 동일하게 정확히 `alarmRepeatCount`회(기본 5회) 발송된다.
    func scheduleSnooze(for alarm: Alarm, minutes: Int = 5) async throws {
        // E12 수정: scheduleAlarm()과 동일하게 권한 확인 추가.
        // 사용 중 권한 철회 시 스누즈가 silently 실패하는 것을 방지.
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            AppLogger.error("scheduleSnooze denied — notification not authorized: '\(alarm.displayTitle)'", category: .alarm)
            throw AlarmError.notAuthorized
        }

        // 스누즈 재예약 전, 기존 알람 알림(5건) 모두 취소
        await cancelAlarm(for: alarm)

        let baseDelay = TimeInterval(minutes * 60)
        var addedCount = 0
        for index in 0..<alarmRepeatCount {
            let content = UNMutableNotificationContent()
            content.title = alarm.displayTitle
            content.body = index == 0
                ? String(localized: "notif_alarm_body_snooze")
                : String(localized: "notif_alarm_body_repeating")
            content.sound = notificationSound(for: alarm)
            content.userInfo = ["alarmID": alarm.id.uuidString, "isSnooze": true]
            content.categoryIdentifier = Self.alarmCategoryIdentifier
            content.interruptionLevel = .timeSensitive

            let totalDelay = baseDelay + (alarmRepeatInterval * TimeInterval(index))
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: totalDelay,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: alarm, index: index),
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
                addedCount += 1
            } catch {
                AppLogger.error("Failed to add snooze request[\(index)] for '\(alarm.displayTitle)': \(error)", category: .alarm)
                if index == 0 {
                    await cancelAlarm(for: alarm)
                    throw error
                }
            }
        }

        AppLogger.info("Snooze notification scheduled: '\(alarm.displayTitle)' in \(minutes)min (\(addedCount)/\(alarmRepeatCount) alerts)", category: .alarm)
    }
}
