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
        AppLogger.info("AlarmStore initializing", category: .store)
        loadAlarms()
        setupAlarmCompletionObserver()
        isInitialized = true
        AppLogger.info("AlarmStore initialized with \(alarms.count) alarms", category: .store)
    }

    // MARK: - Alarm Completion Observer

    private func setupAlarmCompletionObserver() {
        AppLogger.debug("Setting up alarm completion observer", category: .store)
        Task { @MainActor in
            AlarmKitService.shared.observeAlarmCompleted { [weak self] completedAlarm in
                AppLogger.info("Alarm completion callback received: \(completedAlarm.displayTitle)", category: .alarm)
                self?.handleAlarmCompleted(completedAlarm)
            }
        }
    }

    private func notifyUpdate() {
        AppLogger.debug("Notifying alarm update, count: \(alarms.count)", category: .store)
        delegate?.alarmStoreDidUpdateAlarms(self)
        NotificationCenter.default.post(name: .alarmsDidUpdate, object: self)
    }

    // MARK: - Load/Save

    func loadAlarms() {
        AppLogger.debug("Loading alarms from UserDefaults", category: .store)
        guard let data = userDefaults.data(forKey: alarmsKey) else {
            AppLogger.debug("No saved alarms found", category: .store)
            alarms = []
            return
        }

        do {
            alarms = try JSONDecoder().decode([Alarm].self, from: data)
            sortAlarms()
            AppLogger.info("Loaded \(alarms.count) alarms", category: .store)
        } catch {
            AppLogger.error("Failed to load alarms: \(error)", category: .store)
            alarms = []
        }
    }

    private func saveAlarms() {
        AppLogger.debug("Saving \(alarms.count) alarms to UserDefaults", category: .store)
        do {
            let data = try JSONEncoder().encode(alarms)
            userDefaults.set(data, forKey: alarmsKey)
            AppLogger.debug("Alarms saved successfully", category: .store)
        } catch {
            AppLogger.error("Failed to save alarms: \(error)", category: .store)
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
        AppLogger.info("Creating alarm: \(title.isEmpty ? "Untitled" : title) at \(hour):\(minute)", category: .alarm)

        let schedule: AlarmSchedule
        if let weekdays = weekdays, !weekdays.isEmpty {
            schedule = .weekly(weekdays)
            AppLogger.debug("Schedule: weekly \(weekdays.map { $0.shortName })", category: .alarm)
        } else if let date = specificDate {
            schedule = .specificDate(date)
            AppLogger.debug("Schedule: specific date \(date)", category: .alarm)
        } else {
            schedule = .once
            AppLogger.debug("Schedule: once", category: .alarm)
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

        AppLogger.alarmCreated("\(alarm.displayTitle) id=\(alarm.id.uuidString.prefix(8))")
    }

    func updateAlarm(_ alarm: Alarm, hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?, soundName: String = "default") {
        AppLogger.info("Updating alarm: \(alarm.displayTitle) id=\(alarm.id.uuidString.prefix(8))", category: .alarm)

        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            AppLogger.warning("Alarm not found for update: \(alarm.id)", category: .alarm)
            return
        }

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

        AppLogger.alarmUpdated("\(updated.displayTitle) to \(hour):\(minute)")
    }

    func deleteAlarm(_ alarm: Alarm) {
        AppLogger.info("Deleting alarm: \(alarm.displayTitle) id=\(alarm.id.uuidString.prefix(8))", category: .alarm)
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
        updateLiveActivity()
        AppLogger.alarmDeleted(alarm.displayTitle)
    }

    func deleteAlarm(at index: Int) {
        guard index < alarms.count else {
            AppLogger.warning("Invalid index for delete: \(index), count: \(alarms.count)", category: .alarm)
            return
        }
        let alarm = alarms[index]
        deleteAlarm(alarm)
    }

    func toggleAlarm(_ alarm: Alarm, enabled: Bool) {
        AppLogger.info("Toggling alarm: \(alarm.displayTitle) enabled=\(enabled)", category: .alarm)

        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            AppLogger.warning("Alarm not found for toggle: \(alarm.id)", category: .alarm)
            return
        }

        var updated = alarm
        updated.isEnabled = enabled

        if enabled {
            updated.skippedDate = nil
            AppLogger.debug("Cleared skipped date", category: .alarm)
        }

        alarms[index] = updated
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
        updateLiveActivity()

        AppLogger.alarmToggled(alarm.displayTitle, enabled: enabled)
    }

    func skipOnceAlarm(_ alarm: Alarm) {
        AppLogger.info("Skip once alarm: \(alarm.displayTitle)", category: .alarm)

        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            AppLogger.warning("Alarm not found for skip: \(alarm.id)", category: .alarm)
            return
        }
        guard alarm.isEnabled else {
            AppLogger.debug("Alarm is disabled, skipping skip operation", category: .alarm)
            return
        }

        guard let nextDate = alarm.nextTriggerDate() else {
            AppLogger.warning("No next trigger date for skip", category: .alarm)
            return
        }

        var updated = alarm
        updated.skippedDate = nextDate

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
        updateLiveActivity()

        AppLogger.info("Alarm skipped until: \(nextDate)", category: .alarm)
    }

    func clearSkipOnceAlarm(_ alarm: Alarm) {
        AppLogger.info("Clear skip for alarm: \(alarm.displayTitle)", category: .alarm)

        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            AppLogger.warning("Alarm not found for clear skip: \(alarm.id)", category: .alarm)
            return
        }
        guard alarm.skippedDate != nil else {
            AppLogger.debug("Alarm has no skipped date", category: .alarm)
            return
        }

        var updated = alarm
        updated.skippedDate = nil

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        scheduleNextAlarm()
        notifyUpdate()
        updateLiveActivity()

        AppLogger.info("Skip cleared for: \(alarm.displayTitle)", category: .alarm)
    }

    // MARK: - One-time Alarm Completion

    func handleAlarmCompleted(_ alarm: Alarm) {
        AppLogger.info("Handling alarm completed: \(alarm.displayTitle)", category: .alarm)

        // ID로 알람 찾기
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            AppLogger.debug("Alarm not found by ID, trying time match", category: .alarm)
            handleAlarmCompletedByTime(hour: alarm.hour, minute: alarm.minute)
            return
        }

        let existingAlarm = alarms[index]

        // 이미 비활성화된 알람은 중복 처리 방지
        guard existingAlarm.isEnabled else {
            AppLogger.debug("Alarm already disabled, skipping completion handling: \(existingAlarm.displayTitle)", category: .alarm)
            return
        }

        switch existingAlarm.schedule {
        case .once, .specificDate:
            // 1회성 알람은 비활성화
            toggleAlarm(existingAlarm, enabled: false)
            AppLogger.info("One-time alarm completed and disabled: \(existingAlarm.displayTitle)", category: .alarm)
        case .weekly:
            // 주간 알람은 스킵 상태 초기화
            if existingAlarm.skippedDate != nil {
                clearSkipOnceAlarm(existingAlarm)
            }
            // 다음 알람 스케줄
            scheduleNextAlarm()
            AppLogger.info("Weekly alarm completed, scheduling next: \(existingAlarm.displayTitle)", category: .alarm)
        }
    }
    
    // ⭐ ID로 알람 완료 처리 (앱 재시작 시 사용)
    func handleAlarmCompletedById(_ alarmId: UUID) {
        AppLogger.info("Handling alarm completed by ID: \(alarmId)", category: .alarm)
        
        guard let alarm = alarms.first(where: { $0.id == alarmId }) else {
            AppLogger.warning("Alarm not found for ID: \(alarmId)", category: .alarm)
            return
        }
        
        handleAlarmCompleted(alarm)
    }

    // 시간으로 완료된 알람 찾기 (백업 방법)
    private func handleAlarmCompletedByTime(hour: Int, minute: Int) {
        AppLogger.debug("Finding alarm by time: \(hour):\(minute)", category: .alarm)
        guard let alarm = alarms.first(where: {
            $0.isEnabled && $0.hour == hour && $0.minute == minute
        }) else {
            AppLogger.warning("No matching alarm found for time: \(hour):\(minute)", category: .alarm)
            return
        }

        handleAlarmCompleted(alarm)
    }

    // ⭐ 앱이 foreground로 올 때 호출 - 여러 알람 처리
    func checkForCompletedAlarms() {
        AppLogger.debug("Checking for completed alarms from intent", category: .alarm)
        Task { @MainActor in
            // AlarmKitService에서 완료된 알람 ID 배열 가져오기
            let completedAlarmIds = AlarmKitService.shared.checkForPendingIntentActions()
            
            if !completedAlarmIds.isEmpty {
                AppLogger.info("Processing \(completedAlarmIds.count) completed alarms from intent", category: .alarm)
                for alarmId in completedAlarmIds {
                    self.handleAlarmCompletedById(alarmId)
                }
            }
            
            // ⭐ 완료 처리 후 다음 알람 reschedule
            self.scheduleNextAlarm()
        }
    }

    // 사용자가 수동으로 만료된 1회성 알람 정리 (선택적)
    func cleanupExpiredOneTimeAlarms() {
        AppLogger.debug("Cleaning up expired one-time alarms", category: .alarm)
        let now = Date()
        let alarmsToDelete = alarms.filter { alarm in
            switch alarm.schedule {
            case .once, .specificDate:
                return !alarm.isEnabled && alarm.nextTriggerDate(from: now) == nil
            case .weekly:
                return false
            }
        }

        if !alarmsToDelete.isEmpty {
            AppLogger.info("Found \(alarmsToDelete.count) expired alarms to delete", category: .alarm)
        }

        for alarm in alarmsToDelete {
            deleteAlarm(alarm)
        }
    }

    // MARK: - Next Alarm

    // 스킵되지 않은 다음 알람 (AlarmKit 스케줄용)
    var nextAlarm: Alarm? {
        let next = alarms
            .filter { $0.isEnabled && !$0.isSkippingNext }
            .compactMap { alarm -> (Alarm, Date)? in
                guard let date = alarm.nextTriggerDate() else { return nil }
                return (alarm, date)
            }
            .min { $0.1 < $1.1 }?
            .0
        return next
    }

    // 스킵 중인 알람 포함해서 다음 알람 (Live Activity 및 UI 표시용)
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

    // ⭐ 수정: 스킵된 알람도 포함하여 표시 (1번 문제 해결)
    var nextAlarmDisplayString: String? {
        // 스킵된 알람 포함해서 가져오기
        guard let alarm = nextAlarmIncludingSkipped, let date = alarm.nextTriggerDate() else { return nil }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let period = hour < 12 ? "오전" : "오후"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        var baseString: String
        if calendar.isDateInToday(date) {
            baseString = String(format: "오늘 %@ %d시 %02d분", period, displayHour, minute)
        } else if calendar.isDateInTomorrow(date) {
            baseString = String(format: "내일 %@ %d시 %02d분", period, displayHour, minute)
        } else {
            formatter.dateFormat = "M월 d일 (E)"
            let dateString = formatter.string(from: date)
            baseString = String(format: "%@ %@ %d시 %02d분", dateString, period, displayHour, minute)
        }
        
        return baseString
    }
    
    // ⭐ 활성화된 알람이 있는지 확인 (스킵 포함)
    var hasEnabledAlarms: Bool {
        return alarms.contains { $0.isEnabled }
    }

    // MARK: - Alarm Scheduling

    private func scheduleNextAlarm() {
        AppLogger.debug("Scheduling next alarm", category: .alarmKit)
        Task { @MainActor in
            await AlarmKitService.shared.stopAllAlarms()

            if let next = nextAlarm {
                AppLogger.info("Next alarm to schedule: \(next.displayTitle)", category: .alarmKit)
                await AlarmKitService.shared.scheduleAlarm(for: next)
            } else {
                AppLogger.debug("No next alarm to schedule", category: .alarmKit)
            }
        }
    }

    func rescheduleAllAlarms() {
        AppLogger.info("Rescheduling all alarms", category: .alarmKit)
        scheduleNextAlarm()
    }

    // MARK: - Live Activity

    func updateLiveActivity() {
        AppLogger.debug("Updating live activity", category: .liveActivity)
        Task { @MainActor in
            if let alarm = nextAlarmIncludingSkipped {
                AppLogger.debug("Updating activity with: \(alarm.displayTitle)", category: .liveActivity)
                LiveActivityManager.shared.updateActivity(with: alarm)
            } else {
                AppLogger.debug("Updating activity to empty state", category: .liveActivity)
                LiveActivityManager.shared.updateEmptyState()
            }
        }
    }

    func startLiveActivity() {
        AppLogger.info("Starting live activity", category: .liveActivity)
        Task { @MainActor in
            if let alarm = nextAlarmIncludingSkipped {
                AppLogger.debug("Starting activity with: \(alarm.displayTitle)", category: .liveActivity)
                LiveActivityManager.shared.startActivity(with: alarm)
            } else {
                AppLogger.debug("Starting empty activity", category: .liveActivity)
                LiveActivityManager.shared.startEmptyActivity()
            }
        }
    }
}
