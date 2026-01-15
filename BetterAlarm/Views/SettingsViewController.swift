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
        table.register(SettingsCell.self, forCellReuseIdentifier: SettingsCell.identifier)
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
        imageView.tintColor = UIColor.white.withAlphaComponent(0.4)  // 흰색 계열
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
            cell.configure(
                icon: row.icon,
                title: row.title,
                detail: nil,
                showChevron: false,
                showToggle: true,
                toggleValue: LiveActivityManager.shared.isLiveActivityEnabled
            )
            cell.onToggleChanged = { [weak self] isOn in
                UIView.hapticFeedback(style: .light)
                Task { @MainActor in
                    let nextAlarm = AlarmStore.shared.nextAlarm
                    LiveActivityManager.shared.setEnabled(isOn, with: nextAlarm)
                }
            }
            
        case .appVersion:
            cell.configure(
                icon: row.icon,
                title: row.title,
                detail: row.detail,
                showChevron: false,
                showToggle: false
            )
            
        default:
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
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
        case .appVersion, .liveActivity:
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
