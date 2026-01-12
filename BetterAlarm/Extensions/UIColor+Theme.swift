import UIKit

extension UIColor {
    // MARK: - Fixed Dark Mode Theme

    /// Primary accent color - Soft lavender/purple
    static let accentPrimary = UIColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0)  // Bright lavender

    /// Secondary accent - Soft pink/coral
    static let accentSecondary = UIColor(red: 1.0, green: 0.6, blue: 0.7, alpha: 1.0)  // Soft pink

    /// Gradient start color
    static let gradientStart = UIColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 1.0)  // Deep navy

    /// Gradient middle color
    static let gradientMid = UIColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 1.0)   // Dark purple

    /// Gradient end color
    static let gradientEnd = UIColor(red: 0.1, green: 0.12, blue: 0.2, alpha: 1.0)    // Deep blue-purple

    /// Glass card background
    static let glassBackground = UIColor.white.withAlphaComponent(0.08)

    /// Glass card border
    static let glassBorder = UIColor.white.withAlphaComponent(0.15)

    /// Primary text color
    static let textPrimary = UIColor.white

    /// Secondary text color
    static let textSecondary = UIColor.white.withAlphaComponent(0.7)

    /// Tertiary text color
    static let textTertiary = UIColor.white.withAlphaComponent(0.5)

    /// Enabled alarm indicator
    static let alarmEnabled = UIColor(red: 0.5, green: 0.9, blue: 0.7, alpha: 1.0)

    /// Skip indicator color - warm orange
    static let skipIndicator = UIColor(red: 1.0, green: 0.75, blue: 0.4, alpha: 1.0)

    /// Destructive action color
    static let destructiveAction = UIColor(red: 1.0, green: 0.45, blue: 0.5, alpha: 1.0)

    /// Card shadow color
    static let cardShadow = UIColor.black.withAlphaComponent(0.4)

    /// Selected/highlighted state
    static let selectedBackground = UIColor.white.withAlphaComponent(0.12)

    // MARK: - Gradient Layer

    static func gradientLayer(frame: CGRect) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.frame = frame
        gradient.colors = [
            UIColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 1.0).cgColor,
            UIColor(red: 0.1, green: 0.12, blue: 0.2, alpha: 1.0).cgColor
        ]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        return gradient
    }
}

// MARK: - UIFont Theme Extension

extension UIFont {
    static func alarmTimeFont(size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .light)
    }

    static func alarmTitleFont(size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .medium)
    }

    static func alarmSubtitleFont(size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .regular)
    }
}
