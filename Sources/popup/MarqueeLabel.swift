import UIKit

final class MarqueeLabel: UIView {
    var text: String? {
        get { label.text }
        set {
            label.text = newValue
            trailingCopy.text = newValue
            invalidateContentSize()
        }
    }

    var attributedText: NSAttributedString? {
        get { label.attributedText }
        set {
            label.attributedText = newValue
            trailingCopy.attributedText = newValue
            invalidateContentSize()
        }
    }

    var textContentWidth: CGFloat {
        label.sizeThatFits(
            CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        ).width
    }

    var font: UIFont {
        get { label.font }
        set {
            label.font = newValue
            trailingCopy.font = newValue
            invalidateContentSize()
        }
    }

    var textColor: UIColor {
        get { label.textColor }
        set {
            label.textColor = newValue
            trailingCopy.textColor = newValue
        }
    }

    var isScrollEnabled = true {
        didSet { setNeedsLayout() }
    }

    var scrollSpeed: CGFloat = 30 {
        didSet { setNeedsLayout() }
    }

    var pauseDuration: TimeInterval = 2 {
        didSet { setNeedsLayout() }
    }

    var gap: CGFloat = 32 {
        didSet { setNeedsLayout() }
    }

    var fadeLength: CGFloat = 10 {
        didSet { setNeedsLayout() }
    }

    private(set) var isScrolling = false

    private let scroller = UIView()
    private let label = UILabel()
    private let trailingCopy = UILabel()
    private var notificationTokens: [NSObjectProtocol] = []
    private var lastAppliedConfiguration: AppliedConfiguration?

    private static let scrollAnimationKey = "MarqueeLabel.scroll"

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: label.intrinsicContentSize.height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let measuredSize = label.sizeThatFits(
            CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        let textWidth = measuredSize.width
        let needsScroll = isScrollEnabled
            && !UIAccessibility.isReduceMotionEnabled
            && textWidth > bounds.width

        if needsScroll {
            scroller.frame = CGRect(
                x: 0,
                y: 0,
                width: textWidth * 2 + gap,
                height: bounds.height
            )
            label.frame = CGRect(x: 0, y: 0, width: textWidth, height: bounds.height)
            label.lineBreakMode = .byClipping
            trailingCopy.frame = CGRect(
                x: textWidth + gap,
                y: 0,
                width: textWidth,
                height: bounds.height
            )
            trailingCopy.lineBreakMode = .byClipping
            trailingCopy.isHidden = false
            updateFadeMask()
        } else {
            scroller.frame = bounds
            label.frame = bounds
            label.lineBreakMode = .byTruncatingTail
            trailingCopy.isHidden = true
        }

        let configuration = AppliedConfiguration(
            text: text,
            font: font,
            width: bounds.width,
            needsScroll: needsScroll,
            scrollSpeed: scrollSpeed,
            pauseDuration: pauseDuration,
            gap: gap
        )
        guard configuration != lastAppliedConfiguration else { return }
        lastAppliedConfiguration = configuration

        if needsScroll {
            startScrolling(textWidth: textWidth)
        } else {
            stopScrolling()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        lastAppliedConfiguration = nil
        if window == nil {
            stopScrolling()
        } else {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    private func configureView() {
        clipsToBounds = true
        isAccessibilityElement = false
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        scroller.isUserInteractionEnabled = false
        addSubview(scroller)

        for textLabel in [label, trailingCopy] {
            textLabel.numberOfLines = 1
            textLabel.lineBreakMode = .byTruncatingTail
            textLabel.isAccessibilityElement = false
            scroller.addSubview(textLabel)
        }
        trailingCopy.isHidden = true

        observeEnvironmentChanges()
    }

    private func invalidateContentSize() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func observeEnvironmentChanges() {
        let center = NotificationCenter.default
        let names = [
            UIApplication.willEnterForegroundNotification,
            UIAccessibility.reduceMotionStatusDidChangeNotification
        ]
        notificationTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshForEnvironmentChange()
                }
            }
        }
    }

    private func refreshForEnvironmentChange() {
        lastAppliedConfiguration = nil
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func updateFadeMask() {
        guard bounds.width > 0 else {
            layer.mask = nil
            return
        }

        let mask = (layer.mask as? CAGradientLayer) ?? CAGradientLayer()
        let fadeRatio = min(max(fadeLength, 0), bounds.width / 2) / bounds.width
        mask.frame = bounds
        mask.startPoint = CGPoint(x: 0, y: 0.5)
        mask.endPoint = CGPoint(x: 1, y: 0.5)
        mask.colors = [
            UIColor.clear.cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor
        ]
        mask.locations = [
            0,
            NSNumber(value: Double(fadeRatio)),
            NSNumber(value: Double(1 - fadeRatio)),
            1
        ]
        layer.mask = mask
    }

    private func startScrolling(textWidth: CGFloat) {
        isScrolling = true
        scroller.layer.removeAnimation(forKey: Self.scrollAnimationKey)

        let travel = textWidth + gap
        let delay = max(pauseDuration, 0)
        let travelDuration = TimeInterval(max(travel, .leastNonzeroMagnitude) / max(scrollSpeed, 0.01))
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -travel
        animation.beginTime = delay
        animation.duration = travelDuration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)

        let group = CAAnimationGroup()
        group.animations = [animation]
        group.duration = delay + travelDuration
        group.repeatCount = .infinity
        group.isRemovedOnCompletion = false
        scroller.layer.add(group, forKey: Self.scrollAnimationKey)
    }

    private func stopScrolling() {
        isScrolling = false
        trailingCopy.isHidden = true
        scroller.layer.removeAnimation(forKey: Self.scrollAnimationKey)
        scroller.layer.transform = CATransform3DIdentity
        layer.mask = nil
    }

    private struct AppliedConfiguration: Equatable {
        let text: String?
        let font: UIFont
        let width: CGFloat
        let needsScroll: Bool
        let scrollSpeed: CGFloat
        let pauseDuration: TimeInterval
        let gap: CGFloat

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.text == rhs.text
                && lhs.font.isEqual(rhs.font)
                && lhs.width == rhs.width
                && lhs.needsScroll == rhs.needsScroll
                && lhs.scrollSpeed == rhs.scrollSpeed
                && lhs.pauseDuration == rhs.pauseDuration
                && lhs.gap == rhs.gap
        }
    }
}
