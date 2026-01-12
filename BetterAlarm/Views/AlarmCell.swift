import UIKit

protocol AlarmCellDelegate: AnyObject {
    func alarmCell(_ cell: AlarmCell, didToggleAlarm alarm: Alarm, isOn: Bool)
}

class AlarmCell: UITableViewCell {
    static let identifier = "AlarmCell"

    weak var delegate: AlarmCellDelegate?
    private var alarm: Alarm?

    // MARK: - UI Components

    private let containerView: GlassCardView = {
        let view = GlassCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cornerRadius = 16
        return view
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .alarmTimeFont(size: 40)
        label.textColor = .textPrimary
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .alarmTitleFont(size: 15)
        label.textColor = .textSecondary
        return label
    }()

    private let repeatLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .alarmSubtitleFont(size: 13)
        label.textColor = .textTertiary
        return label
    }()

    private lazy var toggleSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.onTintColor = .accentPrimary
        toggle.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
        return toggle
    }()

    private let labelsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        return stack
    }()

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        labelsStackView.addArrangedSubview(titleLabel)
        labelsStackView.addArrangedSubview(repeatLabel)

        contentView.addSubview(containerView)
        containerView.addSubview(timeLabel)
        containerView.addSubview(labelsStackView)
        containerView.addSubview(toggleSwitch)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            timeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            timeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),

            labelsStackView.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 2),
            labelsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            labelsStackView.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -16),
            labelsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14),

            toggleSwitch.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18)
        ])
    }

    // MARK: - Configuration

    func configure(with alarm: Alarm) {
        self.alarm = alarm

        timeLabel.text = alarm.timeString
        titleLabel.text = alarm.displayTitle
        repeatLabel.text = alarm.repeatDescription

        toggleSwitch.setOn(alarm.isEnabled, animated: false)
        updateAppearance(isEnabled: alarm.isEnabled)
    }

    private func updateAppearance(isEnabled: Bool) {
        let alpha: CGFloat = isEnabled ? 1.0 : 0.5

        UIView.animate(withDuration: 0.2) {
            self.timeLabel.alpha = alpha
            self.titleLabel.alpha = alpha
            self.repeatLabel.alpha = alpha
            self.containerView.alpha = isEnabled ? 1.0 : 0.7
        }
    }

    // MARK: - Actions

    @objc private func switchToggled() {
        guard let alarm = alarm else { return }
        UIView.hapticFeedback(style: .medium)
        delegate?.alarmCell(self, didToggleAlarm: alarm, isOn: toggleSwitch.isOn)
    }

    // MARK: - Selection Animation

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        UIView.animate(withDuration: 0.15) {
            self.containerView.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        alarm = nil
        timeLabel.text = nil
        titleLabel.text = nil
        repeatLabel.text = nil
        toggleSwitch.isOn = false
        containerView.transform = .identity
        containerView.alpha = 1.0
    }

}
