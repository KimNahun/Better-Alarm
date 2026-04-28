import Foundation

// MARK: - AlarmStore

/// 알람 CRUD 및 UserDefaults 저장을 담당하는 Service.
/// AlarmMode에 따라 AlarmKitService(iOS 26+) 또는 LocalNotificationService로 분기.
/// LiveActivityManager와 연동하여 알람 상태 변경 시 Live Activity를 업데이트한다.
/// Swift 6: actor로 구현.
actor AlarmStore {
    private let userDefaultsKey = "savedAlarms_v2"
    private let localNotificationService: any LocalNotificationServiceProtocol
    private let audioService: AudioService
    private let liveActivityManager: LiveActivityManager?
    private let alarmKitService: (any AlarmKitServiceProtocol)?

    private(set) var alarms: [Alarm] = []
    /// 마지막으로 scheduleNextAlarm()을 실행한 시각 (불필요한 재스케줄 방지)
    private var lastScheduledAt: Date?

    init(
        localNotificationService: any LocalNotificationServiceProtocol = LocalNotificationService(),
        audioService: AudioService = AudioService(volumeService: VolumeService()),
        liveActivityManager: LiveActivityManager? = nil,
        alarmKitService: (any AlarmKitServiceProtocol)? = nil
    ) {
        self.localNotificationService = localNotificationService
        self.audioService = audioService
        self.liveActivityManager = liveActivityManager
        self.alarmKitService = alarmKitService
    }

    // MARK: - Load / Save

    func loadAlarms() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            alarms = []
            AppLogger.info("No saved alarms found", category: .store)
            return
        }
        do {
            alarms = try JSONDecoder().decode([Alarm].self, from: data)
            sortAlarms()
            AppLogger.info("Loaded \(alarms.count) alarms", category: .store)
        } catch {
            alarms = []
            AppLogger.error("Failed to decode alarms: \(error)", category: .store)
        }
    }

    private func saveAlarms() {
        do {
            let data = try JSONEncoder().encode(alarms)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            AppLogger.debug("Saved \(alarms.count) alarms", category: .store)
        } catch {
            AppLogger.error("Failed to encode alarms: \(error)", category: .store)
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
        await scheduleNextAlarm(force: true)
        await syncLiveActivity()
        AppLogger.alarmCreated(alarm.displayTitle)
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
        await scheduleNextAlarm(force: true)
        await syncLiveActivity()
        AppLogger.alarmUpdated(updated.displayTitle)
    }

    func deleteAlarm(_ alarm: Alarm) async {
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
        await cancelSchedule(for: alarm)
        await scheduleNextAlarm(force: true)
        await syncLiveActivity()
        AppLogger.alarmDeleted(alarm.displayTitle)
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
            // 전체 재스케줄 (반복 알림을 가장 임박한 알람에만 붙이기 위해)
            await scheduleNextAlarm(force: true)
        } else {
            await cancelSchedule(for: alarm)
            // 비활성화 후 반복 알림 대상이 바뀔 수 있으므로 재스케줄
            await scheduleNextAlarm(force: true)
        }
        await syncLiveActivity()
        AppLogger.alarmToggled(alarm.displayTitle, enabled: enabled)
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
        await scheduleNextAlarm(force: true)
        await syncLiveActivity()
        AppLogger.info("Alarm skipped once: \(alarm.displayTitle)", category: .alarm)
    }

    func clearSkipOnceAlarm(_ alarm: Alarm) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        guard alarm.skippedDate != nil else { return }

        var updated = alarm
        updated.skippedDate = nil

        alarms[index] = updated
        sortAlarms()
        saveAlarms()
        await scheduleNextAlarm(force: true)
        await syncLiveActivity()
        AppLogger.info("Alarm skip cleared: \(alarm.displayTitle)", category: .alarm)
    }

    // MARK: - Snooze

    /// AlarmKit SnoozeAlarmIntent가 별도 프로세스에서 저장한 snoozeDate를 앱 메모리에 동기화한다.
    /// 앱 포그라운드 복귀 시 호출.
    func syncSnoozeFromIntent() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "alarmSnoozedFromIntent"),
              let alarmIDString = defaults.string(forKey: "alarmSnoozedAlarmID") else { return }

        let timestamp = defaults.double(forKey: "alarmSnoozeDateTimestamp")
        let snoozeDate = Date(timeIntervalSince1970: timestamp)

        // UserDefaults 키 소비 (중복 동기화 방지)
        defaults.removeObject(forKey: "alarmSnoozedFromIntent")
        defaults.removeObject(forKey: "alarmSnoozedAlarmID")
        defaults.removeObject(forKey: "alarmSnoozeDateTimestamp")

        // 알람 찾아서 snoozeDate 반영
        if let alarmID = UUID(uuidString: alarmIDString),
           let index = alarms.firstIndex(where: { $0.id == alarmID }) {
            alarms[index].snoozeDate = snoozeDate
            saveAlarms()
            AppLogger.info("Synced snoozeDate from Intent: '\(alarms[index].displayTitle)' snooze at \(snoozeDate)", category: .alarm)
        }
    }

    /// 알람을 지정된 분 뒤에 다시 울리도록 스누즈 알림을 예약한다.
    func snoozeAlarm(_ alarm: Alarm, minutes: Int = 5) async {
        // 스누즈 상태 저장
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            var updated = alarms[index]
            updated.snoozeDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
            alarms[index] = updated
            saveAlarms()
        }

        // 기존 반복 알림을 취소한 뒤 스누즈 예약
        await localNotificationService.cancelAlarm(for: alarm)

        do {
            try await localNotificationService.scheduleSnooze(for: alarm, minutes: minutes)
            AppLogger.info("Snooze scheduled: \(alarm.displayTitle) in \(minutes) min", category: .alarm)
        } catch {
            AppLogger.error("Failed to schedule snooze: \(error)", category: .alarm)
        }

        // R8-3: 스누즈는 다음 가장 가까운 알람을 변경할 수 있으므로 Live Activity 동기화
        await syncLiveActivity()
    }

    /// 스누즈를 취소한다 (snoozeDate를 nil로 초기화하고 알림을 정리한 뒤 재스케줄).
    func cancelSnooze(_ alarm: Alarm) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        guard alarms[index].snoozeDate != nil else { return }

        alarms[index].snoozeDate = nil
        saveAlarms()
        await localNotificationService.cancelAlarm(for: alarm)
        await scheduleNextAlarm(force: true)
        await syncLiveActivity()
        AppLogger.info("Snooze cancelled: \(alarm.displayTitle)", category: .alarm)
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
            // E10 수정: 주간 알람 완료 시 snoozeDate를 초기화.
            // 이전에 스누즈된 상태가 다음 주기에 잔존하면 isSnoozed가 잘못 true 반환.
            if alarms[index].snoozeDate != nil {
                alarms[index].snoozeDate = nil
                saveAlarms()
            }
            if existing.skippedDate != nil {
                await clearSkipOnceAlarm(existing)
            }
            await scheduleNextAlarm(force: true)
        }
        await syncLiveActivity()
        AppLogger.info("Alarm completed: \(alarm.displayTitle)", category: .alarm)
    }

    // MARK: - Next Alarm

    var nextAlarm: Alarm? {
        alarms
            .filter { $0.isEnabled && !$0.isSkippingNext }
            .compactMap { alarm -> (Alarm, Date)? in
                guard let date = alarm.effectiveNextTriggerDate() else { return nil }
                return (alarm, date)
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    var nextAlarmDisplayString: String? {
        guard let alarm = nextAlarm, let date = alarm.effectiveNextTriggerDate() else { return nil }

        let timeStr = date.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return String(format: NSLocalizedString("next_alarm_format_today", comment: ""), timeStr)
        } else if calendar.isDateInTomorrow(date) {
            return String(format: NSLocalizedString("next_alarm_format_tomorrow", comment: ""), timeStr)
        } else {
            let dateStr = date.formatted(.dateTime.month().day().weekday(.abbreviated))
            return String(format: NSLocalizedString("next_alarm_format_date", comment: ""), dateStr, timeStr)
        }
    }

    var hasEnabledLocalAlarms: Bool {
        alarms.contains { $0.isEnabled && $0.alarmMode == .local }
    }

    // MARK: - Live Activity Integration

    /// "현재 시점에서 가장 가까운 활성 알람"을 계산하여 Live Activity에 반영하는 단일 진입점.
    ///
    /// 이 메서드는 모든 mutation 경로(create/update/delete/toggle/skip/clearSkip/snooze/cancelSnooze/handleAlarmCompleted)
    /// 끝과, App scenePhase가 .active로 복귀할 때, 그리고 알람 발화 직후 호출되어야 한다.
    /// `nextAlarm`이 nil이면 LiveActivityManager가 내부에서 .end 처리하므로 orphan Activity가 남지 않는다.
    func syncLiveActivity() async {
        if #available(iOS 17.0, *) {
            await liveActivityManager?.updateActivity(nextAlarm: nextAlarm)
        }
    }

    // MARK: - Scheduling (AlarmMode 분기)

    /// AlarmMode에 따라 AlarmKitService 또는 LocalNotificationService로 분기하여 다음 알람을 스케줄한다.
    /// - Parameter force: true이면 쓰로틀링 무시 (CRUD 후 호출 시). 기본 false.
    func scheduleNextAlarm(force: Bool = false) async {
        // 포그라운드 복귀 등 빈번한 호출 시 60초 이내 재실행 방지
        if !force, let last = lastScheduledAt, Date().timeIntervalSince(last) < 60 {
            AppLogger.debug("scheduleNextAlarm skipped (throttled, \(Int(Date().timeIntervalSince(last)))s ago)", category: .alarm)
            return
        }
        lastScheduledAt = Date()

        // local 모드 알람 스케줄
        // UNNotification 64개 제한 → 가장 임박한 알람 1개만 반복 알림 등록, 나머지는 메인 알림만
        let enabledLocalAlarms = alarms.filter { $0.isEnabled && $0.alarmMode == .local }
        let nextLocalAlarmID = enabledLocalAlarms
            .compactMap { alarm -> (Alarm, Date)? in
                guard let d = alarm.nextTriggerDate() else { return nil }
                return (alarm, d)
            }
            .min(by: { $0.1 < $1.1 })?
            .0.id

        for alarm in enabledLocalAlarms {
            let isNext = alarm.id == nextLocalAlarmID
            do {
                try await localNotificationService.scheduleAlarm(for: alarm, withRepeatingAlerts: isNext)
            } catch {
                AppLogger.error("Failed to schedule local alarm '\(alarm.displayTitle)': \(error)", category: .alarm)
            }
        }

        // alarmKit 모드 알람 스케줄
        if let service = alarmKitService {
            let alarmKitAlarms = alarms.filter { $0.isEnabled && $0.alarmMode == .alarmKit && !$0.isSkippingNext }
            if let next = alarmKitAlarms
                .compactMap({ alarm -> (Alarm, Date)? in
                    guard let d = alarm.nextTriggerDate() else { return nil }
                    return (alarm, d)
                })
                .min(by: { $0.1 < $1.1 })?
                .0 {
                try? await service.scheduleAlarm(for: next)
            }
        }
    }

    private func cancelSchedule(for alarm: Alarm) async {
        switch alarm.alarmMode {
        case .local:
            await localNotificationService.cancelAlarm(for: alarm)
        case .alarmKit:
            if let service = alarmKitService {
                await service.cancelAlarm(for: alarm)
            }
        }
    }
}
