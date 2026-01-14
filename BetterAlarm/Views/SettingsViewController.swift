import UIKit
import MessageUI

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
        table.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        return table
    }()

    // MARK: - Settings Data

    private enum SettingsItem {
        case alarmSound
        case snoozeTime
        case vibration
        case alarmPermission
        case liveActivity
        case use24HourFormat
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
            SettingsSection(title: "알람", rows: [
                SettingsRow(icon: "speaker.wave.3.fill", title: "알람 소리", detail: "기본", item: .alarmSound),
                SettingsRow(icon: "moon.zzz.fill", title: "스누즈 시간", detail: "5분", item: .snoozeTime),
                SettingsRow(icon: "iphone.radiowaves.left.and.right", title: "진동", detail: nil, item: .vibration)
            ]),
            SettingsSection(title: "일반", rows: [
                SettingsRow(icon: "alarm.fill", title: "알람 권한", detail: nil, item: .alarmPermission),
                SettingsRow(icon: "rectangle.stack.fill", title: "잠금화면 위젯", detail: nil, item: .liveActivity),
                SettingsRow(icon: "clock.fill", title: "24시간제", detail: nil, item: .use24HourFormat)
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
        setupUI()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupUI() {
        // Use solid background color to prevent white flash on tab switch
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
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func sendFeedbackEmail() {
        guard MFMailComposeViewController.canSendMail() else {
            // Show alert if mail is not configured
            let alert = UIAlertController(
                title: "메일 설정 필요",
                message: "메일 앱이 설정되어 있지 않습니다.\nrlaskgns0212@naver.com으로 피드백을 보내주세요.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "복사하기", style: .default) { _ in
                UIPasteboard.general.string = "rlaskgns0212@naver.com"
                UIView.hapticFeedback(style: .light)
            })
            alert.addAction(UIAlertAction(title: "확인", style: .cancel))
            present(alert, animated: true)
            return
        }

        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = self
        mailVC.setToRecipients(["rlaskgns0212@naver.com"])
        mailVC.setSubject("[BetterAlarm] 피드백")
        mailVC.setMessageBody("\n\n\n---\n앱 버전: \(appVersion)\niOS 버전: \(UIDevice.current.systemVersion)\n기기: \(UIDevice.current.model)", isHTML: false)

        present(mailVC, animated: true)
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.image = UIImage(systemName: row.icon)
        config.imageProperties.tintColor = .accentPrimary
        config.text = row.title
        config.textProperties.color = .textPrimary

        if let detail = row.detail {
            config.secondaryText = detail
            config.secondaryTextProperties.color = .textTertiary
        }

        cell.contentConfiguration = config
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.05)

        // Configure accessory views
        switch row.item {
        case .liveActivity:
            let toggle = UISwitch()
            toggle.onTintColor = .accentPrimary
            toggle.tag = 100 // Tag to identify this switch
            toggle.addTarget(self, action: #selector(liveActivityToggleChanged(_:)), for: .valueChanged)
            Task { @MainActor in
                toggle.isOn = LiveActivityManager.shared.isLiveActivityEnabled
            }
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        case .alarmPermission, .feedback:
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
        case .appVersion:
            cell.accessoryView = nil
            cell.accessoryType = .none
            cell.selectionStyle = .none
        default:
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
        }

        return cell
    }

    @objc private func liveActivityToggleChanged(_ sender: UISwitch) {
        UIView.hapticFeedback(style: .light)
        Task { @MainActor in
            let nextAlarm = AlarmStore.shared.nextAlarm
            LiveActivityManager.shared.setEnabled(sender.isOn, with: nextAlarm)
        }
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = sections[indexPath.section].rows[indexPath.row]

        switch row.item {
        case .alarmPermission:
            UIView.hapticFeedback(style: .light)
            openAppSettings()
        case .feedback:
            UIView.hapticFeedback(style: .light)
            sendFeedbackEmail()
        case .appVersion:
            // Do nothing for app version
            break
        default:
            UIView.hapticFeedback(style: .light)
            print("Selected: \(row.title)")
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
        controller.dismiss(animated: true) { [weak self] in
            self?.showMailResult(result, error: error)
        }
    }

    private func showMailResult(_ result: MFMailComposeResult, error: Error?) {
        let message: String
        var showAlert = true

        switch result {
        case .sent:
            UIView.hapticFeedback(style: .medium)
            message = "피드백이 전송되었습니다.\n감사합니다!"
        case .saved:
            message = "이메일이 임시보관함에 저장되었습니다."
        case .cancelled:
            showAlert = false
            message = ""
        case .failed:
            message = "이메일 전송에 실패했습니다.\n\(error?.localizedDescription ?? "알 수 없는 오류")"
        @unknown default:
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
