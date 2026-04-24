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
            AppLogger.info("Theme restored from UserDefaults: \(theme.rawValue)", category: .settings)
        } else {
            currentTheme = .summer
            UserDefaults.standard.set(PTheme.summer.rawValue, forKey: userDefaultsKey)
            AppLogger.info("Theme first launch — defaulting to summer", category: .settings)
        }
        applyUIKitTheme(currentTheme)
        // init() 시점에는 UIApplication이 완전히 준비되지 않아 아이콘 변경 실패 가능
        // 약간 지연시켜 앱 런치 완료 후 적용
        DispatchQueue.main.async { [self] in
            applyAlternateIcon(for: currentTheme)
        }
    }

    /// 현재 테마의 표시 이름을 반환한다 (ViewModel이 PTheme을 직접 참조하지 않도록).
    var currentThemeDisplayName: String {
        currentTheme.displayName
    }

    /// 테마 이름(rawValue)으로 테마를 설정한다. ViewModel에서 PTheme import 없이 사용 가능.
    func setThemeByName(_ name: String) {
        guard let theme = PTheme(rawValue: name) else {
            AppLogger.warning("Unknown theme name: \(name)", category: .settings)
            return
        }
        setTheme(theme)
    }

    func setTheme(_ theme: PTheme) {
        let old = currentTheme
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: userDefaultsKey)
        applyUIKitTheme(theme)
        applyAlternateIcon(for: theme)
        AppLogger.info("Theme changed: \(old.rawValue) → \(theme.rawValue)", category: .settings)
    }

    private func applyAlternateIcon(for theme: PTheme) {
        let iconName: String
        switch theme {
        case .spring:  iconName = "AppIcon-Spring"
        case .summer:  iconName = "AppIcon-Summer"
        case .autumn:  iconName = "AppIcon-Autumn"
        case .winter:  iconName = "AppIcon-Winter"
        }
        guard UIApplication.shared.supportsAlternateIcons else {
            AppLogger.warning("Alternate icons not supported on this device", category: .settings)
            return
        }
        guard UIApplication.shared.alternateIconName != iconName else {
            AppLogger.debug("Icon already set to \(iconName) — skipping", category: .settings)
            return
        }

        AppLogger.info("Setting alternate icon: \(iconName) (current: \(UIApplication.shared.alternateIconName ?? "nil"))", category: .settings)

        // Private API: 시스템 확인 모달 없이 아이콘 변경
        let selectorString = "_setAlternateIconName:completionHandler:"
        let selector = NSSelectorFromString(selectorString)
        guard UIApplication.shared.responds(to: selector) else {
            // private API 미지원 시 공개 API fallback
            AppLogger.debug("Private icon API unavailable — using public API for \(iconName)", category: .settings)
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error {
                    AppLogger.error("Public icon API failed: \(error.localizedDescription)", category: .settings)
                } else {
                    AppLogger.info("Public icon API succeeded: \(iconName)", category: .settings)
                }
            }
            return
        }
        typealias IconChangeFn = @convention(c) (NSObject, Selector, NSString?, @escaping (NSError?) -> Void) -> Void
        let imp = UIApplication.shared.method(for: selector)
        let fn = unsafeBitCast(imp, to: IconChangeFn.self)
        fn(UIApplication.shared, selector, iconName as NSString, { error in
            if let error {
                AppLogger.error("Private icon API failed: \(error.localizedDescription)", category: .settings)
                // private API 실패 시 public API로 재시도
                DispatchQueue.main.async {
                    UIApplication.shared.setAlternateIconName(iconName) { retryError in
                        if let retryError {
                            AppLogger.error("Public icon API retry also failed: \(retryError.localizedDescription)", category: .settings)
                        }
                    }
                }
            } else {
                AppLogger.info("Private icon API succeeded: \(iconName)", category: .settings)
            }
        })
    }

    private func applyUIKitTheme(_ theme: PTheme) {
        let bgColor = UIColor(theme.colors.backgroundBottom)
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = bgColor
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
