import UIKit

public final class PopupBar: UIView {
    public static let height: CGFloat = 56

    public var horizontalMargin: CGFloat = 12

    public var cornerRadius: CGFloat {
        bounds.height / 2
    }

    public var popupItem: PopupItem? {
        didSet {
            oldValue?.removeObserver(self)
            popupItem?.addObserver(self) { [weak self] item in
                self?.update(from: item)
            }
            update(from: popupItem)
        }
    }

    public let backgroundView: UIVisualEffectView
    public let contentView = UIView()
    public let imageView = UIImageView()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let labelsStack = UIStackView()
    private let buttonsStack = UIStackView()
    private let progressView = UIProgressView(progressViewStyle: .default)

    public override init(frame: CGRect) {
        backgroundView = UIVisualEffectView(effect: Self.backgroundEffect())
        super.init(frame: frame)
        configureView()
    }

    public required init?(coder: NSCoder) {
        backgroundView = UIVisualEffectView(effect: Self.backgroundEffect())
        super.init(coder: coder)
        configureView()
    }

    deinit {
        popupItem?.removeObserver(self)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.layer.cornerRadius = cornerRadius
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    private static func backgroundEffect() -> UIVisualEffect {
        if #available(iOS 26, *) {
            return UIGlassEffect()
        }
        return UIBlurEffect(style: .systemChromeMaterial)
    }

    private func configureView() {
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.layer.cornerRadius = cornerRadius
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentView.addSubview(contentView)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        titleLabel.font = .systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
            weight: .semibold
        )
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 1
        labelsStack.axis = .vertical
        labelsStack.spacing = 1
        labelsStack.addArrangedSubview(titleLabel)
        labelsStack.addArrangedSubview(subtitleLabel)
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(labelsStack)

        buttonsStack.axis = .horizontal
        buttonsStack.alignment = .center
        buttonsStack.spacing = 2
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonsStack)

        progressView.progressTintColor = UIColor.label.withAlphaComponent(0.6)
        progressView.trackTintColor = .clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressView)

        contentView.isAccessibilityElement = true
        contentView.accessibilityTraits = .button
        contentView.accessibilityHint = "Opens the player"
        isAccessibilityElement = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 40),
            imageView.heightAnchor.constraint(equalToConstant: 40),
            labelsStack.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            labelsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            buttonsStack.leadingAnchor.constraint(greaterThanOrEqualTo: labelsStack.trailingAnchor, constant: 8),
            buttonsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            buttonsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -1),
            labelsStack.trailingAnchor.constraint(lessThanOrEqualTo: buttonsStack.leadingAnchor, constant: -8),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            progressView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    private func update(from item: PopupItem?) {
        titleLabel.text = item?.title
        subtitleLabel.text = item?.subtitle
        imageView.image = item?.image
        progressView.progress = item?.progress ?? 0
        contentView.accessibilityLabel = [item?.title, item?.subtitle]
            .compactMap { $0 }
            .joined(separator: ", ")

        buttonsStack.arrangedSubviews.forEach {
            buttonsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        item?.barButtonItems.forEach { barButtonItem in
            let button: UIButton
            if let primaryAction = barButtonItem.primaryAction {
                button = UIButton(type: .system, primaryAction: primaryAction)
                button.setImage(barButtonItem.image, for: .normal)
            } else {
                button = UIButton(type: .system)
                button.setImage(barButtonItem.image, for: .normal)
                if let action = barButtonItem.action {
                    button.addTarget(barButtonItem.target, action: action, for: .touchUpInside)
                }
            }
            button.tintColor = .label
            button.contentHorizontalAlignment = .center
            button.imageView?.contentMode = .scaleAspectFit
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 36),
                button.heightAnchor.constraint(equalToConstant: 36)
            ])
            buttonsStack.addArrangedSubview(button)
        }
    }
}
