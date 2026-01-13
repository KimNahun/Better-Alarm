import UIKit

class WeeklyAlarmViewController: UIViewController {

    // MARK: - Types

    enum Section {
        case main
    }

    // MARK: - Properties

    private let alarmStore = AlarmStore.shared
    private var dataSource: UITableViewDiffableDataSource<Section, Alarm.ID>!
    private var selectedWeekday: Weekday = .monday

    // MARK: - UI Components

    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "주간 알람"
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()

    private let weekdayScrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return scroll
    }()

    private let weekdayStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }()

    private var weekdayButtons: [UIButton] = []

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.delegate = self
        table.register(AlarmCell.self, forCellReuseIdentifier: AlarmCell.identifier)
        table.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 100, right: 0)
        return table
    }()

    private let emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let emptyStateIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "calendar.badge.exclamationmark")
        imageView.tintColor = .textTertiary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        label.textColor = .textTertiary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configureDataSource()
        setupWeekdayButtons()

        // Set initial weekday to today
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        if let weekday = Weekday(rawValue: todayWeekday) {
            selectedWeekday = weekday
        }

        setupNotificationObserver()
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAlarmsDidUpdate),
            name: .alarmsDidUpdate,
            object: nil
        )
    }

    @objc private func handleAlarmsDidUpdate() {
        applySnapshot()
        reconfigureVisibleCells()
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSelectedWeekdayButton()
        applySnapshot(animatingDifferences: false)
        updateUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Use solid background color to prevent white flash on tab switch
        view.backgroundColor = .backgroundTop

        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(weekdayScrollView)
        weekdayScrollView.addSubview(weekdayStackView)

        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        emptyStateView.addSubview(emptyStateIcon)
        emptyStateView.addSubview(emptyStateLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),

            weekdayScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            weekdayScrollView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            weekdayScrollView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            weekdayScrollView.heightAnchor.constraint(equalToConstant: 50),
            weekdayScrollView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),

            weekdayStackView.topAnchor.constraint(equalTo: weekdayScrollView.topAnchor),
            weekdayStackView.leadingAnchor.constraint(equalTo: weekdayScrollView.leadingAnchor),
            weekdayStackView.trailingAnchor.constraint(equalTo: weekdayScrollView.trailingAnchor),
            weekdayStackView.bottomAnchor.constraint(equalTo: weekdayScrollView.bottomAnchor),
            weekdayStackView.heightAnchor.constraint(equalTo: weekdayScrollView.heightAnchor),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 50),

            emptyStateIcon.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateIcon.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateIcon.widthAnchor.constraint(equalToConstant: 60),
            emptyStateIcon.heightAnchor.constraint(equalToConstant: 60),

            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateIcon.bottomAnchor, constant: 16),
            emptyStateLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
    }

    private func setupWeekdayButtons() {
        let weekdays: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

        for weekday in weekdays {
            let button = createWeekdayButton(for: weekday)
            weekdayButtons.append(button)
            weekdayStackView.addArrangedSubview(button)

            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        }
    }

    private func createWeekdayButton(for weekday: Weekday) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(weekday.shortName, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 22
        button.tag = weekday.rawValue
        button.addTarget(self, action: #selector(weekdayButtonTapped(_:)), for: .touchUpInside)

        updateButtonAppearance(button, isSelected: false)

        return button
    }

    private func updateButtonAppearance(_ button: UIButton, isSelected: Bool) {
        if isSelected {
            button.backgroundColor = .accentPrimary
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            button.setTitleColor(.textSecondary, for: .normal)
        }
    }

    private func updateSelectedWeekdayButton() {
        for button in weekdayButtons {
            let isSelected = button.tag == selectedWeekday.rawValue
            updateButtonAppearance(button, isSelected: isSelected)
        }
    }

    // MARK: - DiffableDataSource

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, Alarm.ID>(tableView: tableView) { [weak self] tableView, indexPath, alarmId in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: AlarmCell.identifier, for: indexPath) as? AlarmCell,
                  let alarm = self?.filteredAlarms().first(where: { $0.id == alarmId }) else {
                return UITableViewCell()
            }

            cell.configure(with: alarm)
            cell.delegate = self
            return cell
        }

        dataSource.defaultRowAnimation = .fade
    }

    private func filteredAlarms() -> [Alarm] {
        return alarmStore.alarms.filter { alarm in
            if case .weekly(let days) = alarm.schedule {
                return days.contains(selectedWeekday)
            }
            return false
        }
    }

    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Alarm.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(filteredAlarms().map { $0.id })
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    private func reconfigureVisibleCells() {
        // Reconfigure all visible cells to reflect state changes immediately
        let filtered = filteredAlarms()
        for cell in tableView.visibleCells {
            guard let alarmCell = cell as? AlarmCell,
                  let indexPath = tableView.indexPath(for: cell),
                  let alarmId = dataSource.itemIdentifier(for: indexPath),
                  let alarm = filtered.first(where: { $0.id == alarmId }) else {
                continue
            }
            alarmCell.configure(with: alarm)
        }
    }

    // MARK: - Update UI

    private func updateUI() {
        let alarms = filteredAlarms()
        let hasAlarms = !alarms.isEmpty
        emptyStateView.isHidden = hasAlarms
        tableView.isHidden = !hasAlarms
        emptyStateLabel.text = "\(selectedWeekday.shortName)요일에 울리는\n알람이 없습니다"
    }

    // MARK: - Actions

    @objc private func weekdayButtonTapped(_ sender: UIButton) {
        UIView.hapticFeedback(style: .light)

        guard let weekday = Weekday(rawValue: sender.tag) else { return }
        selectedWeekday = weekday

        updateSelectedWeekdayButton()
        applySnapshot()
        updateUI()
    }
}

// MARK: - UITableViewDelegate

extension WeeklyAlarmViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let alarmId = dataSource.itemIdentifier(for: indexPath),
              let alarm = filteredAlarms().first(where: { $0.id == alarmId }) else { return }

        UIView.hapticFeedback(style: .light)

        let editVC = AlarmDetailViewController()
        editVC.delegate = self
        editVC.configure(with: alarm)
        editVC.modalPresentationStyle = .pageSheet

        if let sheet = editVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        present(editVC, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
            guard let alarmId = self?.dataSource.itemIdentifier(for: indexPath),
                  let alarm = self?.filteredAlarms().first(where: { $0.id == alarmId }) else {
                completion(false)
                return
            }

            UIView.hapticFeedback(style: .medium)
            self?.alarmStore.deleteAlarm(alarm)
            completion(true)
        }

        deleteAction.image = UIImage(systemName: "trash.fill")
        deleteAction.backgroundColor = .destructiveAction

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - AlarmCellDelegate

extension WeeklyAlarmViewController: AlarmCellDelegate {
    func alarmCell(_ cell: AlarmCell, didToggleAlarm alarm: Alarm, isOn: Bool) {
        if isOn {
            // Turning ON
            if alarm.isSkippingNext {
                // Clear skip status
                UIView.hapticFeedback(style: .light)
                alarmStore.clearSkipOnceAlarm(alarm)
            } else if !alarm.isEnabled {
                // Enable disabled alarm
                UIView.hapticFeedback(style: .light)
                alarmStore.toggleAlarm(alarm, enabled: true)
            }
        } else {
            // Turning OFF
            if alarm.isEnabled && !alarm.isSkippingNext {
                // Show skip option for weekly alarms
                let actionSheet = UIAlertController(
                    title: alarm.displayTitle,
                    message: "알람을 어떻게 처리할까요?",
                    preferredStyle: .actionSheet
                )

                let skipOnceAction = UIAlertAction(title: "1번만 끄기", style: .default) { [weak self] _ in
                    UIView.hapticFeedback(style: .light)
                    self?.alarmStore.skipOnceAlarm(alarm)
                }
                actionSheet.addAction(skipOnceAction)

                let deleteAction = UIAlertAction(title: "완전히 끄기", style: .destructive) { [weak self] _ in
                    UIView.hapticFeedback(style: .medium)
                    self?.alarmStore.deleteAlarm(alarm)
                }
                actionSheet.addAction(deleteAction)

                let cancelAction = UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
                    self?.applySnapshot()
                    self?.reconfigureVisibleCells()
                }
                actionSheet.addAction(cancelAction)

                present(actionSheet, animated: true)
            }
        }
    }
}

// MARK: - AlarmDetailViewControllerDelegate

extension WeeklyAlarmViewController: AlarmDetailViewControllerDelegate {
    func alarmDetailViewController(_ controller: AlarmDetailViewController, didSaveAlarm hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?, existingAlarm: Alarm?) {
        if let existing = existingAlarm {
            alarmStore.updateAlarm(existing, hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate)
        } else {
            alarmStore.createAlarm(hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate)
        }
    }
}

