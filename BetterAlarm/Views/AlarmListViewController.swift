import UIKit

class AlarmListViewController: UIViewController {
    // MARK: - Properties

    private let alarmManager = AlarmManager.shared
    private var gradientLayer: CAGradientLayer?

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.delegate = self
        table.dataSource = self
        table.register(AlarmCell.self, forCellReuseIdentifier: AlarmCell.identifier)
        table.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 100, right: 0)
        return table
    }()

    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "알람"
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()

    private let nextAlarmCard: GlassCardView = {
        let view = GlassCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cornerRadius = 20
        return view
    }()

    private let nextAlarmTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "다음 알람"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .accentPrimary
        return label
    }()

    private let nextAlarmTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .alarmTimeFont(size: 26)
        label.textColor = .textPrimary
        label.text = "설정된 알람 없음"
        return label
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
        imageView.image = UIImage(systemName: "alarm")
        imageView.tintColor = .textTertiary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "알람이 없습니다\n+ 버튼을 눌러 알람을 추가하세요"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .textTertiary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .accentPrimary
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.accentPrimary.cgColor
        button.layer.shadowOpacity = 0.4
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 12
        button.addTarget(self, action: #selector(addAlarmTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        alarmManager.delegate = self
        requestNotificationPermission()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        alarmManager.loadAlarms()
        tableView.reloadData()
        updateUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = view.bounds
    }

    // MARK: - Setup

    private func setupUI() {
        gradientLayer = view.addGradientBackground()

        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(nextAlarmCard)
        nextAlarmCard.addSubview(nextAlarmTitleLabel)
        nextAlarmCard.addSubview(nextAlarmTimeLabel)

        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        emptyStateView.addSubview(emptyStateIcon)
        emptyStateView.addSubview(emptyStateLabel)

        view.addSubview(addButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),

            nextAlarmCard.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            nextAlarmCard.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            nextAlarmCard.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            nextAlarmCard.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),

            nextAlarmTitleLabel.topAnchor.constraint(equalTo: nextAlarmCard.topAnchor, constant: 14),
            nextAlarmTitleLabel.leadingAnchor.constraint(equalTo: nextAlarmCard.leadingAnchor, constant: 18),

            nextAlarmTimeLabel.topAnchor.constraint(equalTo: nextAlarmTitleLabel.bottomAnchor, constant: 6),
            nextAlarmTimeLabel.leadingAnchor.constraint(equalTo: nextAlarmCard.leadingAnchor, constant: 18),
            nextAlarmTimeLabel.trailingAnchor.constraint(equalTo: nextAlarmCard.trailingAnchor, constant: -18),
            nextAlarmTimeLabel.bottomAnchor.constraint(equalTo: nextAlarmCard.bottomAnchor, constant: -14),

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
            emptyStateLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor),

            addButton.widthAnchor.constraint(equalToConstant: 56),
            addButton.heightAnchor.constraint(equalToConstant: 56),
            addButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { _, _ in }
    }

    // MARK: - Update UI

    private func updateUI() {
        let hasAlarms = !alarmManager.alarms.isEmpty
        emptyStateView.isHidden = hasAlarms
        tableView.isHidden = !hasAlarms
        updateNextAlarmDisplay()
    }

    private func updateNextAlarmDisplay() {
        if let displayString = alarmManager.nextAlarmDisplayString {
            nextAlarmTimeLabel.text = displayString
        } else {
            nextAlarmTimeLabel.text = "설정된 알람 없음"
        }
    }

    // MARK: - Actions

    @objc private func addAlarmTapped() {
        UIView.hapticFeedback(style: .medium)

        let addVC = AlarmDetailViewController()
        addVC.delegate = self
        addVC.modalPresentationStyle = .pageSheet

        if let sheet = addVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        present(addVC, animated: true)
    }

    private func showSkipOrTurnOffActionSheet(for alarm: Alarm, at index: Int) {
        let actionSheet = UIAlertController(
            title: alarm.displayTitle,
            message: "알람을 어떻게 처리할까요?",
            preferredStyle: .actionSheet
        )

        // Skip once option (1번만 끄기)
        let skipOnceAction = UIAlertAction(title: "1번만 끄기", style: .default) { [weak self] _ in
            UIView.hapticFeedback(style: .light)
            self?.alarmManager.skipOnceAlarm(alarm)
            self?.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            self?.updateUI()
        }
        actionSheet.addAction(skipOnceAction)

        // Turn off completely option (완전히 끄기) - now deletes the alarm
        let deleteAction = UIAlertAction(title: "완전히 끄기", style: .destructive) { [weak self] _ in
            UIView.hapticFeedback(style: .medium)
            self?.alarmManager.deleteAlarm(alarm)
        }
        actionSheet.addAction(deleteAction)

        // Cancel option (취소)
        let cancelAction = UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
            self?.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }
        actionSheet.addAction(cancelAction)

        present(actionSheet, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension AlarmListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return alarmManager.alarms.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AlarmCell.identifier, for: indexPath) as? AlarmCell else {
            return UITableViewCell()
        }

        let alarm = alarmManager.alarms[indexPath.row]
        cell.configure(with: alarm)
        cell.delegate = self
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AlarmListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alarm = alarmManager.alarms[indexPath.row]

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
            UIView.hapticFeedback(style: .medium)
            self?.alarmManager.deleteAlarm(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self?.updateUI()
            completion(true)
        }

        deleteAction.image = UIImage(systemName: "trash.fill")
        deleteAction.backgroundColor = .destructiveAction

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - AlarmCellDelegate

extension AlarmListViewController: AlarmCellDelegate {
    func alarmCell(_ cell: AlarmCell, didToggleAlarm alarm: Alarm, isOn: Bool) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        if !isOn && alarm.isEnabled {
            showSkipOrTurnOffActionSheet(for: alarm, at: indexPath.row)
        } else {
            alarmManager.toggleAlarm(alarm, enabled: isOn)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: - AlarmDetailViewControllerDelegate

extension AlarmListViewController: AlarmDetailViewControllerDelegate {
    func alarmDetailViewController(_ controller: AlarmDetailViewController, didSaveAlarm hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?, existingAlarm: Alarm?) {
        if let existing = existingAlarm {
            alarmManager.updateAlarm(existing, hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate)
        } else {
            alarmManager.createAlarm(hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate)
        }
        tableView.reloadData()
        updateUI()
    }
}

// MARK: - AlarmManagerDelegate

extension AlarmListViewController: AlarmManagerDelegate {
    func alarmManagerDidUpdateAlarms(_ manager: AlarmManager) {
        tableView.reloadData()
        updateUI()
    }
}
