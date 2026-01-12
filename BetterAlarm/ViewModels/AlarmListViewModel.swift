import Foundation

protocol AlarmListViewModelDelegate: AnyObject {
    func viewModelDidUpdateAlarms()
    func viewModelDidUpdateNextAlarm(_ displayString: String?)
}

class AlarmListViewModel {
    weak var delegate: AlarmListViewModelDelegate?

    private let alarmManager = AlarmManager.shared

    var alarms: [Alarm] {
        return alarmManager.alarms
    }

    var numberOfAlarms: Int {
        return alarms.count
    }

    var nextAlarmDisplayString: String? {
        return alarmManager.nextAlarmDisplayString
    }

    var hasAlarms: Bool {
        return !alarms.isEmpty
    }

    init() {
        alarmManager.delegate = self
    }

    // MARK: - Data Access

    func alarm(at index: Int) -> Alarm? {
        guard index >= 0 && index < alarms.count else { return nil }
        return alarms[index]
    }

    // MARK: - Actions

    func createAlarm(hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?) {
        alarmManager.createAlarm(hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate)
        updateNextAlarmDisplay()
    }

    func updateAlarm(_ alarm: Alarm, hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?) {
        alarmManager.updateAlarm(alarm, hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate)
        updateNextAlarmDisplay()
    }

    func deleteAlarm(at index: Int) {
        alarmManager.deleteAlarm(at: index)
        updateNextAlarmDisplay()
    }

    func toggleAlarm(at index: Int, enabled: Bool) {
        guard let alarm = alarm(at: index) else { return }
        alarmManager.toggleAlarm(alarm, enabled: enabled)
        updateNextAlarmDisplay()
    }

    func turnOffCompletely(at index: Int) {
        guard let alarm = alarm(at: index) else { return }
        alarmManager.toggleAlarm(alarm, enabled: false)
        updateNextAlarmDisplay()
    }

    // MARK: - Next Alarm

    private func updateNextAlarmDisplay() {
        delegate?.viewModelDidUpdateNextAlarm(nextAlarmDisplayString)
    }
}

// MARK: - AlarmManagerDelegate

extension AlarmListViewModel: AlarmManagerDelegate {
    func alarmManagerDidUpdateAlarms(_ manager: AlarmManager) {
        delegate?.viewModelDidUpdateAlarms()
    }
}
