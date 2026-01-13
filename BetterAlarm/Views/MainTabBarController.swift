import UIKit

class MainTabBarController: UITabBarController {

    // MARK: - Properties

    private var gradientLayer: CAGradientLayer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupViewControllers()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = tabBar.bounds
    }

    // MARK: - Setup

    private func setupTabBar() {
        // Custom appearance for tab bar
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(white: 0.08, alpha: 0.95)

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

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        // Add subtle top border
        let topBorder = UIView()
        topBorder.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(topBorder)

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: tabBar.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 0.5)
        ])
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
