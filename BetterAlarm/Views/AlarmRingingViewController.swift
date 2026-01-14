import UIKit

protocol AlarmRingingViewControllerDelegate: AnyObject {
    func alarmRingingViewControllerDidDismiss(_ controller: AlarmRingingViewController)
    func alarmRingingViewControllerDidSnooze(_ controller: AlarmRingingViewController, alarm: Alarm)
}

class AlarmRingingViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: AlarmRingingViewControllerDelegate?
    private var alarm: Alarm?
    private var gradientLayer: CAGradientLayer?
    private var pulseAnimationLayer: CAShapeLayer?
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0

    // MARK: - UI Components

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .alarmTimeFont(size: 72)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let periodLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.8)
        label.textAlignment = .center
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let alarmIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "alarm.fill")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let pulseView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 80
        return view
    }()

    private lazy var dismissButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("알람 끄기", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 30
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        button.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        return button
    }()

    private lazy var snoozeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("5분 후 다시 알림", for: .normal)
        button.setTitleColor(.white.withAlphaComponent(0.9), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(snoozeTapped), for: .touchUpInside)
        return button
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.7)
        label.textAlignment = .center
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        startAnimations()
        updateTimeDisplay()

        // Start playing alarm sound
        AlarmPlayer.shared.playAlarmSound(named: alarm?.soundName ?? "default")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAnimations()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Configuration

    func configure(with alarm: Alarm) {
        self.alarm = alarm
    }

    // MARK: - Setup

    private func setupUI() {
        // Gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0).cgColor,
            UIColor(red: 0.2, green: 0.1, blue: 0.4, alpha: 1.0).cgColor,
            UIColor(red: 0.1, green: 0.05, blue: 0.2, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        self.gradientLayer = gradientLayer

        view.addSubview(dateLabel)
        view.addSubview(pulseView)
        view.addSubview(alarmIconView)
        view.addSubview(periodLabel)
        view.addSubview(timeLabel)
        view.addSubview(titleLabel)
        view.addSubview(dismissButton)
        view.addSubview(snoozeButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            dateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            pulseView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pulseView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            pulseView.widthAnchor.constraint(equalToConstant: 160),
            pulseView.heightAnchor.constraint(equalToConstant: 160),

            alarmIconView.centerXAnchor.constraint(equalTo: pulseView.centerXAnchor),
            alarmIconView.centerYAnchor.constraint(equalTo: pulseView.centerYAnchor),
            alarmIconView.widthAnchor.constraint(equalToConstant: 60),
            alarmIconView.heightAnchor.constraint(equalToConstant: 60),

            periodLabel.bottomAnchor.constraint(equalTo: timeLabel.topAnchor, constant: -4),
            periodLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            timeLabel.topAnchor.constraint(equalTo: pulseView.bottomAnchor, constant: 40),
            timeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            dismissButton.bottomAnchor.constraint(equalTo: snoozeButton.topAnchor, constant: -20),
            dismissButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 200),
            dismissButton.heightAnchor.constraint(equalToConstant: 60),

            snoozeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            snoozeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            snoozeButton.widthAnchor.constraint(equalToConstant: 200),
            snoozeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func updateTimeDisplay() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        let period = hour < 12 ? "오전" : "오후"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)

        periodLabel.text = period
        timeLabel.text = String(format: "%d:%02d", displayHour, minute)

        if let alarm = alarm {
            titleLabel.text = alarm.displayTitle
        } else {
            titleLabel.text = "알람"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "M월 d일 EEEE"
        dateLabel.text = dateFormatter.string(from: now)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Pulse animation
        startPulseAnimation()

        // Icon shake animation
        startShakeAnimation()
    }

    private func startPulseAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.0
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.3
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseView.layer.add(pulseAnimation, forKey: "pulse")

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.duration = 1.0
        opacityAnimation.fromValue = 0.3
        opacityAnimation.toValue = 0.1
        opacityAnimation.autoreverses = true
        opacityAnimation.repeatCount = .infinity
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseView.layer.add(opacityAnimation, forKey: "opacity")
    }

    private func startShakeAnimation() {
        let shakeAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        shakeAnimation.values = [-0.1, 0.1, -0.1, 0.1, 0]
        shakeAnimation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        shakeAnimation.duration = 0.5
        shakeAnimation.repeatCount = .infinity
        alarmIconView.layer.add(shakeAnimation, forKey: "shake")
    }

    private func stopAnimations() {
        pulseView.layer.removeAllAnimations()
        alarmIconView.layer.removeAllAnimations()
    }

    // MARK: - Actions

    @objc private func dismissTapped() {
        UIView.hapticFeedback(style: .medium)
        AlarmPlayer.shared.stopAlarm()
        stopAnimations()

        let completedAlarm = alarm

        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            // Handle one-time alarm cleanup AFTER dismiss animation completes
            if let alarm = completedAlarm {
                AlarmStore.shared.handleAlarmCompleted(alarm)
            }

            self.delegate?.alarmRingingViewControllerDidDismiss(self)
        }
    }

    @objc private func snoozeTapped() {
        UIView.hapticFeedback(style: .light)
        AlarmPlayer.shared.stopAlarm()
        stopAnimations()

        dismiss(animated: true) { [weak self] in
            guard let self = self, let alarm = self.alarm else { return }
            AlarmPlayer.shared.snoozeAlarm(alarm, minutes: 5)
            self.delegate?.alarmRingingViewControllerDidSnooze(self, alarm: alarm)
        }
    }
}
