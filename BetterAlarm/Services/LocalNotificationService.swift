import Foundation
import UserNotifications

// MARK: - LocalNotificationServiceProtocol

protocol LocalNotificationServiceProtocol: Sendable {
    func requestPermission() async -> Bool
    func scheduleAlarm(for alarm: Alarm) async throws
    func scheduleSnooze(for alarm: Alarm, minutes: Int) async throws
    func cancelAlarm(for alarm: Alarm) async
    func cancelAllAlarms() async
    func scheduleBackgroundReminder(for alarm: Alarm) async
    func cancelBackgroundReminder() async
}

// MARK: - LocalNotificationService

/// UNUserNotificationCenter 기반 로컬 알림 스케줄링 서비스.
/// local 모드 알람에서 사용.
/// Swift 6: actor로 구현.
actor LocalNotificationService: LocalNotificationServiceProtocol {
    private let notificationCenter = UNUserNotificationCenter.current()
    private let backgroundReminderIdentifier = "com.nahun.BetterAlarm.backgroundReminder"

    // MARK: - Permission

    /// 알림 권한을 요청한다.
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Schedule

    /// 알람을 UNCalendarNotificationTrigger로 등록한다.
    /// - Parameter alarm: 스케줄할 알람
    func scheduleAlarm(for alarm: Alarm) async throws {
        guard alarm.isEnabled else { return }

        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            throw AlarmError.notAuthorized
        }

        // 기존 알람 알림 제거
        await cancelAlarm(for: alarm)

        guard let triggerDate = alarm.nextTriggerDate() else {
            throw AlarmError.scheduleFailed("다음 발생 시각을 계산할 수 없습니다.")
        }

        let content = UNMutableNotificationContent()
        content.title = alarm.displayTitle
        content.body = "알람이 울립니다."
        content.sound = alarm.soundName == "default"
            ? .default
            : UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(alarm.soundName).mp3"))
        content.userInfo = ["alarmID": alarm.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            // 알람 울릴 때 끄지 않으면 5초 간격 반복 알림 등록
            await scheduleRepeatingAlerts(for: alarm)
        } catch {
            throw AlarmError.scheduleFailed(error.localizedDescription)
        }
    }

    // MARK: - Cancel

    /// 특정 알람의 알림을 취소한다.
    func cancelAlarm(for alarm: Alarm) async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [alarm.id.uuidString])
        await cancelRepeatingAlerts(for: alarm)
    }

    /// 모든 알람 알림을 취소한다.
    func cancelAllAlarms() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    // MARK: - Background Reminder (기능 6)

    /// 앱이 백그라운드/종료될 때 "알람이 설정되어 있습니다" 즉시 알림 1건 등록.
    func scheduleBackgroundReminder(for alarm: Alarm) async {
        let content = UNMutableNotificationContent()
        content.title = alarm.displayTitle
        content.body = "알람이 설정되어 있습니다. 알람 시각: \(alarm.timeString)"
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

    // MARK: - Repeating Alerts

    /// 알람 시각부터 5초 간격으로 반복 알림을 미리 등록한다 (최대 count개).
    /// 사용자가 알람을 끄지 않으면 계속 울리도록 한다.
    func scheduleRepeatingAlerts(for alarm: Alarm, count: Int = 30) async {
        guard let triggerDate = alarm.nextTriggerDate() else { return }

        let content = UNMutableNotificationContent()
        content.title = alarm.displayTitle
        content.body = "알람이 울리고 있습니다. 앱을 열어 알람을 끄세요."
        content.sound = .default
        content.userInfo = ["alarmID": alarm.id.uuidString]

        for i in 1...count {
            let delay = TimeInterval(i * 5)
            let fireDate = triggerDate.addingTimeInterval(delay)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "\(alarm.id.uuidString)-repeat-\(i)",
                content: content,
                trigger: trigger
            )
            try? await notificationCenter.add(request)
        }
    }

    /// 반복 알림을 모두 취소한다.
    func cancelRepeatingAlerts(for alarm: Alarm, count: Int = 30) async {
        let identifiers = (1...count).map { "\(alarm.id.uuidString)-repeat-\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: - Snooze (기능 12)

    /// 스누즈 알림을 지정된 분 뒤에 울리도록 예약한다.
    func scheduleSnooze(for alarm: Alarm, minutes: Int = 5) async throws {
        // E12 수정: scheduleAlarm()과 동일하게 권한 확인 추가.
        // 사용 중 권한 철회 시 스누즈가 silently 실패하는 것을 방지.
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            throw AlarmError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = alarm.displayTitle
        content.body = "스누즈 알람이 울립니다."
        content.sound = alarm.soundName == "default"
            ? .default
            : UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(alarm.soundName).mp3"))
        content.userInfo = ["alarmID": alarm.id.uuidString, "isSnooze": true]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(alarm.id.uuidString)-snooze",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }
}
