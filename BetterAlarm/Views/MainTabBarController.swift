import UIKit

class MainTabBarController: UITabBarController {

    // MARK: - Properties

    private var backgroundGradientLayer: CAGradientLayer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupTabBar()
        setupViewControllers()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer?.frame = view.bounds
    }

    // MARK: - Setup

    private func setupBackground() {
        // Add gradient background to the tab bar controller's view
        // This prevents flickering when switching tabs
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.backgroundTop.cgColor,
            UIColor.backgroundBottom.cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.frame = view.bounds

        view.layer.insertSublayer(gradientLayer, at: 0)
        backgroundGradientLayer = gradientLayer
    }

    private func setupTabBar() {
        // Custom appearance for tab bar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.08, alpha: 1.0)

        // Shadow line at the top
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.1)

        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = .textTertiary
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.textTertiary,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]

        // Selected state
        appearance.stackedLayoutAppearance.selected.iconColor = .accentPrimary
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.accentPrimary,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]

        // Apply to all states
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        // Ensure the tab bar is not translucent
        tabBar.isTranslucent = false
    }

    private func setupViewControllers() {
        // Alarm List Tab
        let alarmListVC = AlarmListViewController()
        alarmListVC.tabBarItem = UITabBarItem(
            title: "알람",
            image: UIImage(systemName: "alarm"),
            selectedImage: UIImage(systemName: "alarm.fill")
        )

        // Weekly Alarm Tab
        let weeklyAlarmVC = WeeklyAlarmViewController()
        weeklyAlarmVC.tabBarItem = UITabBarItem(
            title: "주간 알람",
            image: UIImage(systemName: "calendar"),
            selectedImage: UIImage(systemName: "calendar.badge.clock")
        )

        // Settings Tab (placeholder for now)
        let settingsVC = SettingsViewController()
        settingsVC.tabBarItem = UITabBarItem(
            title: "설정",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        viewControllers = [alarmListVC, weeklyAlarmVC, settingsVC]
    }
}
