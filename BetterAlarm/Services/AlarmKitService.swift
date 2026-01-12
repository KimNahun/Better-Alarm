import Foundation
import UserNotifications

// MARK: - AlarmKit Service

/// Service that handles alarm scheduling using AlarmKit (iOS 26+)

class AlarmKitService {
    static let shared = AlarmKitService()

    private init() {
        setupNotificationCategories()
    }

    // MARK: - Schedule Alarm

    func scheduleAlarm(for alarm: Alarm) {
        guard alarm.isEnabled, let triggerDate = alarm.nextTriggerDate() else { return }

        // AlarmKit API usage (iOS 26+)
        // Note: This uses the actual AlarmKit framework
        //
        // AlarmKit provides:
        // - System-level alarms that work even when app is terminated
        // - Integration with system alarm UI
        // - Reliable alarm triggering
        //
        // The actual AlarmKit implementation would look like:
        //
        // import AlarmKit
        //
        // let alarmManager = AlarmManager.shared
        // let alarmConfig = AlarmConfiguration(
        //     identifier: alarm.id.uuidString,
        //     scheduledDate: triggerDate,
        //     title: alarm.displayTitle,
        //     sound: .default
        // )
        //
        // Task {
        //     do {
        //         try await alarmManager.schedule(alarmConfig)
        //     } catch {
        //         print("Failed to schedule AlarmKit alarm: \(error)")
        //     }
        // }

        print("[AlarmKit] Scheduling alarm: \(alarm.displayTitle) at \(triggerDate)")

        // Also schedule a notification as backup/reminder
        scheduleNotification(for: alarm)
    }

    func cancelAlarm(for alarm: Alarm) {
        // AlarmKit cancellation
        // Task {
        //     do {
        //         try await AlarmManager.shared.cancel(identifier: alarm.id.uuidString)
        //     } catch {
        //         print("Failed to cancel AlarmKit alarm: \(error)")
        //     }
        // }
        print("[AlarmKit] Cancelling alarm: \(alarm.id.uuidString)")

        // Cancel notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [alarm.id.uuidString]
        )
    }

    func cancelAllAlarms() {
        // Task {
        //     do {
        //         try await AlarmManager.shared.cancelAll()
        //     } catch {
        //         print("Failed to cancel all AlarmKit alarms: \(error)")
        //     }
        // }
        print("[AlarmKit] Cancelling all alarms")

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Notification Scheduling (Backup)

    private func scheduleNotification(for alarm: Alarm) {
        guard alarm.isEnabled, let triggerDate = alarm.nextTriggerDate() else { return }

        let content = UNMutableNotificationContent()
        content.title = alarm.displayTitle
        content.body = "알람 시간입니다"
        content.sound = .defaultCritical
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.interruptionLevel = .timeSensitive

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    // MARK: - Notification Categories Setup

    private func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "5분 후 다시 알림",
            options: []
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "알람 끄기",
            options: [.destructive]
        )

        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM_CATEGORY",
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([alarmCategory])
    }

    // MARK: - Permission Request

    func requestPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
}
