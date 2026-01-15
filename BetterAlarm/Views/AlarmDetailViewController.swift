import UIKit

protocol AlarmDetailViewControllerDelegate: AnyObject {
    func alarmDetailViewController(
        _ controller: AlarmDetailViewController,
        didSaveAlarm hour: Int,
        minute: Int,
        title: String,
        weekdays: Set<Weekday>?,
        specificDate: Date?,
        soundName: String,
        existingAlarm: Alarm?
    )
}

class AlarmDetailViewController: UIViewController {
    // MARK: - Properties

    weak var delegate: AlarmDetailViewControllerDelegate?
    
    // 삭제 콜백
    var onDeleteAlarm: ((Alarm) -> Void)?

    private var existingAlarm: Alarm?
    private var isNewAlarm: Bool { existingAlarm == nil }

    private var selectedHour: Int = 8
    private var selectedMinute: Int = 0
    private var alarmTitle: String = ""
    private var selectedWeekdays: Set<Weekday> = []
    private var specificDate: Date?
    private var repeatMode: Int = 0

    private var gradientLayer: CAGradientLayer?

    // Dynamic constraints
    private var repeatCardBottomToSegmentConstraint: NSLayoutConstraint?
    private var repeatCardBottomToWeekdayConstraint: NSLayoutConstraint?
    private var repeatCardBottomToDatePickerConstraint: NSLayoutConstraint?

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        scroll.keyboardDismissMode = .onDrag
        return scroll
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let headerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("취소", for: .normal)
        button.setTitleColor(.textSecondary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17)
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return button
    }()

    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("저장", for: .normal)
        button.setTitleColor(.accentPrimary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        return button
    }()

    private let timePickerCard: GlassCardView = {
        let view = GlassCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cornerRadius = 20
        return view
    }()

    private lazy var timePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "ko_KR")
        picker.overrideUserInterfaceStyle = .dark
        picker.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
        return picker
    }()

    private let titleCard: GlassCardView = {
        let view = GlassCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cornerRadius = 16
        return view
    }()

    private let titleFieldLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "알람 제목"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .textSecondary
        return label
    }()

    private lazy var titleTextField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "알람"
        field.font = .systemFont(ofSize: 17)
        field.textColor = .textPrimary
        field.attributedPlaceholder = NSAttributedString(
            string: "알람",
            attributes: [.foregroundColor: UIColor.textTertiary]
        )
        field.delegate = self
        field.returnKeyType = .done
        return field
    }()

    private let repeatCard: GlassCardView = {
        let view = GlassCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cornerRadius = 16
        return view
    }()

    private let repeatLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "반복"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .textSecondary
        return label
    }()

    private lazy var repeatSegmentControl: UISegmentedControl = {
        let items = ["반복 안 함", "요일 반복", "특정 날짜"]
        let control = UISegmentedControl(items: items)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .accentPrimary
        control.setTitleTextAttributes([.foregroundColor: UIColor.textSecondary], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.addTarget(self, action: #selector(repeatTypeChanged), for: .valueChanged)
        return control
    }()

    private let weekdayStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 6
        return stack
    }()

    private var weekdayButtons: [UIButton] = []

    private lazy var datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale(identifier: "ko_KR")
        picker.minimumDate = Date()
        picker.tintColor = .accentPrimary
        picker.overrideUserInterfaceStyle = .dark
        picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        return picker
    }()
    
    // 삭제 버튼
    private lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("알람 삭제", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        button.isHidden = true  // 새 알람일 때는 숨김
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupWeekdayButtons()
        updateUIForExistingAlarm()
        updateRepeatSectionVisibility(animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = view.bounds
    }

    // MARK: - Configuration

    func configure(with alarm: Alarm) {
        existingAlarm = alarm
        selectedHour = alarm.hour
        selectedMinute = alarm.minute
        alarmTitle = alarm.title

        switch alarm.schedule {
        case .once:
            repeatMode = 0
        case .weekly(let days):
            repeatMode = 1
            selectedWeekdays = days
        case .specificDate(let date):
            repeatMode = 2
            specificDate = date
        }
    }

    // MARK: - Setup

    private func setupUI() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.backgroundTop.cgColor,
            UIColor.backgroundBottom.cgColor
        ]
        gradient.locations = [0.0, 1.0]
        view.layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient

        headerLabel.text = isNewAlarm ? "새 알람" : "알람 편집"
        deleteButton.isHidden = isNewAlarm

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(headerLabel)
        contentView.addSubview(cancelButton)
        contentView.addSubview(saveButton)
        contentView.addSubview(timePickerCard)
        timePickerCard.addSubview(timePicker)
        contentView.addSubview(titleCard)
        titleCard.addSubview(titleFieldLabel)
        titleCard.addSubview(titleTextField)
        contentView.addSubview(repeatCard)
        repeatCard.addSubview(repeatLabel)
        repeatCard.addSubview(repeatSegmentControl)
        repeatCard.addSubview(weekdayStackView)
        repeatCard.addSubview(datePicker)
        contentView.addSubview(deleteButton)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        repeatCardBottomToSegmentConstraint = repeatCard.bottomAnchor.constraint(equalTo: repeatSegmentControl.bottomAnchor, constant: 16)
        repeatCardBottomToWeekdayConstraint = repeatCard.bottomAnchor.constraint(equalTo: weekdayStackView.bottomAnchor, constant: 16)
        repeatCardBottomToDatePickerConstraint = repeatCard.bottomAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 16)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            cancelButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            saveButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            timePickerCard.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 30),
            timePickerCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            timePickerCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            timePicker.topAnchor.constraint(equalTo: timePickerCard.topAnchor, constant: 8),
            timePicker.leadingAnchor.constraint(equalTo: timePickerCard.leadingAnchor),
            timePicker.trailingAnchor.constraint(equalTo: timePickerCard.trailingAnchor),
            timePicker.bottomAnchor.constraint(equalTo: timePickerCard.bottomAnchor, constant: -8),

            titleCard.topAnchor.constraint(equalTo: timePickerCard.bottomAnchor, constant: 16),
            titleCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            titleFieldLabel.topAnchor.constraint(equalTo: titleCard.topAnchor, constant: 14),
            titleFieldLabel.leadingAnchor.constraint(equalTo: titleCard.leadingAnchor, constant: 16),

            titleTextField.topAnchor.constraint(equalTo: titleFieldLabel.bottomAnchor, constant: 8),
            titleTextField.leadingAnchor.constraint(equalTo: titleCard.leadingAnchor, constant: 16),
            titleTextField.trailingAnchor.constraint(equalTo: titleCard.trailingAnchor, constant: -16),
            titleTextField.bottomAnchor.constraint(equalTo: titleCard.bottomAnchor, constant: -14),
            titleTextField.heightAnchor.constraint(equalToConstant: 36),

            repeatCard.topAnchor.constraint(equalTo: titleCard.bottomAnchor, constant: 16),
            repeatCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            repeatCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            repeatLabel.topAnchor.constraint(equalTo: repeatCard.topAnchor, constant: 14),
            repeatLabel.leadingAnchor.constraint(equalTo: repeatCard.leadingAnchor, constant: 16),

            repeatSegmentControl.topAnchor.constraint(equalTo: repeatLabel.bottomAnchor, constant: 12),
            repeatSegmentControl.leadingAnchor.constraint(equalTo: repeatCard.leadingAnchor, constant: 16),
            repeatSegmentControl.trailingAnchor.constraint(equalTo: repeatCard.trailingAnchor, constant: -16),
            repeatSegmentControl.heightAnchor.constraint(equalToConstant: 36),

            weekdayStackView.topAnchor.constraint(equalTo: repeatSegmentControl.bottomAnchor, constant: 16),
            weekdayStackView.leadingAnchor.constraint(equalTo: repeatCard.leadingAnchor, constant: 16),
            weekdayStackView.trailingAnchor.constraint(equalTo: repeatCard.trailingAnchor, constant: -16),
            weekdayStackView.heightAnchor.constraint(equalToConstant: 44),

            datePicker.topAnchor.constraint(equalTo: repeatSegmentControl.bottomAnchor, constant: 16),
            datePicker.centerXAnchor.constraint(equalTo: repeatCard.centerXAnchor),
            
            // 삭제 버튼
            deleteButton.topAnchor.constraint(equalTo: repeatCard.bottomAnchor, constant: 32),
            deleteButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            deleteButton.heightAnchor.constraint(equalToConstant: 50),
            deleteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func setupWeekdayButtons() {
        let weekdays: [(Weekday, String)] = [
            (.sunday, "일"), (.monday, "월"), (.tuesday, "화"),
            (.wednesday, "수"), (.thursday, "목"), (.friday, "금"), (.saturday, "토")
        ]

        for (_, name) in weekdays {
            let button = UIButton(type: .system)
            button.setTitle(name, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.setTitleColor(.textSecondary, for: .normal)
            button.backgroundColor = .glassBackground
            button.layer.cornerRadius = 22
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.glassBorder.cgColor
            button.addTarget(self, action: #selector(weekdayTapped(_:)), for: .touchUpInside)

            weekdayButtons.append(button)
            weekdayStackView.addArrangedSubview(button)
        }
    }

    private func updateUIForExistingAlarm() {
        guard existingAlarm != nil else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = selectedHour
        components.minute = selectedMinute
        if let date = Calendar.current.date(from: components) {
            timePicker.date = date
        }

        titleTextField.text = alarmTitle
        repeatSegmentControl.selectedSegmentIndex = repeatMode
        deleteButton.isHidden = false

        if repeatMode == 2, let date = specificDate {
            datePicker.date = date
        }

        updateWeekdayButtons()
    }

    private func updateRepeatSectionVisibility(animated: Bool) {
        let selectedIndex = repeatSegmentControl.selectedSegmentIndex

        repeatCardBottomToSegmentConstraint?.isActive = false
        repeatCardBottomToWeekdayConstraint?.isActive = false
        repeatCardBottomToDatePickerConstraint?.isActive = false

        let animations = {
            switch selectedIndex {
            case 1:
                self.weekdayStackView.isHidden = false
                self.weekdayStackView.alpha = 1
                self.datePicker.isHidden = true
                self.datePicker.alpha = 0
                self.repeatCardBottomToWeekdayConstraint?.isActive = true

            case 2:
                self.weekdayStackView.isHidden = true
                self.weekdayStackView.alpha = 0
                self.datePicker.isHidden = false
                self.datePicker.alpha = 1
                self.repeatCardBottomToDatePickerConstraint?.isActive = true

            default:
                self.weekdayStackView.isHidden = true
                self.weekdayStackView.alpha = 0
                self.datePicker.isHidden = true
                self.datePicker.alpha = 0
                self.repeatCardBottomToSegmentConstraint?.isActive = true
            }

            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: animations)
        } else {
            animations()
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        UIView.hapticFeedback(style: .light)
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        UIView.hapticFeedback(style: .medium)

        let calendar = Calendar.current
        selectedHour = calendar.component(.hour, from: timePicker.date)
        selectedMinute = calendar.component(.minute, from: timePicker.date)
        alarmTitle = titleTextField.text ?? ""

        var weekdays: Set<Weekday>? = nil
        var date: Date? = nil

        switch repeatSegmentControl.selectedSegmentIndex {
        case 1:
            weekdays = selectedWeekdays.isEmpty ? nil : selectedWeekdays
        case 2:
            date = datePicker.date
        default:
            break
        }

        delegate?.alarmDetailViewController(
            self,
            didSaveAlarm: selectedHour,
            minute: selectedMinute,
            title: alarmTitle,
            weekdays: weekdays,
            specificDate: date,
            soundName: "default",
            existingAlarm: existingAlarm
        )
        dismiss(animated: true)
    }
    
    @objc private func deleteTapped() {
        UIView.hapticFeedback(style: .medium)
        
        guard let alarm = existingAlarm else { return }
        
        let alert = UIAlertController(
            title: "알람 삭제",
            message: "'\(alarm.displayTitle)' 알람을 삭제하시겠습니까?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.onDeleteAlarm?(alarm)
            self?.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }

    @objc private func timeChanged() {
        UIView.selectionFeedback()
    }

    @objc private func dateChanged() {
        UIView.selectionFeedback()
        specificDate = datePicker.date
    }

    @objc private func repeatTypeChanged() {
        UIView.hapticFeedback(style: .light)
        repeatMode = repeatSegmentControl.selectedSegmentIndex
        updateRepeatSectionVisibility(animated: true)
    }

    @objc private func weekdayTapped(_ sender: UIButton) {
        UIView.hapticFeedback(style: .light)

        let weekdays: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        guard let index = weekdayButtons.firstIndex(of: sender) else { return }
        let weekday = weekdays[index]

        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }

        updateWeekdayButtons()
    }

    private func updateWeekdayButtons() {
        let weekdays: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

        for (index, button) in weekdayButtons.enumerated() {
            let weekday = weekdays[index]
            let isSelected = selectedWeekdays.contains(weekday)

            UIView.animate(withDuration: 0.2) {
                button.backgroundColor = isSelected ? .accentPrimary : .glassBackground
                button.setTitleColor(isSelected ? .white : .textSecondary, for: .normal)
                button.layer.borderColor = isSelected ? UIColor.accentPrimary.cgColor : UIColor.glassBorder.cgColor
            }
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - UITextFieldDelegate

extension AlarmDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
