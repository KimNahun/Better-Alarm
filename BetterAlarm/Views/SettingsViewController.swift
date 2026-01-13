import UIKit

class SettingsViewController: UIViewController {

    // MARK: - Properties

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

    private let sections: [(title: String, items: [(icon: String, title: String, detail: String?)])] = [
        ("알람", [
            ("speaker.wave.3.fill", "알람 소리", "기본"),
            ("moon.zzz.fill", "스누즈 시간", "5분"),
            ("vibration", "진동", nil)
        ]),
        ("일반", [
            ("bell.badge.fill", "알림 권한", nil),
            ("clock.fill", "24시간제", nil)
        ]),
        ("정보", [
            ("info.circle.fill", "앱 버전", "1.0.0"),
            ("envelope.fill", "피드백 보내기", nil)
        ])
    ]

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
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.image = UIImage(systemName: item.icon)
        config.imageProperties.tintColor = .accentPrimary
        config.text = item.title
        config.textProperties.color = .textPrimary

        if let detail = item.detail {
            config.secondaryText = detail
            config.secondaryTextProperties.color = .textTertiary
        }

        cell.contentConfiguration = config
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        cell.accessoryType = item.detail == nil ? .disclosureIndicator : .none

        return cell
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UIView.hapticFeedback(style: .light)

        // Handle settings selection
        let item = sections[indexPath.section].items[indexPath.row]
        print("Selected: \(item.title)")
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .textSecondary
        }
    }
}
