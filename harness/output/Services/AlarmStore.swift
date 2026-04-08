import Foundation

// MARK: - AlarmStore

/// 알람 CRUD 및 UserDefaults 저장을 담당하는 Service.
/// AlarmMode에 따라 AlarmKitService(iOS 26+) 또는 LocalNotificationService로 분기.
/// Swift 6: actor로 구현.
actor AlarmStore {
    private let userDefaultsKey = "savedAlarms_v2"
    private let localNotificationService: LocalNotificationService
    private let audioService: AudioService

    private(set) var alarms: [Alarm] = []

    init(
        localNotificationService: LocalNotificationService = LocalNotificationService(),
        audioService: AudioService = AudioService()
    ) {
        self.localNotificationService = localNotificationService
        self.audioService = audioService
    }

    // MARK: - Load / Save

    func loadAlarms() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            alarms = []
            return
        }
        do {
            alarms = try JSONDecoder().decode([Alarm].self, from: data)
            sortAlarms()
        } catch {
            alarms = []
        }
    }

    private func saveAlarms() {
        do {
            let data = try JSONEncoder().encode(alarms)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            // 저장 실패 시 무시 (에러 타입이 없어 로그만 남김)
        }
    }

    private func sortAlarms() {
        alarms.sort {
            if $0.hour != $1.hour { return $0.hour < $1.hour }
            return $0.minute < $1.minute
        }
    }

    // MARK: - CRUD

    func createAlarm(
        hour: Int,
        minute: Int,
        title: String,
        schedule: AlarmSchedule,
        soundName: String = "default",
        alarmMode: AlarmMode = .local,
        isSilentAlarm: Bool = false
    ) async {
        let alarm = Alarm(
            title: title,
            hour: hour,
            minute: minute,
            schedule: schedule,
            soundName: soundName,
            alarmMode: alarmMode,
            isSilentAlarm: isSilentAlarm
        )
        alarms.append(alarm)
        sortAlarms()
        saveAlarms()
        await scheduleNextAlarm()
    }

    func updateAlarm(
        _ alarm: Alarm,
        hour: Int,
        minute: Int,
        title: String,
        schedule: AlarmSchedule,
        soundName: String,
        alarmMode: AlarmMode,
        isSilentAlarm: Bool
    ) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }

        var updated = alarm
        updated.hour = hour
        updated.minute = minute
        updated.title = title
        updated.schedule = schedule
        updated.soundName = soundName
        updated.alarmMode = alarmMode
        updated.isSilentAlarm = isSilentAlarm

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        await scheduleNextAlarm()
    }

    func deleteAlarm(_ alarm: Alarm) async {
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
        await cancelSchedule(for: alarm)
        await scheduleNextAlarm()
    }

    func toggleAlarm(_ alarm: Alarm, enabled: Bool) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }

        var updated = alarm
        updated.isEnabled = enabled
        if enabled {
            updated.skippedDate = nil
        }

        alarms[index] = updated
        saveAlarms()

        if enabled {
            await scheduleNextAlarm()
        } else {
            await cancelSchedule(for: alarm)
        }
    }

    func skipOnceAlarm(_ alarm: Alarm) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        guard alarm.isEnabled else { return }
        guard let nextDate = alarm.nextTriggerDate() else { return }

        var updated = alarm
        updated.skippedDate = nextDate

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        await scheduleNextAlarm()
    }

    func clearSkipOnceAlarm(_ alarm: Alarm) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        guard alarm.skippedDate != nil else { return }

        var updated = alarm
        updated.skippedDate = nil

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        await scheduleNextAlarm()
    }

    // MARK: - Alarm Completion

    func handleAlarmCompleted(_ alarm: Alarm) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        let existing = alarms[index]
        guard existing.isEnabled else { return }

        switch existing.schedule {
        case .once, .specificDate:
            await toggleAlarm(existing, enabled: false)
        case .weekly:
            if existing.skippedDate != nil {
                await clearSkipOnceAlarm(existing)
            }
            await scheduleNextAlarm()
        }
    }

    func checkForCompletedAlarms() async {
        // local 모드에서는 알림 딜리버리를 UNUserNotificationCenter로 확인
        // (실제 구현에서는 delivered notifications를 조회하여 처리)
    }

    // MARK: - Next Alarm

    var nextAlarm: Alarm? {
        alarms
            .filter { $0.isEnabled && !$0.isSkippingNext }
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

    var hasEnabledLocalAlarms: Bool {
        alarms.contains { $0.isEnabled && $0.alarmMode == .local }
    }

    // MARK: - Scheduling (AlarmMode 분기)

    /// AlarmMode에 따라 AlarmKitService 또는 LocalNotificationService로 분기하여 다음 알람을 스케줄한다.
    func scheduleNextAlarm() async {
        // local 모드 알람 스케줄
        let enabledLocalAlarms = alarms.filter { $0.isEnabled && $0.alarmMode == .local }
        for alarm in enabledLocalAlarms {
            try? await localNotificationService.scheduleAlarm(for: alarm)
        }

        // alarmKit 모드 알람 스케줄 (iOS 26+)
        if #available(iOS 26.0, *) {
            let alarmKitAlarms = alarms.filter { $0.isEnabled && $0.alarmMode == .alarmKit && !$0.isSkippingNext }
            if let next = alarmKitAlarms
                .compactMap({ alarm -> (Alarm, Date)? in
                    guard let d = alarm.nextTriggerDate() else { return nil }
                    return (alarm, d)
                })
                .min(by: { $0.1 < $1.1 })?
                .0 {
                let service = AlarmKitService()
                try? await service.scheduleAlarm(for: next)
            }
        }
    }

    private func cancelSchedule(for alarm: Alarm) async {
        switch alarm.alarmMode {
        case .local:
            await localNotificationService.cancelAlarm(for: alarm)
        case .alarmKit:
            if #available(iOS 26.0, *) {
                let service = AlarmKitService()
                service.cancelAlarm(for: alarm)
            }
        }
    }
}
