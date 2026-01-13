import Foundation

protocol AlarmStoreDelegate: AnyObject {
    func alarmStoreDidUpdateAlarms(_ store: AlarmStore)
}

class AlarmStore {
    static let shared = AlarmStore()

    weak var delegate: AlarmStoreDelegate?

    private let userDefaults = UserDefaults.standard
    private let alarmsKey = "savedAlarms"

    private(set) var alarms: [Alarm] = []

    private init() {
        loadAlarms()
    }

    // MARK: - Load/Save

    func loadAlarms() {
        guard let data = userDefaults.data(forKey: alarmsKey) else {
            alarms = []
            return
        }

        do {
            alarms = try JSONDecoder().decode([Alarm].self, from: data)
            sortAlarms()
        } catch {
            print("Failed to load alarms: \(error)")
            alarms = []
        }
    }

    private func saveAlarms() {
        do {
            let data = try JSONEncoder().encode(alarms)
            userDefaults.set(data, forKey: alarmsKey)
        } catch {
            print("Failed to save alarms: \(error)")
        }
    }

    private func sortAlarms() {
        alarms.sort { ($0.nextTriggerDate() ?? .distantFuture) < ($1.nextTriggerDate() ?? .distantFuture) }
    }

    // MARK: - CRUD

    func createAlarm(hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?) {
        let schedule: AlarmSchedule
        if let weekdays = weekdays, !weekdays.isEmpty {
            schedule = .weekly(weekdays)
        } else if let date = specificDate {
            schedule = .specificDate(date)
        } else {
            schedule = .once
        }

        let alarm = Alarm(
            title: title,
            hour: hour,
            minute: minute,
            schedule: schedule
        )

        alarms.append(alarm)
        sortAlarms()
        saveAlarms()
        scheduleAlarm(alarm)
        delegate?.alarmStoreDidUpdateAlarms(self)
        updateLiveActivity()
    }

    func updateAlarm(_ alarm: Alarm, hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }

        let schedule: AlarmSchedule
        if let weekdays = weekdays, !weekdays.isEmpty {
            schedule = .weekly(weekdays)
        } else if let date = specificDate {
            schedule = .specificDate(date)
        } else {
            schedule = .once
        }

        var updated = alarm
        updated.hour = hour
        updated.minute = minute
        updated.title = title
        updated.schedule = schedule

        cancelAlarm(alarm)
        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        scheduleAlarm(updated)
        delegate?.alarmStoreDidUpdateAlarms(self)
        updateLiveActivity()
    }

    func deleteAlarm(_ alarm: Alarm) {
        cancelAlarm(alarm)
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
        delegate?.alarmStoreDidUpdateAlarms(self)
        updateLiveActivity()
    }

    func deleteAlarm(at index: Int) {
        guard index < alarms.count else { return }
        let alarm = alarms[index]
        deleteAlarm(alarm)
    }

    func toggleAlarm(_ alarm: Alarm, enabled: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }

        var updated = alarm
        updated.isEnabled = enabled

        if enabled {
            updated.skippedDate = nil
            scheduleAlarm(updated)
        } else {
            cancelAlarm(updated)
        }

        alarms[index] = updated
        saveAlarms()
        delegate?.alarmStoreDidUpdateAlarms(self)
        updateLiveActivity()
    }

    func skipOnceAlarm(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        guard alarm.isEnabled else { return }

        guard let nextDate = alarm.nextTriggerDate() else { return }

        var updated = alarm
        updated.skippedDate = nextDate

        cancelAlarm(alarm)
        scheduleAlarm(updated)

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        delegate?.alarmStoreDidUpdateAlarms(self)
        updateLiveActivity()
    }

    func clearSkipOnceAlarm(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        guard alarm.skippedDate != nil else { return }

        var updated = alarm
        updated.skippedDate = nil

        cancelAlarm(alarm)
        scheduleAlarm(updated)

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        delegate?.alarmStoreDidUpdateAlarms(self)
        updateLiveActivity()
    }

    // MARK: - One-time Alarm Cleanup

    func handleAlarmCompleted(_ alarm: Alarm) {
        switch alarm.schedule {
        case .once, .specificDate:
            deleteAlarm(alarm)
        case .weekly:
            if alarm.skippedDate != nil {
                clearSkipOnceAlarm(alarm)
            }
        }
    }

    func cleanupExpiredOneTimeAlarms() {
        let now = Date()
        let alarmsToDelete = alarms.filter { alarm in
            switch alarm.schedule {
            case .once, .specificDate:
                return alarm.nextTriggerDate(from: now) == nil
            case .weekly:
                return false
            }
        }

        for alarm in alarmsToDelete {
            deleteAlarm(alarm)
        }
    }

    // MARK: - Next Alarm

    var nextAlarm: Alarm? {
        return alarms
            .filter { $0.isEnabled }
            .min { ($0.nextTriggerDate() ?? .distantFuture) < ($1.nextTriggerDate() ?? .distantFuture) }
    }

    var nextAlarmDisplayString: String? {
        guard let alarm = nextAlarm, let date = alarm.nextTriggerDate() else { return nil }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let period = hour < 12 ? "오전" : "오후"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        if calendar.isDateInToday(date) {
            return String(format: "오늘 %@ %d시 %02d분", period, displayHour, minute)
        } else if calendar.isDateInTomorrow(date) {
            return String(format: "내일 %@ %d시 %02d분", period, displayHour, minute)
        } else {
            formatter.dateFormat = "M월 d일 (E)"
            let dateString = formatter.string(from: date)
            return String(format: "%@ %@ %d시 %02d분", dateString, period, displayHour, minute)
        }
    }

    // MARK: - Alarm Scheduling

    private func scheduleAlarm(_ alarm: Alarm) {
        Task { @MainActor in
            await AlarmKitService.shared.scheduleAlarm(for: alarm)
        }
    }

    private func cancelAlarm(_ alarm: Alarm) {
        Task { @MainActor in
            AlarmKitService.shared.cancelAlarm(for: alarm)
        }
    }

    func rescheduleAllAlarms() {
        Task { @MainActor in
            await AlarmKitService.shared.stopAllAlarms()
            if let nextAlarm = nextAlarm, nextAlarm.isEnabled {
                await AlarmKitService.shared.scheduleAlarm(for: nextAlarm)
            }
        }
    }

    // MARK: - Live Activity

    func updateLiveActivity() {
        let alarm = nextAlarm
        Task { @MainActor in
            guard let alarm = alarm else {
                LiveActivityManager.shared.endActivity()
                return
            }
            LiveActivityManager.shared.updateActivity(with: alarm)
        }
    }

    func startLiveActivity() {
        guard let alarm = nextAlarm else { return }
        Task { @MainActor in
            LiveActivityManager.shared.startActivity(with: alarm)
        }
    }
}
