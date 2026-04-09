import Foundation
import PersonalColorDesignSystem
import UIKit

// MARK: - AppThemeManager

/// 앱 테마(PTheme)를 관리하는 클래스.
/// UserDefaults에 선택된 테마를 저장하여 앱 재시작 시 유지.
@MainActor
@Observable
final class AppThemeManager {
    private(set) var currentTheme: PTheme = .winter
    private let userDefaultsKey = "selectedTheme"

    init() {
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey),
           let theme = PTheme(rawValue: saved) {
            currentTheme = theme
        }
    }

    func setTheme(_ theme: PTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: userDefaultsKey)
        applyUIKitTheme(theme)
    }

    private func applyUIKitTheme(_ theme: PTheme) {
        let bgColor = UIColor(theme.colors.backgroundTop)
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = bgColor
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
