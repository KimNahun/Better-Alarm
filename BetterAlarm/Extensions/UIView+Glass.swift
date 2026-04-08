import UIKit

// ⚠️ DEPRECATED: 이 파일은 UIKit 레거시 코드입니다.
// SwiftUI 뷰에서는 PersonalColorDesignSystem의 GlassCard, HapticManager 등을 사용하세요.
// 신규 코드에서 이 파일의 클래스/메서드를 참조하지 마세요.

extension UIView {
    // MARK: - Glass Effect

    func applyGlassEffect(cornerRadius: CGFloat = 20) {
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = false

        layer.borderWidth = 0.5
        layer.borderColor = UIColor.glassBorder.cgColor

        layer.shadowColor = UIColor.cardShadow.cgColor
        layer.shadowOpacity = 1.0
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        clipsToBounds = false
    }

    // MARK: - Gradient Background

    @discardableResult
    func addGradientBackground() -> CAGradientLayer {
        let gradient = UIColor.gradientLayer(frame: bounds)
        gradient.name = "backgroundGradient"
        layer.insertSublayer(gradient, at: 0)
        return gradient
    }

    // MARK: - Haptic Feedback

    static func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// MARK: - Glass Card View

class GlassCardView: UIView {
    var cornerRadius: CGFloat = 20 {
        didSet { updateAppearance() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        // Use solid semi-transparent background for better scroll performance
        backgroundColor = UIColor(red: 0.15, green: 0.13, blue: 0.22, alpha: 0.9)
        updateAppearance()
    }

    private func updateAppearance() {
        layer.cornerRadius = cornerRadius
        clipsToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.glassBorder.cgColor
    }
}
