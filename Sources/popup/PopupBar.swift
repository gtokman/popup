import UIKit

public final class PopupBar: UIView {
    public enum WidthMode: Equatable, Sendable {
        case fill
        case fitsContent
    }

    public var preferredHeight: CGFloat = 56 {
        didSet {
            guard preferredHeight != oldValue else { return }
            imageSizeConstraints.forEach { $0.constant = itemSide }
            buttonSizeConstraints.forEach { $0.constant = itemSide }
            updateTextOnlyContentInsets()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
            preferredHeightDidChange?(preferredHeight)
            preferredContentWidthDidChange?(preferredContentWidth)
        }
    }

    public var widthMode: WidthMode = .fill {
        didSet {
            guard widthMode != oldValue else { return }
            updateTextOnlyContentInsets()
            invalidateIntrinsicContentSize()
            widthModeDidChange?(widthMode)
        }
    }

    public var horizontalMargin: CGFloat = 12 {
        didSet {
            horizontalMarginDidChange?(horizontalMargin)
        }
    }
    public var showsImageBackground = true {
        didSet { updateImageBackground() }
    }

    public var marqueeScrollEnabled = true {
        didSet {
            titleLabel.isScrollEnabled = marqueeScrollEnabled
            subtitleLabel.isScrollEnabled = marqueeScrollEnabled
        }
    }

    /// Padding between the capsule edge and the artwork / trailing buttons.
    /// Inner radii are derived from it so every item stays concentric with the bar.
    public static let contentInset: CGFloat = 8

    private var itemSide: CGFloat { max(preferredHeight - Self.contentInset * 2, 0) }
    private var textOnlyFitHorizontalPadding: CGFloat { max(preferredHeight / 2 - 4, 0) }
    var isInlineAccessory = false {
        didSet { updateInlineAccessoryVisibility() }
    }
    var preferredHeightDidChange: ((CGFloat) -> Void)?
    var horizontalMarginDidChange: ((CGFloat) -> Void)?
    var widthModeDidChange: ((WidthMode) -> Void)?
    var preferredContentWidthDidChange: ((CGFloat) -> Void)?

    private var imageSizeConstraints: [NSLayoutConstraint] = []
    private var buttonSizeConstraints: [NSLayoutConstraint] = []

    var preferredContentWidth: CGFloat {
        let hasImage = popupItem?.image != nil
        let buttonCount = popupItem?.barButtonItems.count ?? 0
        let visibleButtonCount = isInlineAccessory ? min(buttonCount, 1) : buttonCount
        let textWidth = max(titleLabel.textContentWidth, isInlineAccessory ? 0 : subtitleLabel.textContentWidth)
        if widthMode == .fitsContent, !hasImage, visibleButtonCount == 0 {
            return ceil(textWidth + textOnlyFitHorizontalPadding * 2)
        }
        let leadingInset = hasImage ? Self.contentInset + itemSide + 10 : 20
        let trailingInset = visibleButtonCount > 0
            ? Self.contentInset * 2 + 8 + CGFloat(visibleButtonCount) * itemSide
            : 20
        return ceil(leadingInset + textWidth + trailingInset)
    }

    public var cornerRadius: CGFloat {
        bounds.height / 2
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(
            width: widthMode == .fitsContent ? preferredContentWidth : UIView.noIntrinsicMetric,
            height: preferredHeight
        )
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

    private let titleLabel = MarqueeLabel()
    private let subtitleLabel = MarqueeLabel()
    let labelsStack = UIStackView()
    private let buttonsStack = UIStackView()
    private var labelsLeadingWithImageConstraint: NSLayoutConstraint?
    private var labelsLeadingWithoutImageConstraint: NSLayoutConstraint?
    private var labelsTrailingWithButtonsConstraint: NSLayoutConstraint?
    private var labelsTrailingWithoutButtonsConstraint: NSLayoutConstraint?

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

    public override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.layer.cornerRadius = cornerRadius
        let concentricRadius = max(cornerRadius - Self.contentInset, 0)
        imageView.layer.cornerRadius = concentricRadius
        buttonsStack.arrangedSubviews.forEach { $0.layer.cornerRadius = concentricRadius }
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
        imageView.layer.cornerRadius = max(cornerRadius - Self.contentInset, 0)
        imageView.layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        titleLabel.font = .systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
            weight: .semibold
        )
        titleLabel.textColor = .label
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .secondaryLabel
        labelsStack.axis = .vertical
        labelsStack.spacing = 2
        labelsStack.addArrangedSubview(titleLabel)
        labelsStack.addArrangedSubview(subtitleLabel)
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(labelsStack)

        buttonsStack.axis = .horizontal
        buttonsStack.alignment = .center
        buttonsStack.spacing = 0
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonsStack)

        contentView.isAccessibilityElement = true
        contentView.accessibilityTraits = .button
        contentView.accessibilityHint = "Opens the popup"
        isAccessibilityElement = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        labelsLeadingWithImageConstraint = labelsStack.leadingAnchor.constraint(
            equalTo: imageView.trailingAnchor,
            constant: 10
        )
        labelsLeadingWithoutImageConstraint = labelsStack.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: 20
        )
        labelsTrailingWithButtonsConstraint = labelsStack.trailingAnchor.constraint(
            equalTo: buttonsStack.leadingAnchor,
            constant: -8
        )
        labelsTrailingWithoutButtonsConstraint = labelsStack.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -20
        )

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.contentInset),
            imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            buttonsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.contentInset),
            buttonsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        imageSizeConstraints = [
            imageView.widthAnchor.constraint(equalToConstant: itemSide),
            imageView.heightAnchor.constraint(equalToConstant: itemSide)
        ]
        NSLayoutConstraint.activate(imageSizeConstraints)

        update(from: nil)
    }

    private func update(from item: PopupItem?) {
        if let attributedTitle = item?.attributedTitle {
            titleLabel.attributedText = attributedTitle
        } else {
            titleLabel.text = item?.title
        }
        subtitleLabel.text = item?.subtitle
        subtitleLabel.isHidden = item?.subtitle == nil
        imageView.image = item?.image
        imageView.isHidden = item?.image == nil
        if let image = item?.image, image.isSymbolImage {
            imageView.contentMode = .center
            imageView.preferredSymbolConfiguration = .init(pointSize: 20, weight: .semibold)
            imageView.tintColor = .label
        } else {
            imageView.contentMode = .scaleAspectFill
            imageView.preferredSymbolConfiguration = nil
            imageView.tintColor = nil
        }
        updateImageBackground()

        let hasImage = item?.image != nil
        labelsLeadingWithImageConstraint?.isActive = hasImage
        labelsLeadingWithoutImageConstraint?.isActive = !hasImage

        contentView.accessibilityLabel = [item?.attributedTitle?.string ?? item?.title, item?.subtitle]
            .compactMap { $0 }
            .joined(separator: ", ")

        buttonsStack.arrangedSubviews.forEach {
            buttonsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        buttonSizeConstraints.removeAll()

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
            button.layer.cornerCurve = .continuous
            button.layer.cornerRadius = max(cornerRadius - Self.contentInset, 0)
            button.translatesAutoresizingMaskIntoConstraints = false
            let sizeConstraints = [
                button.widthAnchor.constraint(equalToConstant: itemSide),
                button.heightAnchor.constraint(equalToConstant: itemSide)
            ]
            buttonSizeConstraints.append(contentsOf: sizeConstraints)
            NSLayoutConstraint.activate(sizeConstraints)
            buttonsStack.addArrangedSubview(button)
        }

        let hasButtons = item?.barButtonItems.isEmpty == false
        labelsTrailingWithButtonsConstraint?.isActive = hasButtons
        labelsTrailingWithoutButtonsConstraint?.isActive = !hasButtons
        buttonsStack.isHidden = !hasButtons
        updateTextOnlyContentInsets()
        updateInlineAccessoryVisibility()
        invalidateIntrinsicContentSize()
        preferredContentWidthDidChange?(preferredContentWidth)
    }

    func setSystemAccessoryStyle(_ enabled: Bool) {
        backgroundView.isHidden = false
        backgroundView.effect = enabled ? nil : Self.backgroundEffect()
        layer.shadowOpacity = enabled ? 0 : 0.12
    }

    private func updateImageBackground() {
        guard showsImageBackground, let image = popupItem?.image, image.isSymbolImage else {
            imageView.backgroundColor = .clear
            return
        }
        imageView.backgroundColor = UIColor.label.withAlphaComponent(0.08)
    }

    private func updateInlineAccessoryVisibility() {
        updateTextOnlyContentInsets()
        subtitleLabel.isHidden = isInlineAccessory || popupItem?.subtitle == nil
        for (index, button) in buttonsStack.arrangedSubviews.enumerated() {
            button.isHidden = isInlineAccessory && index > 0
        }
        invalidateIntrinsicContentSize()
        preferredContentWidthDidChange?(preferredContentWidth)
    }

    private func updateTextOnlyContentInsets() {
        let buttonCount = popupItem?.barButtonItems.count ?? 0
        let visibleButtonCount = isInlineAccessory ? min(buttonCount, 1) : buttonCount
        let usesCompactInsets = widthMode == .fitsContent
            && popupItem?.image == nil
            && visibleButtonCount == 0
        let inset = usesCompactInsets ? textOnlyFitHorizontalPadding : 20
        labelsLeadingWithoutImageConstraint?.constant = inset
        labelsTrailingWithoutButtonsConstraint?.constant = -inset
    }
}
