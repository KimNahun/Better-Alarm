import Foundation

protocol AlarmListViewModelDelegate: AnyObject {
    func viewModelDidUpdateAlarms()
    func viewModelDidUpdateNextAlarm(_ displayString: String?)
}

class AlarmListViewModel {
    weak var delegate: AlarmListViewModelDelegate?

    private let alarmStore = AlarmStore.shared

    var alarms: [Alarm] {
        return alarmStore.alarms
    }

    var numberOfAlarms: Int {
        return alarms.count
    }

    var nextAlarmDisplayString: String? {
        return alarmStore.nextAlarmDisplayString
    }

    var hasAlarms: Bool {
        return !alarms.isEmpty
    }

    init() {
        AppLogger.debug("AlarmListViewModel initialized", category: .lifecycle)
        alarmStore.delegate = self
    }

    // MARK: - Data Access

    func alarm(at index: Int) -> Alarm? {
        guard index >= 0 && index < alarms.count else {
            AppLogger.warning("Invalid alarm index: \(index), count: \(alarms.count)", category: .alarm)
            return nil
        }
        return alarms[index]
    }

    // MARK: - Actions

    func createAlarm(hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?) {
        AppLogger.info("ViewModel creating alarm: \(hour):\(minute)", category: .alarm)
        alarmStore.createAlarm(hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate)
        updateNextAlarmDisplay()
    }

    func updateAlarm(_ alarm: Alarm, hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?) {
        AppLogger.info("ViewModel updating alarm: \(alarm.displayTitle)", category: .alarm)
        alarmStore.updateAlarm(alarm, hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate)
        updateNextAlarmDisplay()
    }

    func deleteAlarm(at index: Int) {
        AppLogger.info("ViewModel deleting alarm at index: \(index)", category: .alarm)
        alarmStore.deleteAlarm(at: index)
        updateNextAlarmDisplay()
    }

    func toggleAlarm(at index: Int, enabled: Bool) {
        guard let alarm = alarm(at: index) else { return }
        AppLogger.info("ViewModel toggling alarm: \(alarm.displayTitle), enabled: \(enabled)", category: .alarm)
        alarmStore.toggleAlarm(alarm, enabled: enabled)
        updateNextAlarmDisplay()
    }

    func turnOffCompletely(at index: Int) {
        guard let alarm = alarm(at: index) else { return }
        AppLogger.info("ViewModel turning off alarm completely: \(alarm.displayTitle)", category: .alarm)
        alarmStore.toggleAlarm(alarm, enabled: false)
        updateNextAlarmDisplay()
    }

    // MARK: - Next Alarm

    private func updateNextAlarmDisplay() {
        delegate?.viewModelDidUpdateNextAlarm(nextAlarmDisplayString)
    }
}

// MARK: - AlarmStoreDelegate

extension AlarmListViewModel: AlarmStoreDelegate {
    func alarmStoreDidUpdateAlarms(_ store: AlarmStore) {
        AppLogger.debug("AlarmStore delegate: alarms updated, count: \(store.alarms.count)", category: .store)
        delegate?.viewModelDidUpdateAlarms()
    }
}
