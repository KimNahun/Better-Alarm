import Foundation
#if os(iOS)
import AlarmKit
#endif

// MARK: - AlarmKitServiceProtocol

/// AlarmKit 서비스 추상화. DI 및 테스트를 위한 프로토콜.
protocol AlarmKitServiceProtocol: Sendable {
    func requestPermission() async -> Bool
    /// 권한을 요청하지 않고 현재 상태만 확인한다.
    func checkPermission() async -> Bool
    func scheduleAlarm(for alarm: Alarm) async throws
    func cancelAlarm(for alarm: Alarm) async
    func stopAllAlarms() async
    func snoozeAlarm(id alarmIDString: String) async
}

// MARK: - AlarmKitService (iOS 26+)

/// AlarmKit 기반 알람 스케줄링 서비스.
/// iOS 26.0 이상에서만 사용 가능. 모든 코드에 @available(iOS 26.0, *) 가드 적용.
/// Swift 6: actor로 구현.
@available(iOS 26.0, *)
actor AlarmKitService: AlarmKitServiceProtocol {
    private let manager = AlarmManager.shared
    private var currentAlarmKitID: UUID?
    private var monitoringTask: Task<Void, Never>?

    // MARK: - Permission

    /// AlarmKit 권한을 요청한다.
    func requestPermission() async -> Bool {
        do {
            let status = try await manager.requestAuthorization()
            let granted = status == .authorized
            AppLogger.info("AlarmKit permission request → \(granted ? "authorized" : "denied")", category: .permission)
            return granted
        } catch {
            AppLogger.error("AlarmKit permission request failed: \(error)", category: .permission)
            return false
        }
    }

    /// 권한을 요청하지 않고 현재 상태만 확인한다.
    func checkPermission() async -> Bool {
        let authorized = manager.authorizationState == .authorized
        AppLogger.debug("AlarmKit permission check → \(authorized ? "authorized" : "not authorized")", category: .permission)
        return authorized
    }

    // MARK: - Schedule

    /// 알람을 AlarmKit으로 스케줄한다.
    /// - .once / .specificDate: Fixed schedule (특정 날짜 1회)
    /// - .weekly: Relative schedule (주간 반복)
    func scheduleAlarm(for alarm: Alarm) async throws {
        guard alarm.isEnabled else {
            AppLogger.debug("AlarmKit scheduleAlarm skipped (disabled): \(alarm.displayTitle)", category: .alarmKit)
            return
        }

        // 권한이 이미 허용된 경우 불필요한 requestPermission() 호출을 건너뛴다.
        var authorized = await checkPermission()
        if !authorized {
            authorized = await requestPermission()
        }
        guard authorized else {
            AppLogger.error("AlarmKit scheduleAlarm denied — not authorized: \(alarm.displayTitle)", category: .alarmKit)
            throw AlarmError.notAuthorized
        }

        // 기존 알람 모두 중지
        await stopAllAlarms()

        let alarmID = UUID()
        currentAlarmKitID = alarmID

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.displayTitle),
            stopButton: AlarmButton(
                text: LocalizedStringResource("alarmkit_button_stop"),
                textColor: .white,
                systemImageName: "stop.fill"
            ),
            secondaryButton: AlarmButton(
                text: LocalizedStringResource("alarmkit_button_snooze"),
                textColor: .white,
                systemImageName: "moon.zzz.fill"
            ),
            secondaryButtonBehavior: .custom
        )
        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes<BetterAlarmMetadata>(
            presentation: presentation,
            tintColor: .purple
        )

        typealias Config = AlarmManager.AlarmConfiguration<BetterAlarmMetadata>
        let schedule: AlarmKit.Alarm.Schedule

        switch alarm.schedule {
        case .once:
            guard let triggerDate = alarm.nextTriggerDate() else {
                AppLogger.error("AlarmKit: failed to compute trigger date for '\(alarm.displayTitle)'", category: .alarmKit)
                throw AlarmError.scheduleFailed(String(localized: "error_compute_trigger_failed"))
            }
            guard triggerDate.timeIntervalSinceNow > 0 else {
                AppLogger.error("AlarmKit: trigger date is in the past for '\(alarm.displayTitle)'", category: .alarmKit)
                throw AlarmError.scheduleFailed(String(localized: "error_past_time"))
            }
            AppLogger.info("AlarmKit schedule .once → \(triggerDate)", category: .alarmKit)
            schedule = .fixed(triggerDate)

        case .weekly(let weekdays):
            let time = AlarmKit.Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
            let localeWeekdays = weekdays.map { $0.localeWeekday }
            let recurrence = AlarmKit.Alarm.Schedule.Relative.Recurrence.weekly(localeWeekdays)
            let relativeSchedule = AlarmKit.Alarm.Schedule.Relative(time: time, repeats: recurrence)
            schedule = .relative(relativeSchedule)
            AppLogger.info("AlarmKit schedule .weekly [\(weekdays.map(\.shortName).joined(separator: ","))] at \(alarm.hour):\(String(format: "%02d", alarm.minute))", category: .alarmKit)

        case .specificDate(let date):
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            guard let triggerDate = Calendar.current.date(from: components) else {
                AppLogger.error("AlarmKit: date component conversion failed for '\(alarm.displayTitle)'", category: .alarmKit)
                throw AlarmError.scheduleFailed(String(localized: "error_date_conversion_failed"))
            }
            guard triggerDate.timeIntervalSinceNow > 0 else {
                AppLogger.error("AlarmKit: specificDate is in the past for '\(alarm.displayTitle)'", category: .alarmKit)
                throw AlarmError.scheduleFailed(String(localized: "error_past_date"))
            }
            AppLogger.info("AlarmKit schedule .specificDate → \(triggerDate)", category: .alarmKit)
            schedule = .fixed(triggerDate)
        }

        let config = Config(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: alarmID.uuidString),
            secondaryIntent: SnoozeAlarmIntent(alarmID: alarmID.uuidString)
        )

        _ = try await manager.schedule(id: alarmID, configuration: config)
        AppLogger.info("AlarmKit alarm scheduled: '\(alarm.displayTitle)' id=\(alarmID)", category: .alarmKit)
    }

    // MARK: - Cancel / Stop

    /// 현재 스케줄된 알람을 취소한다.
    /// E7/E13 수정: currentAlarmKitID 단일 UUID에 의존하지 않고 stopAllAlarms()로 전체 취소.
    /// AlarmStore는 AlarmKit 모드에서 항상 1개만 스케줄하므로 전체 취소가 올바른 동작.
    func cancelAlarm(for alarm: Alarm) async {
        await stopAllAlarms()
    }

    /// 모든 AlarmKit 알람을 중지한다.
    func stopAllAlarms() async {
        do {
            let existing = try manager.alarms
            AppLogger.debug("AlarmKit stopping \(existing.count) existing alarm(s)", category: .alarmKit)
            for alarm in existing {
                try? manager.stop(id: alarm.id)
            }
        } catch {}
        currentAlarmKitID = nil
    }

    // MARK: - Snooze

    /// 스누즈: 현재 알람 중지 후 5분 뒤 새 AlarmKit 알람 등록.
    func snoozeAlarm(id alarmIDString: String) async {
        AppLogger.info("AlarmKit snooze requested for id=\(alarmIDString)", category: .alarmKit)
        if let id = UUID(uuidString: alarmIDString) {
            try? manager.stop(id: id)
        }

        let newID = UUID()
        let snoozeDate = Date().addingTimeInterval(5 * 60)

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource("alarmkit_alert_snooze_title"),
            stopButton: AlarmButton(text: LocalizedStringResource("alarmkit_button_stop"), textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: AlarmButton(text: LocalizedStringResource("alarmkit_button_snooze"), textColor: .white, systemImageName: "moon.zzz.fill"),
            secondaryButtonBehavior: .custom
        )
        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes<BetterAlarmMetadata>(
            presentation: presentation,
            tintColor: .purple
        )

        typealias Config = AlarmManager.AlarmConfiguration<BetterAlarmMetadata>
        let config = Config(
            schedule: .fixed(snoozeDate),
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: newID.uuidString),
            secondaryIntent: SnoozeAlarmIntent(alarmID: newID.uuidString)
        )

        _ = try? await manager.schedule(id: newID, configuration: config)
        AppLogger.info("AlarmKit snooze scheduled: newID=\(newID) at \(snoozeDate)", category: .alarmKit)
    }

    // MARK: - Monitoring

    /// alarmUpdates AsyncSequence를 구독하여 알람 상태 변화를 감시한다.
    func startMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task {
            for await alarms in self.manager.alarmUpdates {
                if Task.isCancelled { break }
                for alarm in alarms where alarm.state == .alerting {
                    AppLogger.info("AlarmKit alarm alerting: \(alarm.id)", category: .alarmKit)
                }
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
}
