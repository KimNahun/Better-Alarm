import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var alarmRingingVC: AlarmRingingViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = MainTabBarController()
        window?.makeKeyAndVisible()

        // Load alarms and start Live Activity
        AlarmStore.shared.loadAlarms()
        AlarmStore.shared.rescheduleAllAlarms()
        AlarmStore.shared.startLiveActivity()

        // Setup alarm notification observer
        setupAlarmNotificationObserver()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Refresh alarms and clean up expired one-time alarms
        AlarmStore.shared.loadAlarms()
        AlarmStore.shared.cleanupExpiredOneTimeAlarms()
        AlarmStore.shared.updateLiveActivity()
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Refresh alarms
        AlarmStore.shared.loadAlarms()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }

    // MARK: - Alarm Notification Observer

    private func setupAlarmNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .alarmTriggered,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAlarmTriggered(notification)
        }
    }

    private func handleAlarmTriggered(_ notification: Notification) {
        var alarm: Alarm?

        // Try to get alarm from notification
        if let userInfo = notification.userInfo {
            if let alarmObj = userInfo["alarm"] as? Alarm {
                alarm = alarmObj
            } else if let alarmId = userInfo["alarmId"] as? String {
                alarm = AlarmStore.shared.alarms.first { $0.id.uuidString == alarmId }
            }
        }

        showAlarmRingingScreen(with: alarm)
    }

    func showAlarmRingingScreen(with alarm: Alarm?) {
        guard let rootVC = window?.rootViewController else { return }

        // Dismiss any existing alarm ringing screen
        if let existingAlarmVC = alarmRingingVC {
            existingAlarmVC.dismiss(animated: false)
            alarmRingingVC = nil
        }

        // Create and present the alarm ringing view controller
        let ringingVC = AlarmRingingViewController()
        ringingVC.delegate = self

        if let alarm = alarm {
            ringingVC.configure(with: alarm)
        }

        ringingVC.modalPresentationStyle = .fullScreen
        ringingVC.modalTransitionStyle = .crossDissolve

        // Present on top of everything
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(ringingVC, animated: true)
        alarmRingingVC = ringingVC
    }
}

// MARK: - AlarmRingingViewControllerDelegate

extension SceneDelegate: AlarmRingingViewControllerDelegate {
    func alarmRingingViewControllerDidDismiss(_ controller: AlarmRingingViewController) {
        alarmRingingVC = nil

        // Post notification that alarm was dismissed
        NotificationCenter.default.post(name: .alarmDismissed, object: nil)
    }

    func alarmRingingViewControllerDidSnooze(_ controller: AlarmRingingViewController, alarm: Alarm) {
        alarmRingingVC = nil

        // Show snooze confirmation (optional)
        if let rootVC = window?.rootViewController {
            let snoozeTime = Date().addingTimeInterval(5 * 60)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "a h:mm"

            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            // Show brief toast-like notification
            showSnoozeToast(on: topVC, time: formatter.string(from: snoozeTime))
        }
    }

    private func showSnoozeToast(on viewController: UIViewController, time: String) {
        let toastView = UIView()
        toastView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastView.layer.cornerRadius = 12
        toastView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "\(time)에 다시 알림"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        toastView.addSubview(label)
        viewController.view.addSubview(toastView)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -20),

            toastView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])

        toastView.alpha = 0
        toastView.transform = CGAffineTransform(translationX: 0, y: 20)

        UIView.animate(withDuration: 0.3) {
            toastView.alpha = 1
            toastView.transform = .identity
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            UIView.animate(withDuration: 0.3, animations: {
                toastView.alpha = 0
                toastView.transform = CGAffineTransform(translationX: 0, y: -20)
            }) { _ in
                toastView.removeFromSuperview()
            }
        }
    }
}
