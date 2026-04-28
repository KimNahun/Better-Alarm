import Foundation
import PersonalColorDesignSystem
import UIKit

// MARK: - AppThemeManager

/// 앱 테마(PTheme) 관리자.
/// **단순화됨**: 사용자 색상 선택 기능을 제거하고 항상 `PTheme.summer`로 고정.
/// 클래스 자체와 `currentTheme` 프로퍼티는 ViewModel/View 호환을 위해 유지한다.
@MainActor
@Observable
final class AppThemeManager {
    /// 항상 Summer 테마.
    let currentTheme: PTheme = .summer

    init() {
        applyUIKitTheme(currentTheme)
        AppLogger.info("Theme fixed to summer (color picker removed)", category: .settings)
    }

    /// 현재 테마의 표시 이름. (호출부 호환을 위해 유지)
    var currentThemeDisplayName: String {
        currentTheme.displayName
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
