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

    private let accentLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 2
        return view
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .alarmTimeFont(size: 40)
        label.textColor = .textPrimary
        return label
    }()

    private let typeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .medium)
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

    private let skipBadgeView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.15)
        view.layer.cornerRadius = 6
        view.isHidden = true
        return view
    }()
    
    private let skipIconLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1.0)
        label.text = "다음 알람 건너뛰기"
        return label
    }()
    
    private let nextAlarmInfoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .textTertiary
        label.isHidden = true
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
        stack.spacing = 3
        stack.alignment = .leading
        return stack
    }()
    
    // 동적 높이를 위한 bottom constraint
    private var containerBottomConstraint: NSLayoutConstraint?

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

        // Skip badge 구성
        skipBadgeView.addSubview(skipIconLabel)
        
        labelsStackView.addArrangedSubview(titleLabel)
        labelsStackView.addArrangedSubview(repeatLabel)
        labelsStackView.addArrangedSubview(skipBadgeView)
        labelsStackView.addArrangedSubview(nextAlarmInfoLabel)

        contentView.addSubview(containerView)
        containerView.addSubview(accentLine)
        containerView.addSubview(timeLabel)
        containerView.addSubview(typeLabel)
        containerView.addSubview(labelsStackView)
        containerView.addSubview(toggleSwitch)

        setupConstraints()
    }

    private func setupConstraints() {
        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerBottomConstraint!,

            accentLine.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            accentLine.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            accentLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 0),
            accentLine.widthAnchor.constraint(equalToConstant: 4),

            timeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            timeLabel.leadingAnchor.constraint(equalTo: accentLine.trailingAnchor, constant: 14),
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),

            typeLabel.firstBaselineAnchor.constraint(equalTo: timeLabel.firstBaselineAnchor),
            typeLabel.leadingAnchor.constraint(equalTo: timeLabel.trailingAnchor, constant: 8),

            labelsStackView.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 4),
            labelsStackView.leadingAnchor.constraint(equalTo: accentLine.trailingAnchor, constant: 14),
            labelsStackView.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -16),
            labelsStackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -14),

            toggleSwitch.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            
            // Skip badge constraints
            skipIconLabel.topAnchor.constraint(equalTo: skipBadgeView.topAnchor, constant: 4),
            skipIconLabel.bottomAnchor.constraint(equalTo: skipBadgeView.bottomAnchor, constant: -4),
            skipIconLabel.leadingAnchor.constraint(equalTo: skipBadgeView.leadingAnchor, constant: 8),
            skipIconLabel.trailingAnchor.constraint(equalTo: skipBadgeView.trailingAnchor, constant: -8)
        ])
    }

    // MARK: - Configuration

    func configure(with alarm: Alarm) {
        self.alarm = alarm

        timeLabel.text = alarm.timeString
        titleLabel.text = alarm.displayTitle
        repeatLabel.text = alarm.repeatDescription

        configureTypeIndicator(for: alarm)
        configureSkipInfo(for: alarm)

        toggleSwitch.setOn(alarm.isEnabled, animated: false)
        updateAppearance(isEnabled: alarm.isEnabled, isSkipping: alarm.isSkippingNext)
    }

    private func configureSkipInfo(for alarm: Alarm) {
        guard alarm.isEnabled, alarm.isSkippingNext, let skippedDate = alarm.skippedDate else {
            skipBadgeView.isHidden = true
            nextAlarmInfoLabel.isHidden = true
            return
        }

        skipBadgeView.isHidden = false

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        // 스킵된 날짜 포맷
        let skippedMonth = calendar.component(.month, from: skippedDate)
        let skippedDay = calendar.component(.day, from: skippedDate)
        let skippedWeekday = calendar.component(.weekday, from: skippedDate)
        let skippedWeekdayName = Weekday(rawValue: skippedWeekday)?.shortName ?? ""

        skipIconLabel.text = "\(skippedMonth)/\(skippedDay)(\(skippedWeekdayName)) 건너뛰기"

        // 다음 알람 날짜 계산
        if let nextDate = alarm.nextTriggerDate() {
            nextAlarmInfoLabel.isHidden = false
            
            let nextMonth = calendar.component(.month, from: nextDate)
            let nextDay = calendar.component(.day, from: nextDate)
            let nextWeekday = calendar.component(.weekday, from: nextDate)
            let nextWeekdayName = Weekday(rawValue: nextWeekday)?.shortName ?? ""
            
            nextAlarmInfoLabel.text = "다음 알람: \(nextMonth)/\(nextDay)(\(nextWeekdayName))"
        } else {
            nextAlarmInfoLabel.isHidden = true
        }
    }

    private func configureTypeIndicator(for alarm: Alarm) {
        let accentColor: UIColor
        let typeText: String

        switch alarm.schedule {
        case .once:
            accentColor = UIColor(red: 0.65, green: 0.55, blue: 0.95, alpha: 1.0)
            typeText = "1회"
        case .weekly(let days):
            accentColor = UIColor(red: 0.45, green: 0.7, blue: 0.95, alpha: 1.0)
            typeText = formatWeekdays(days)
        case .specificDate(let date):
            accentColor = UIColor(red: 0.95, green: 0.55, blue: 0.45, alpha: 1.0)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "M/d"
            typeText = formatter.string(from: date)
        }

        accentLine.backgroundColor = accentColor
        typeLabel.text = typeText
        typeLabel.textColor = accentColor
    }

    private func formatWeekdays(_ days: Set<Weekday>) -> String {
        if days.count == 7 {
            return "매일"
        } else if days == Set([Weekday.saturday, .sunday]) {
            return "주말"
        } else if days == Set([Weekday.monday, .tuesday, .wednesday, .thursday, .friday]) {
            return "주중"
        } else {
            let sorted = days.sorted { $0.rawValue < $1.rawValue }
            return sorted.map { $0.shortName }.joined(separator: " ")
        }
    }

    private func updateAppearance(isEnabled: Bool, isSkipping: Bool = false) {
        let alpha: CGFloat
        let containerAlpha: CGFloat
        
        if !isEnabled {
            alpha = 0.4
            containerAlpha = 0.6
        } else if isSkipping {
            alpha = 0.7
            containerAlpha = 0.85
        } else {
            alpha = 1.0
            containerAlpha = 1.0
        }

        UIView.animate(withDuration: 0.2) {
            self.timeLabel.alpha = alpha
            self.titleLabel.alpha = alpha
            self.repeatLabel.alpha = alpha
            self.typeLabel.alpha = alpha
            self.accentLine.alpha = alpha
            self.containerView.alpha = containerAlpha
            self.skipBadgeView.alpha = 1.0
            self.nextAlarmInfoLabel.alpha = 1.0
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
        typeLabel.text = nil
        skipBadgeView.isHidden = true
        nextAlarmInfoLabel.isHidden = true
        nextAlarmInfoLabel.text = nil
        toggleSwitch.isOn = false
        containerView.transform = .identity
        containerView.alpha = 1.0
        timeLabel.alpha = 1.0
        titleLabel.alpha = 1.0
        repeatLabel.alpha = 1.0
        typeLabel.alpha = 1.0
        accentLine.alpha = 1.0
    }
}
