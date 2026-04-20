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
        } else {
            currentTheme = .summer
            UserDefaults.standard.set(PTheme.summer.rawValue, forKey: userDefaultsKey)
        }
        applyUIKitTheme(currentTheme)
        applyAlternateIcon(for: currentTheme)
    }

    func setTheme(_ theme: PTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: userDefaultsKey)
        applyUIKitTheme(theme)
        applyAlternateIcon(for: theme)
    }

    private func applyAlternateIcon(for theme: PTheme) {
        let iconName: String
        switch theme {
        case .spring:  iconName = "AppIcon-Spring"
        case .autumn:  iconName = "AppIcon-Autumn"
        case .winter:  iconName = "AppIcon-Winter"
        default:       iconName = "AppIcon-Summer"
        }
        guard UIApplication.shared.supportsAlternateIcons else { return }
        guard UIApplication.shared.alternateIconName != iconName else { return }

        // Private API: 시스템 확인 모달 없이 아이콘 변경
        let selectorString = "_setAlternateIconName:completionHandler:"
        let selector = NSSelectorFromString(selectorString)
        guard UIApplication.shared.responds(to: selector) else {
            // private API 미지원 시 공개 API fallback
            UIApplication.shared.setAlternateIconName(iconName) { _ in }
            return
        }
        typealias IconChangeFn = @convention(c) (NSObject, Selector, NSString?, @escaping (NSError?) -> Void) -> Void
        let imp = UIApplication.shared.method(for: selector)
        let fn = unsafeBitCast(imp, to: IconChangeFn.self)
        fn(UIApplication.shared, selector, iconName as NSString, { _ in })
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
