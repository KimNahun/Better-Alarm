import Foundation
#if os(iOS)
import AlarmKit
#endif

// MARK: - AlarmKitServiceProtocol

/// AlarmKit 서비스 추상화. DI 및 테스트를 위한 프로토콜.
protocol AlarmKitServiceProtocol: Sendable {
    func requestPermission() async -> Bool
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
            return status == .authorized
        } catch {
            return false
        }
    }

    // MARK: - Schedule

    /// 알람을 AlarmKit으로 스케줄한다.
    /// - .once / .specificDate: Fixed schedule (특정 날짜 1회)
    /// - .weekly: Relative schedule (주간 반복)
    func scheduleAlarm(for alarm: Alarm) async throws {
        guard alarm.isEnabled else { return }

        guard await requestPermission() else {
            throw AlarmError.notAuthorized
        }

        // 기존 알람 모두 중지
        await stopAllAlarms()

        let alarmID = UUID()
        currentAlarmKitID = alarmID

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.displayTitle),
            stopButton: AlarmButton(
                text: "정지",
                textColor: .white,
                systemImageName: "stop.fill"
            ),
            secondaryButton: AlarmButton(
                text: "스누즈",
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
                throw AlarmError.scheduleFailed("다음 발생 시각 계산 실패")
            }
            guard triggerDate.timeIntervalSinceNow > 0 else {
                throw AlarmError.scheduleFailed("과거 시각으로는 알람을 설정할 수 없습니다.")
            }
            schedule = .fixed(triggerDate)

        case .weekly(let weekdays):
            let time = AlarmKit.Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
            let localeWeekdays = weekdays.map { $0.localeWeekday }
            let recurrence = AlarmKit.Alarm.Schedule.Relative.Recurrence.weekly(localeWeekdays)
            let relativeSchedule = AlarmKit.Alarm.Schedule.Relative(time: time, repeats: recurrence)
            schedule = .relative(relativeSchedule)

        case .specificDate(let date):
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            guard let triggerDate = Calendar.current.date(from: components) else {
                throw AlarmError.scheduleFailed("날짜 변환 실패")
            }
            guard triggerDate.timeIntervalSinceNow > 0 else {
                throw AlarmError.scheduleFailed("과거 날짜로는 알람을 설정할 수 없습니다.")
            }
            schedule = .fixed(triggerDate)
        }

        let config = Config(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: alarmID.uuidString),
            secondaryIntent: SnoozeAlarmIntent(alarmID: alarmID.uuidString)
        )

        _ = try await manager.schedule(id: alarmID, configuration: config)
    }

    // MARK: - Cancel / Stop

    /// 현재 스케줄된 알람을 취소한다.
    func cancelAlarm(for alarm: Alarm) async {
        guard let id = currentAlarmKitID else { return }
        try? manager.stop(id: id)
        currentAlarmKitID = nil
    }

    /// 모든 AlarmKit 알람을 중지한다.
    func stopAllAlarms() async {
        do {
            let existing = try manager.alarms
            for alarm in existing {
                try? manager.stop(id: alarm.id)
            }
        } catch {}
        currentAlarmKitID = nil
    }

    // MARK: - Snooze

    /// 스누즈: 현재 알람 중지 후 5분 뒤 새 AlarmKit 알람 등록.
    func snoozeAlarm(id alarmIDString: String) async {
        if let id = UUID(uuidString: alarmIDString) {
            try? manager.stop(id: id)
        }

        let newID = UUID()
        let snoozeDate = Date().addingTimeInterval(5 * 60)

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: "스누즈 알람"),
            stopButton: AlarmButton(text: "정지", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: AlarmButton(text: "스누즈", textColor: .white, systemImageName: "moon.zzz.fill"),
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
