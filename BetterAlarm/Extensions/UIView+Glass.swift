import UIKit

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
    private var blurView: UIVisualEffectView?

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
        backgroundColor = .clear

        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        blurView?.translatesAutoresizingMaskIntoConstraints = false
        if let blurView = blurView {
            addSubview(blurView)
            NSLayoutConstraint.activate([
                blurView.topAnchor.constraint(equalTo: topAnchor),
                blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
                blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
                blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        updateAppearance()
    }

    private func updateAppearance() {
        layer.cornerRadius = cornerRadius
        clipsToBounds = true

        layer.borderWidth = 0.5
        layer.borderColor = UIColor.glassBorder.cgColor

        blurView?.layer.cornerRadius = cornerRadius
        blurView?.clipsToBounds = true
    }
}
