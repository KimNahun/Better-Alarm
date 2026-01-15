import Foundation

extension Notification.Name {
    static let alarmsDidUpdate = Notification.Name("alarmsDidUpdate")
}

protocol AlarmStoreDelegate: AnyObject {
    func alarmStoreDidUpdateAlarms(_ store: AlarmStore)
}

class AlarmStore {
    static let shared = AlarmStore()

    weak var delegate: AlarmStoreDelegate?

    private let userDefaults = UserDefaults.standard
    private let alarmsKey = "savedAlarms"

    private(set) var alarms: [Alarm] = []
    
    private var isInitialized = false

    private init() {
        loadAlarms()
        setupAlarmCompletionObserver()
        isInitialized = true
    }
    
    // MARK: - Alarm Completion Observer
    
    private func setupAlarmCompletionObserver() {
        Task { @MainActor in
            AlarmKitService.shared.observeAlarmCompleted { [weak self] completedAlarm in
                self?.handleAlarmCompleted(completedAlarm)
            }
        }
    }

    private func notifyUpdate() {
        delegate?.alarmStoreDidUpdateAlarms(self)
        NotificationCenter.default.post(name: .alarmsDidUpdate, object: self)
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
        alarms.sort { alarm1, alarm2 in
            if alarm1.hour != alarm2.hour {
                return alarm1.hour < alarm2.hour
            }
            return alarm1.minute < alarm2.minute
        }
    }

    // MARK: - CRUD

    func createAlarm(hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?, soundName: String = "default") {
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
            schedule: schedule,
            soundName: soundName
        )

        alarms.append(alarm)
        sortAlarms()
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
        updateLiveActivity()
    }

    func updateAlarm(_ alarm: Alarm, hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?, soundName: String = "default") {
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
        updated.soundName = soundName

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
        updateLiveActivity()
    }

    func deleteAlarm(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
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
        }

        alarms[index] = updated
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
        updateLiveActivity()
    }

    func skipOnceAlarm(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        guard alarm.isEnabled else { return }

        guard let nextDate = alarm.nextTriggerDate() else { return }

        var updated = alarm
        updated.skippedDate = nextDate

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
        updateLiveActivity()
    }

    func clearSkipOnceAlarm(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        guard alarm.skippedDate != nil else { return }

        var updated = alarm
        updated.skippedDate = nil

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
        updateLiveActivity()
    }

    // MARK: - One-time Alarm Completion

    func handleAlarmCompleted(_ alarm: Alarm) {
        // ID로 알람 찾기
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            // ID로 못 찾으면 시간으로 매칭 시도
            handleAlarmCompletedByTime(hour: alarm.hour, minute: alarm.minute)
            return
        }
        
        let existingAlarm = alarms[index]
        
        switch existingAlarm.schedule {
        case .once, .specificDate:
            // 1회성 알람은 비활성화
            toggleAlarm(existingAlarm, enabled: false)
            print("[AlarmStore] One-time alarm completed and disabled: \(existingAlarm.displayTitle)")
        case .weekly:
            // 주간 알람은 스킵 상태 초기화
            if existingAlarm.skippedDate != nil {
                clearSkipOnceAlarm(existingAlarm)
            }
            // 다음 알람 스케줄
            scheduleNextAlarm()
            print("[AlarmStore] Weekly alarm completed, scheduling next: \(existingAlarm.displayTitle)")
        }
    }
    
    // 시간으로 완료된 알람 찾기 (백업 방법)
    private func handleAlarmCompletedByTime(hour: Int, minute: Int) {
        guard let alarm = alarms.first(where: {
            $0.isEnabled && $0.hour == hour && $0.minute == minute
        }) else { return }
        
        handleAlarmCompleted(alarm)
    }
    
    // 앱이 foreground로 올 때 호출
    func checkForCompletedAlarms() {
        Task { @MainActor in
            AlarmKitService.shared.checkForPendingIntentActions()
        }
    }
    
    // 사용자가 수동으로 만료된 1회성 알람 정리 (선택적)
    func cleanupExpiredOneTimeAlarms() {
        let now = Date()
        let alarmsToDelete = alarms.filter { alarm in
            switch alarm.schedule {
            case .once, .specificDate:
                // 비활성화되어 있고, 다음 트리거 날짜가 없는 경우만
                return !alarm.isEnabled && alarm.nextTriggerDate(from: now) == nil
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
            .filter { $0.isEnabled && !$0.isSkippingNext }
            .compactMap { alarm -> (Alarm, Date)? in
                guard let date = alarm.nextTriggerDate() else { return nil }
                return (alarm, date)
            }
            .min { $0.1 < $1.1 }?
            .0
    }
    
    // 스킵 중인 알람 포함해서 다음 알람 (Live Activity용)
    var nextAlarmIncludingSkipped: Alarm? {
        return alarms
            .filter { $0.isEnabled }
            .compactMap { alarm -> (Alarm, Date)? in
                guard let date = alarm.nextTriggerDate() else { return nil }
                return (alarm, date)
            }
            .min { $0.1 < $1.1 }?
            .0
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

    private func scheduleNextAlarm() {
        Task { @MainActor in
            await AlarmKitService.shared.stopAllAlarms()
            
            if let next = nextAlarm {
                await AlarmKitService.shared.scheduleAlarm(for: next)
            }
        }
    }

    func rescheduleAllAlarms() {
        scheduleNextAlarm()
    }

    // MARK: - Live Activity

    func updateLiveActivity() {
        Task { @MainActor in
            if let alarm = nextAlarmIncludingSkipped {
                LiveActivityManager.shared.updateActivity(with: alarm)
            } else {
                LiveActivityManager.shared.updateEmptyState()
            }
        }
    }

    func startLiveActivity() {
        Task { @MainActor in
            if let alarm = nextAlarmIncludingSkipped {
                LiveActivityManager.shared.startActivity(with: alarm)
            } else {
                LiveActivityManager.shared.startEmptyActivity()
            }
        }
    }
}
