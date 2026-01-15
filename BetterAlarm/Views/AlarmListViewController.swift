import UIKit

class AlarmListViewController: UIViewController {
    // MARK: - Types

    enum Section {
        case main
    }

    // MARK: - Properties

    private let alarmStore = AlarmStore.shared
    private var dataSource: UITableViewDiffableDataSource<Section, Alarm.ID>!

    // MARK: - UI Components

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

    // Permission denied UI
    private let permissionDeniedView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let permissionWarningIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        imageView.tintColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let permissionWarningLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "알람 권한이 없습니다"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .textPrimary
        return label
    }()

    private lazy var openSettingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("설정으로 이동", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .accentPrimary
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)
        return button
    }()

    private var hasAlarmPermission: Bool = true

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
        configureDataSource()
        setupNotificationObserver()
        requestNotificationPermission()
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAlarmsDidUpdate),
            name: .alarmsDidUpdate,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleAppDidBecomeActive() {
        checkAlarmPermission()
        checkForCompletedAlarms()
        restartLiveActivityIfNeeded()
    }

    @objc private func handleAppWillEnterForeground() {
        checkAlarmPermission()
        checkForCompletedAlarms()
        restartLiveActivityIfNeeded()
    }
    
    private func checkForCompletedAlarms() {
        // Intent에서 완료된 알람 처리
        alarmStore.checkForCompletedAlarms()
    }

    private func restartLiveActivityIfNeeded() {
        Task { @MainActor in
            LiveActivityManager.shared.restartActivityIfNeeded(with: alarmStore.nextAlarm)
        }
    }

    @objc private func handleAlarmsDidUpdate() {
        applySnapshot()
        reconfigureVisibleCells()
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        alarmStore.loadAlarms()
        applySnapshot(animatingDifferences: false)
        checkAlarmPermission()
        checkForCompletedAlarms()
        updateUI()
    }

    private func checkAlarmPermission() {
        Task {
            let isAuthorized = AlarmKitService.shared.checkAuthorizationStatus()
            await MainActor.run {
                hasAlarmPermission = isAuthorized
                updatePermissionUI()
            }
        }
    }

    private func updatePermissionUI() {
        if hasAlarmPermission {
            permissionDeniedView.isHidden = true
            nextAlarmTimeLabel.isHidden = false
        } else {
            permissionDeniedView.isHidden = false
            nextAlarmTimeLabel.isHidden = true
        }
    }

    @objc private func openSettingsTapped() {
        UIView.hapticFeedback(style: .light)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .backgroundTop

        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(nextAlarmCard)
        nextAlarmCard.addSubview(nextAlarmTitleLabel)
        nextAlarmCard.addSubview(nextAlarmTimeLabel)

        nextAlarmCard.addSubview(permissionDeniedView)
        permissionDeniedView.addSubview(permissionWarningIcon)
        permissionDeniedView.addSubview(permissionWarningLabel)
        permissionDeniedView.addSubview(openSettingsButton)

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

            permissionDeniedView.topAnchor.constraint(equalTo: nextAlarmTitleLabel.bottomAnchor, constant: 6),
            permissionDeniedView.leadingAnchor.constraint(equalTo: nextAlarmCard.leadingAnchor, constant: 18),
            permissionDeniedView.trailingAnchor.constraint(equalTo: nextAlarmCard.trailingAnchor, constant: -18),
            permissionDeniedView.bottomAnchor.constraint(equalTo: nextAlarmCard.bottomAnchor, constant: -14),

            permissionWarningIcon.leadingAnchor.constraint(equalTo: permissionDeniedView.leadingAnchor),
            permissionWarningIcon.centerYAnchor.constraint(equalTo: permissionDeniedView.centerYAnchor),
            permissionWarningIcon.widthAnchor.constraint(equalToConstant: 24),
            permissionWarningIcon.heightAnchor.constraint(equalToConstant: 24),

            permissionWarningLabel.leadingAnchor.constraint(equalTo: permissionWarningIcon.trailingAnchor, constant: 8),
            permissionWarningLabel.centerYAnchor.constraint(equalTo: permissionDeniedView.centerYAnchor),

            openSettingsButton.trailingAnchor.constraint(equalTo: permissionDeniedView.trailingAnchor),
            openSettingsButton.centerYAnchor.constraint(equalTo: permissionDeniedView.centerYAnchor),
            openSettingsButton.widthAnchor.constraint(equalToConstant: 100),
            openSettingsButton.heightAnchor.constraint(equalToConstant: 32),

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
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { _, _ in }
    }

    // MARK: - DiffableDataSource

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, Alarm.ID>(tableView: tableView) { [weak self] tableView, indexPath, alarmId in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: AlarmCell.identifier, for: indexPath) as? AlarmCell,
                  let alarm = self?.alarmStore.alarms.first(where: { $0.id == alarmId }) else {
                return UITableViewCell()
            }

            cell.configure(with: alarm)
            cell.delegate = self
            return cell
        }

        dataSource.defaultRowAnimation = .fade
    }

    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Alarm.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(alarmStore.alarms.map { $0.id })
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    private func reconfigureVisibleCells() {
        for cell in tableView.visibleCells {
            guard let alarmCell = cell as? AlarmCell,
                  let indexPath = tableView.indexPath(for: cell),
                  let alarmId = dataSource.itemIdentifier(for: indexPath),
                  let alarm = alarmStore.alarms.first(where: { $0.id == alarmId }) else {
                continue
            }
            alarmCell.configure(with: alarm)
        }
    }

    // MARK: - Update UI

    private func updateUI() {
        let hasAlarms = !alarmStore.alarms.isEmpty
        emptyStateView.isHidden = hasAlarms
        tableView.isHidden = !hasAlarms
        updateNextAlarmDisplay()
    }

    private func updateNextAlarmDisplay() {
        if let displayString = alarmStore.nextAlarmDisplayString {
            nextAlarmTimeLabel.text = displayString
        } else {
            nextAlarmTimeLabel.text = "설정된 알람 없음"
        }
    }

    // MARK: - Toast Message

    func showToast(message: String, duration: TimeInterval = 2.5) {
        let toastContainer = UIView()
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        toastContainer.layer.cornerRadius = 12
        toastContainer.isUserInteractionEnabled = false

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "checkmark.circle.fill")
        iconView.tintColor = .accentPrimary
        iconView.contentMode = .scaleAspectFit

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 15, weight: .medium)
        messageLabel.numberOfLines = 0

        toastContainer.addSubview(iconView)
        toastContainer.addSubview(messageLabel)
        view.addSubview(toastContainer)

        NSLayoutConstraint.activate([
            toastContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            toastContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toastContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            iconView.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            messageLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 14),
            messageLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -14)
        ])

        toastContainer.alpha = 0
        toastContainer.transform = CGAffineTransform(translationX: 0, y: -20)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            toastContainer.alpha = 1
            toastContainer.transform = .identity
        }

        UIView.animate(withDuration: 0.5, delay: duration, options: .curveEaseOut) {
            toastContainer.alpha = 0
        } completion: { _ in
            toastContainer.removeFromSuperview()
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

    private func showSkipOrTurnOffActionSheet(for alarm: Alarm, at indexPath: IndexPath) {
        let actionSheet = UIAlertController(
            title: alarm.displayTitle,
            message: "알람을 어떻게 처리할까요?",
            preferredStyle: .actionSheet
        )

        // 이번만 건너뛰기
        let skipOnceAction = UIAlertAction(title: "이번만 건너뛰기", style: .default) { [weak self] _ in
            UIView.hapticFeedback(style: .light)
            self?.alarmStore.skipOnceAlarm(alarm)
            self?.showToast(message: "다음 알람을 건너뜁니다")
        }
        actionSheet.addAction(skipOnceAction)

        // 알람 끄기 (비활성화)
        let turnOffAction = UIAlertAction(title: "알람 끄기", style: .default) { [weak self] _ in
            UIView.hapticFeedback(style: .light)
            self?.alarmStore.toggleAlarm(alarm, enabled: false)
            self?.showToast(message: "알람이 꺼졌습니다")
        }
        actionSheet.addAction(turnOffAction)

        // 취소
        let cancelAction = UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
            self?.applySnapshot()
            self?.reconfigureVisibleCells()
        }
        actionSheet.addAction(cancelAction)

        present(actionSheet, animated: true)
    }

    private func deleteAlarm(_ alarm: Alarm) {
        alarmStore.deleteAlarm(alarm)
        showToast(message: "알람이 삭제되었습니다")
    }
}

// MARK: - UITableViewDelegate

extension AlarmListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let alarmId = dataSource.itemIdentifier(for: indexPath),
              let alarm = alarmStore.alarms.first(where: { $0.id == alarmId }) else {
            return 110
        }
        // 스킵 중인 알람은 더 높게
        return alarm.isSkippingNext ? 135 : 110
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let alarmId = dataSource.itemIdentifier(for: indexPath),
              let alarm = alarmStore.alarms.first(where: { $0.id == alarmId }) else { return }

        UIView.hapticFeedback(style: .light)

        let editVC = AlarmDetailViewController()
        editVC.delegate = self
        editVC.onDeleteAlarm = { [weak self] deletedAlarm in
            self?.alarmStore.deleteAlarm(deletedAlarm)
            self?.showToast(message: "알람이 삭제되었습니다")
        }
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
                  let alarm = self?.alarmStore.alarms.first(where: { $0.id == alarmId }) else {
                completion(false)
                return
            }

            UIView.hapticFeedback(style: .medium)
            self?.deleteAlarm(alarm)
            completion(true)
        }

        deleteAction.image = UIImage(systemName: "trash.fill")
        deleteAction.backgroundColor = .destructiveAction

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - AlarmCellDelegate

extension AlarmListViewController: AlarmCellDelegate {
    // AlarmListViewController.swift - alarmCell 델리게이트 메서드 전체 교체

    func alarmCell(_ cell: AlarmCell, didToggleAlarm alarm: Alarm, isOn: Bool) {
        // 현재 알람의 실제 상태 다시 확인 (stale 데이터 방지)
        guard let currentAlarm = alarmStore.alarms.first(where: { $0.id == alarm.id }) else {
            return
        }
        
        if isOn {
            // 스위치를 켜는 경우
            if currentAlarm.isSkippingNext {
                // 스킵 상태였다면 스킵 해제
                UIView.hapticFeedback(style: .light)
                alarmStore.clearSkipOnceAlarm(currentAlarm)
                showToast(message: "건너뛰기가 취소되었습니다")
            } else if !currentAlarm.isEnabled {
                // 꺼져있었다면 켜기
                UIView.hapticFeedback(style: .light)
                alarmStore.toggleAlarm(currentAlarm, enabled: true)
                showToast(message: "알람이 켜졌습니다")
            }
        } else {
            // 스위치를 끄는 경우
            if currentAlarm.isEnabled && !currentAlarm.isSkippingNext {
                if currentAlarm.isWeeklyAlarm {
                    // 주간 알람은 선택지 제공
                    guard let indexPath = tableView.indexPath(for: cell) else { return }
                    showSkipOrTurnOffActionSheet(for: currentAlarm, at: indexPath)
                } else {
                    // 1회성 알람은 바로 끄기
                    UIView.hapticFeedback(style: .light)
                    alarmStore.toggleAlarm(currentAlarm, enabled: false)
                    showToast(message: "알람이 꺼졌습니다")
                }
            }
        }
    }
}

// MARK: - AlarmDetailViewControllerDelegate

extension AlarmListViewController: AlarmDetailViewControllerDelegate {
    func alarmDetailViewController(_ controller: AlarmDetailViewController, didSaveAlarm hour: Int, minute: Int, title: String, weekdays: Set<Weekday>?, specificDate: Date?, soundName: String, existingAlarm: Alarm?) {
        if let existing = existingAlarm {
            alarmStore.updateAlarm(existing, hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate, soundName: soundName)
            showToast(message: "알람이 수정되었습니다")
        } else {
            alarmStore.createAlarm(hour: hour, minute: minute, title: title, weekdays: weekdays, specificDate: specificDate, soundName: soundName)
            showToast(message: "알람이 추가되었습니다")
        }
    }
}
