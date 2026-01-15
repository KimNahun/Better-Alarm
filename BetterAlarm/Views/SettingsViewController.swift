import UIKit
import MessageUI
import ActivityKit

class SettingsViewController: UIViewController {

    // MARK: - Properties

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - UI Components

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "설정"
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        table.delegate = self
        table.dataSource = self
        table.register(SettingsCell.self, forCellReuseIdentifier: SettingsCell.identifier)
        return table
    }()

    // MARK: - Settings Data

    private enum SettingsItem {
        case alarmPermission
        case liveActivity
        case appVersion
        case feedback
    }

    private struct SettingsRow {
        let icon: String
        let title: String
        let detail: String?
        let item: SettingsItem
    }

    private struct SettingsSection {
        let title: String
        let rows: [SettingsRow]
    }

    private var sections: [SettingsSection] {
        [
            SettingsSection(title: "일반", rows: [
                SettingsRow(icon: "alarm.fill", title: "알람 권한", detail: nil, item: .alarmPermission),
                SettingsRow(icon: "rectangle.stack.fill", title: "잠금화면 위젯", detail: nil, item: .liveActivity)
            ]),
            SettingsSection(title: "정보", rows: [
                SettingsRow(icon: "info.circle.fill", title: "앱 버전", detail: appVersion, item: .appVersion),
                SettingsRow(icon: "envelope.fill", title: "피드백 보내기", detail: nil, item: .feedback)
            ])
        ]
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.viewDidLoad("SettingsViewController")
        setupUI()
        setupConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppLogger.viewWillAppear("SettingsViewController")
        tableView.reloadData()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .backgroundTop

        view.addSubview(titleLabel)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Actions

    private func openAppSettings() {
        AppLogger.info("Opening app settings", category: .settings)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func sendFeedbackEmail() {
        AppLogger.buttonTapped("Send Feedback Email")
        guard MFMailComposeViewController.canSendMail() else {
            AppLogger.warning("Mail not configured on device", category: .settings)
            let alert = UIAlertController(
                title: "메일 설정 필요",
                message: "메일 앱이 설정되어 있지 않습니다.\nrlaskgns0212@naver.com으로 피드백을 보내주세요.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "복사하기", style: .default) { _ in
                AppLogger.buttonTapped("Copy Email Address")
                UIPasteboard.general.string = "rlaskgns0212@naver.com"
                UIView.hapticFeedback(style: .light)
            })
            alert.addAction(UIAlertAction(title: "확인", style: .cancel))
            present(alert, animated: true)
            return
        }

        AppLogger.debug("Presenting mail composer", category: .settings)
        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = self
        mailVC.setToRecipients(["rlaskgns0212@naver.com"])
        mailVC.setSubject("[BetterAlarm] 피드백")
        mailVC.setMessageBody("\n\n\n---\n앱 버전: \(appVersion)\niOS 버전: \(UIDevice.current.systemVersion)\n기기: \(UIDevice.current.model)", isHTML: false)

        present(mailVC, animated: true)
    }
    
    // MARK: - Toast

    // SettingsViewController.swift - showToast 메서드 전체 교체

    private func showToast(message: String, duration: TimeInterval = 2.5) {
        AppLogger.debug("Showing toast: \(message)", category: .ui)
        let toastContainer = UIView()
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        toastContainer.layer.cornerRadius = 12
        toastContainer.isUserInteractionEnabled = false

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "exclamationmark.circle.fill")
        iconView.tintColor = .systemOrange
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
}

// MARK: - Settings Cell

class SettingsCell: UITableViewCell {
    static let identifier = "SettingsCell"
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .accentPrimary
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17)
        label.textColor = .textPrimary
        return label
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17)
        label.textColor = .textTertiary
        return label
    }()
    
    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.white.withAlphaComponent(0.4)
        return imageView
    }()
    
    private let toggleSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.onTintColor = .accentPrimary
        toggle.isHidden = true
        return toggle
    }()
    
    var onToggleChanged: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.white.withAlphaComponent(0.05)
        selectionStyle = .default
        
        let selectedView = UIView()
        selectedView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        selectedBackgroundView = selectedView
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(chevronImageView)
        contentView.addSubview(toggleSwitch)
        
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 28),
            iconImageView.heightAnchor.constraint(equalToConstant: 28),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            chevronImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 14),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20),
            
            detailLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggleSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    @objc private func toggleChanged() {
        onToggleChanged?(toggleSwitch.isOn)
    }
    
    func configure(icon: String, title: String, detail: String?, showChevron: Bool, showToggle: Bool, toggleValue: Bool = false) {
        iconImageView.image = UIImage(systemName: icon)
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = detail == nil
        
        chevronImageView.isHidden = !showChevron || showToggle
        toggleSwitch.isHidden = !showToggle
        toggleSwitch.isOn = toggleValue
        
        selectionStyle = showToggle ? .none : .default
    }
    
    func setToggleValue(_ value: Bool) {
        toggleSwitch.setOn(value, animated: false)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        titleLabel.text = nil
        detailLabel.text = nil
        detailLabel.isHidden = true
        chevronImageView.isHidden = false
        toggleSwitch.isHidden = true
        toggleSwitch.isOn = false
        onToggleChanged = nil
        selectionStyle = .default
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.identifier, for: indexPath) as? SettingsCell else {
            return UITableViewCell()
        }
        
        let row = sections[indexPath.section].rows[indexPath.row]
        
        switch row.item {
        case .liveActivity:
            let isEnabled = LiveActivityManager.shared.isLiveActivityEnabled
            cell.configure(
                icon: row.icon,
                title: row.title,
                detail: nil,
                showChevron: false,
                showToggle: true,
                toggleValue: isEnabled
            )
            cell.onToggleChanged = { [weak self] isOn in
                self?.handleLiveActivityToggle(isOn: isOn, cell: cell)
            }

        case .appVersion:
            cell.configure(
                icon: row.icon,
                title: row.title,
                detail: row.detail,
                showChevron: false,
                showToggle: false
            )

        case .alarmPermission, .feedback:
            cell.configure(
                icon: row.icon,
                title: row.title,
                detail: row.detail,
                showChevron: true,
                showToggle: false
            )
        }

        return cell
    }
    
    private func handleLiveActivityToggle(isOn: Bool, cell: SettingsCell) {
        AppLogger.switchToggled("Live Activity", value: isOn)
        UIView.hapticFeedback(style: .light)

        if isOn {
            // 시스템에서 Live Activity가 허용되어 있는지 확인
            let authInfo = ActivityAuthorizationInfo()

            if !authInfo.areActivitiesEnabled {
                // 시스템에서 비활성화됨 - 스위치를 다시 끄고 안내
                AppLogger.warning("Live Activity not enabled in system settings", category: .permission)
                cell.setToggleValue(false)

                showToast(message: "설정에서 실시간 현황을 켜주세요")

                // 1초 후 설정으로 이동
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.openAppSettings()
                }
                return
            }
        }

        // 정상적으로 토글
        AppLogger.info("Toggling Live Activity to: \(isOn)", category: .liveActivity)
        Task { @MainActor in
            let nextAlarm = AlarmStore.shared.nextAlarm
            LiveActivityManager.shared.setEnabled(isOn, with: nextAlarm)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = sections[indexPath.section].rows[indexPath.row]
        AppLogger.cellSelected("Settings: \(row.title)")

        switch row.item {
        case .alarmPermission:
            UIView.hapticFeedback(style: .light)
            openAppSettings()
        case .feedback:
            UIView.hapticFeedback(style: .light)
            sendFeedbackEmail()
        case .appVersion, .liveActivity:
            AppLogger.debug("Non-interactive cell tapped: \(row.title)", category: .action)
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .textSecondary
        }
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        AppLogger.info("Mail compose finished with result: \(result.rawValue)", category: .settings)
        controller.dismiss(animated: true) { [weak self] in
            self?.showMailResult(result, error: error)
        }
    }

    private func showMailResult(_ result: MFMailComposeResult, error: Error?) {
        let message: String
        var showAlert = true

        switch result {
        case .sent:
            AppLogger.info("Feedback email sent successfully", category: .settings)
            UIView.hapticFeedback(style: .medium)
            message = "피드백이 전송되었습니다.\n감사합니다!"
        case .saved:
            AppLogger.info("Feedback email saved to drafts", category: .settings)
            message = "이메일이 임시보관함에 저장되었습니다."
        case .cancelled:
            AppLogger.debug("Feedback email cancelled", category: .settings)
            showAlert = false
            message = ""
        case .failed:
            AppLogger.error("Feedback email failed: \(error?.localizedDescription ?? "unknown")", category: .settings)
            message = "이메일 전송에 실패했습니다.\n\(error?.localizedDescription ?? "알 수 없는 오류")"
        @unknown default:
            AppLogger.warning("Unknown mail compose result", category: .settings)
            showAlert = false
            message = ""
        }

        if showAlert {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
        }
    }
}
