import UIKit

/// Hosts a popup bar inside a container controller and drives the bar ⇄ content transition.
///
/// Opening is a real custom modal presentation: the content controller is presented with
/// `modalPresentationStyle = .custom`, a `PopupPresentationController`, a
/// `UIViewControllerAnimatedTransitioning` scene animator, and a
/// `UIViewControllerInteractiveTransitioning` spring driver.
/// One pan gesture can start, scrub, interrupt and reverse the transition at any point.
@MainActor
public final class PopupController: NSObject {
    public enum State: Equatable {
        case hidden
        case barPresented
        case transitioning
        case open
    }

    public let bar = PopupBar()
    public private(set) var state: State = .hidden
    public private(set) var contentViewController: UIViewController?

    /// Settling duration of the spring used for taps and gesture releases.
    public var transitionDuration: TimeInterval = 0.55
    public var openSpring: PopupSpring = .open
    public var closeSpring: PopupSpring = .close
    public var settleSpring: PopupSpring = .settle
    /// Scale applied to the container while the popup is open.
    public var backgroundScale: CGFloat = 0.94
    public var dimmingAlpha: CGFloat = 0.25
    /// Corner radius of the content when fully open. Defaults to the display's corner radius.
    public var openCornerRadius: CGFloat?
    public weak var dockingAnchorView: UIView? {
        didSet {
            if dockingAnchorView !== oldValue, state != .hidden {
                reinstallBar()
            }
        }
    }
    public var barSpacing: CGFloat = 6 {
        didSet {
            barBottomConstraint?.constant -= barSpacing - oldValue
            if state != .hidden { updateContentInsets(visible: true) }
        }
    }
    public var usesTabBarAccessory = false {
        didSet {
            if usesTabBarAccessory != oldValue, state != .hidden {
                reinstallBar()
            }
        }
    }

    weak var containerViewController: UIViewController?
    var interaction: PopupInteractionController?

    private var gestureStartFraction: CGFloat = 0
    private var gestureStartDragOffset: CGFloat = 0
    private var trackedScrollViews = NSHashTable<UIScrollView>.weakObjects()
    private var barBottomConstraint: NSLayoutConstraint?
    private var barLeadingConstraint: NSLayoutConstraint?
    private var barTrailingConstraint: NSLayoutConstraint?
    private var barCenterXConstraint: NSLayoutConstraint?
    private var barWidthConstraint: NSLayoutConstraint?
    private var barMaximumWidthConstraint: NSLayoutConstraint?
    private var barAccessoryWidthConstraint: NSLayoutConstraint?
    private var barAccessoryFitWidthConstraint: NSLayoutConstraint?
    private var barHeightConstraint: NSLayoutConstraint?
    private var accessoryTransitionContainer: UIView?
    private var isUsingTabBarAccessory = false
    private var pendingCompletion: (() -> Void)?

    private(set) lazy var barPanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gesture.delegate = self
        return gesture
    }()

    private(set) lazy var barTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBarTap))

    /// Installed on the presentation container: drags the open content closed and grabs in-flight transitions.
    private(set) lazy var contentPanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gesture.delegate = self
        return gesture
    }()

    init(containerViewController: UIViewController) {
        self.containerViewController = containerViewController
        super.init()
        if #available(iOS 26.0, *), containerViewController is UITabBarController {
            usesTabBarAccessory = true
        }
        bar.preferredHeightDidChange = { [weak self] height in
            self?.barHeightConstraint?.constant = height
            if self?.state != .hidden { self?.updateContentInsets(visible: true) }
        }
        bar.horizontalMarginDidChange = { [weak self] margin in
            self?.barLeadingConstraint?.constant = margin
            self?.barTrailingConstraint?.constant = -margin
            self?.barMaximumWidthConstraint?.constant = -2 * margin
            self?.barAccessoryWidthConstraint?.constant = -2 * margin
        }
        bar.widthModeDidChange = { [weak self] _ in self?.updateBarWidthConstraints() }
        bar.preferredContentWidthDidChange = { [weak self] width in
            self?.barWidthConstraint?.constant = width
            self?.barAccessoryFitWidthConstraint?.constant = width
        }
        if #available(iOS 26.0, *), containerViewController is UITabBarController {
            bar.registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) { [weak self] (bar: PopupBar, _) in
                bar.isInlineAccessory = bar.traitCollection.tabAccessoryEnvironment == .inline
                self?.updateBarWidthConstraints()
            }
        }
        bar.addGestureRecognizer(barTapGesture)
        bar.addGestureRecognizer(barPanGesture)
    }

    // MARK: - Bar

    func presentBar(with content: UIViewController, animated: Bool, completion: (() -> Void)?) {
        guard let container = containerViewController else { return }
        if let current = contentViewController, current !== content {
            if state == .open || state == .transitioning {
                current.dismiss(animated: false)
                state = .barPresented
                bar.alpha = 1
            }
            current.popupContainer = nil
        }
        contentViewController = content
        content.popupContainer = container
        bar.popupItem = content.popupItem

        guard bar.superview == nil else {
            completion?()
            return
        }
        installBar(in: container)
        state = .barPresented
        container.view.layoutIfNeeded()

        guard animated else {
            updateContentInsets(visible: true)
            completion?()
            return
        }
        let offscreen = container.view.bounds.maxY - bar.frame.minY
        bar.transform = CGAffineTransform(translationX: 0, y: offscreen)
        let animator = UIViewPropertyAnimator(duration: 0.5, dampingRatio: 0.85) {
            self.bar.transform = .identity
            self.updateContentInsets(visible: true)
            container.view.layoutIfNeeded()
        }
        animator.addCompletion { _ in completion?() }
        animator.startAnimation()
    }

    func dismissBar(animated: Bool, completion: (() -> Void)?) {
        guard state != .hidden, let container = containerViewController else {
            completion?()
            return
        }
        if state != .barPresented {
            close(animated: false) { [weak self] in self?.dismissBar(animated: animated, completion: completion) }
            return
        }
        let finish = {
            self.removeInstalledBar()
            self.bar.removeFromSuperview()
            self.bar.transform = .identity
            self.contentViewController?.popupContainer = nil
            self.contentViewController = nil
            self.bar.popupItem = nil
            self.state = .hidden
            completion?()
        }
        guard animated else {
            updateContentInsets(visible: false)
            finish()
            return
        }
        let offscreen = container.view.bounds.maxY - bar.frame.minY
        let animator = UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) {
            self.bar.transform = CGAffineTransform(translationX: 0, y: offscreen)
            self.updateContentInsets(visible: false)
            container.view.layoutIfNeeded()
        }
        animator.addCompletion { _ in finish() }
        animator.startAnimation()
    }

    private func installBar(in container: UIViewController) {
        bar.translatesAutoresizingMaskIntoConstraints = false
        let view = container.view!
        view.layoutIfNeeded()
        if #available(iOS 26.0, *),
           let tabBarController = container as? UITabBarController,
           usesTabBarAccessory {
            isUsingTabBarAccessory = true
            bar.setSystemAccessoryStyle(true)
            tabBarController.setBottomAccessory(UITabAccessory(contentView: bar), animated: true)
            barAccessoryWidthConstraint = bar.widthAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.widthAnchor,
                constant: -2 * bar.horizontalMargin
            )
            barAccessoryWidthConstraint?.priority = .defaultHigh
            barAccessoryFitWidthConstraint = bar.widthAnchor.constraint(equalToConstant: bar.preferredContentWidth)
            barAccessoryFitWidthConstraint?.priority = .required
            bar.isInlineAccessory = tabBarController.traitCollection.tabAccessoryEnvironment == .inline
            updateBarWidthConstraints()
            return
        }
        isUsingTabBarAccessory = false
        bar.setSystemAccessoryStyle(false)
        let bottom: NSLayoutConstraint
        if let anchor = dockingAnchorView, let parent = anchor.superview {
            parent.insertSubview(bar, belowSubview: anchor)
            bottom = bar.bottomAnchor.constraint(equalTo: anchor.topAnchor, constant: -barSpacing)
        } else if let navigationController = container as? UINavigationController, !navigationController.isToolbarHidden {
            let toolbar = navigationController.toolbar
            view.addSubview(bar)
            let toolbarClearance: CGFloat
            if let toolbar, toolbar.window === view.window {
                let toolbarFrame = toolbar.convert(toolbar.bounds, to: view)
                toolbarClearance = max(view.safeAreaLayoutGuide.layoutFrame.maxY - toolbarFrame.minY, 0)
            } else {
                toolbarClearance = 44
            }
            bottom = bar.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -toolbarClearance - barSpacing
            )
        } else {
            view.addSubview(bar)
            bottom = bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -barSpacing)
        }
        barBottomConstraint = bottom
        barLeadingConstraint = bar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: bar.horizontalMargin)
        barTrailingConstraint = bar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -bar.horizontalMargin)
        barCenterXConstraint = bar.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor)
        barWidthConstraint = bar.widthAnchor.constraint(equalToConstant: bar.preferredContentWidth)
        barWidthConstraint?.priority = .defaultHigh
        barMaximumWidthConstraint = bar.widthAnchor.constraint(
            lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor,
            constant: -2 * bar.horizontalMargin
        )
        barHeightConstraint = bar.heightAnchor.constraint(equalToConstant: bar.preferredHeight)
        NSLayoutConstraint.activate([
            barHeightConstraint!,
            bottom,
        ])
        updateBarWidthConstraints()
    }

    private var barInset: CGFloat {
        bar.preferredHeight + barSpacing * (dockingAnchorView == nil ? 2 : 1)
    }

    private func reinstallBar() {
        guard state != .hidden, let container = containerViewController else { return }
        removeInstalledBar()
        bar.removeFromSuperview()
        installBar(in: container)
        container.view.layoutIfNeeded()
    }

    private func updateBarWidthConstraints() {
        if isUsingTabBarAccessory {
            let usesFitWidth = bar.widthMode == .fitsContent || bar.isInlineAccessory
            barAccessoryWidthConstraint?.isActive = !usesFitWidth
            barAccessoryFitWidthConstraint?.constant = bar.preferredContentWidth
            barAccessoryFitWidthConstraint?.isActive = usesFitWidth
            return
        }
        guard barWidthConstraint != nil else { return }
        let fitsContent = bar.widthMode == .fitsContent
        barLeadingConstraint?.isActive = !fitsContent
        barTrailingConstraint?.isActive = !fitsContent
        barCenterXConstraint?.isActive = fitsContent
        barWidthConstraint?.constant = bar.preferredContentWidth
        barWidthConstraint?.isActive = fitsContent
        barMaximumWidthConstraint?.constant = -2 * bar.horizontalMargin
        barMaximumWidthConstraint?.isActive = fitsContent
    }

    private func removeInstalledBar() {
        if #available(iOS 26.0, *),
           isUsingTabBarAccessory,
           let tabBarController = containerViewController as? UITabBarController {
            tabBarController.setBottomAccessory(nil, animated: false)
        }
        isUsingTabBarAccessory = false
        accessoryTransitionContainer?.isHidden = false
        accessoryTransitionContainer = nil
        bar.setSystemAccessoryStyle(false)
        bar.isInlineAccessory = false
        [barBottomConstraint, barLeadingConstraint, barTrailingConstraint, barCenterXConstraint,
         barWidthConstraint, barMaximumWidthConstraint, barHeightConstraint]
            .forEach { $0?.isActive = false }
        barBottomConstraint = nil
        barLeadingConstraint = nil
        barTrailingConstraint = nil
        barCenterXConstraint = nil
        barWidthConstraint = nil
        barMaximumWidthConstraint = nil
        barAccessoryWidthConstraint?.isActive = false
        barAccessoryWidthConstraint = nil
        barAccessoryFitWidthConstraint?.isActive = false
        barAccessoryFitWidthConstraint = nil
        barHeightConstraint = nil
    }

    func setBarHiddenForTransition(_ hidden: Bool) {
        guard isUsingTabBarAccessory, let root = containerViewController?.view else {
            bar.alpha = hidden ? 0 : 1
            return
        }
        if hidden {
            var ancestor: UIView = bar
            while let parent = ancestor.superview, parent !== root {
                ancestor = parent
            }
            if ancestor.superview === root {
                accessoryTransitionContainer = ancestor
                ancestor.isHidden = true
            } else {
                bar.alpha = 0
            }
        } else {
            accessoryTransitionContainer?.isHidden = false
            accessoryTransitionContainer = nil
            bar.alpha = 1
        }
    }

    /// Keeps scrollable content clear of the bar by insetting the container's children.
    private func updateContentInsets(visible: Bool) {
        guard let container = containerViewController else { return }
        if isUsingTabBarAccessory { return }
        let inset = visible ? barInset : 0
        let docksOnBottomBar = container is UITabBarController || (container as? UINavigationController)?.isToolbarHidden == false
        if docksOnBottomBar || !container.children.isEmpty {
            for child in container.children {
                child.additionalSafeAreaInsets.bottom = inset
            }
        } else {
            container.additionalSafeAreaInsets.bottom = inset
            // The guide moved up by `inset`; keep the bar on the original safe-area bottom.
            barBottomConstraint?.constant = inset - barSpacing
        }
    }

    // MARK: - Open / close

    func open(animated: Bool, completion: (() -> Void)?) {
        beginOpen(animated: animated, interactive: false, completion: completion)
    }

    func close(animated: Bool, completion: (() -> Void)?) {
        guard state == .open else {
            completion?()
            return
        }
        beginClose(animated: animated, interactive: false, completion: completion)
    }

    @discardableResult
    private func beginOpen(animated: Bool, interactive: Bool, completion: (() -> Void)?) -> Bool {
        guard state == .barPresented, let container = containerViewController, let content = contentViewController,
              container.presentedViewController == nil else { return false }
        content.modalPresentationStyle = .custom
        content.transitioningDelegate = self
        content.modalPresentationCapturesStatusBarAppearance = true
        interaction = PopupInteractionController(isPresenting: true, wantsInteractiveStart: interactive)
        state = .transitioning
        pendingCompletion = completion
        container.present(content, animated: animated)
        return true
    }

    @discardableResult
    private func beginClose(animated: Bool, interactive: Bool, completion: (() -> Void)?) -> Bool {
        guard state == .open, let content = contentViewController else { return false }
        interaction = PopupInteractionController(isPresenting: false, wantsInteractiveStart: interactive)
        state = .transitioning
        pendingCompletion = completion
        content.dismiss(animated: animated)
        return true
    }

    /// Called by the presentation controller once UIKit settles the transition.
    func transitionDidEnd(isOpen: Bool) {
        state = isOpen ? .open : .barPresented
        setBarHiddenForTransition(isOpen)
        interaction = nil
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?()
    }

    // MARK: - Geometry

    var resolvedOpenCornerRadius: CGFloat {
        if let openCornerRadius { return openCornerRadius }
        let screen = bar.window?.screen ?? containerViewController?.view.window?.screen
        return screen?.popupDisplayCornerRadius ?? 0
    }

    /// The vertical distance the content's top edge travels between closed and open.
    var transitionTravel: CGFloat {
        guard let presenter = containerViewController?.view else { return 1 }
        return max(PopupGeometry.restingFrame(of: bar, in: presenter).minY, 1)
    }

    // MARK: - Gestures

    @objc private func handleBarTap() {
        if let interaction, interaction.isActive {
            return
        }
        open(animated: true, completion: nil)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let space = gesture.view?.window ?? gesture.view
        switch gesture.state {
        case .began:
            if let interaction, interaction.isActive {
                gestureStartFraction = interaction.pause()
                if interaction.isDragging {
                    gestureStartDragOffset = interaction.dragOffset
                }
            } else if gesture === barPanGesture, beginOpen(animated: true, interactive: true, completion: nil) {
                gestureStartFraction = 0
                gestureStartDragOffset = 0
            } else if gesture === contentPanGesture, state == .open {
                cancelTrackedScrolling()
                beginClose(animated: true, interactive: true, completion: nil)
                gestureStartFraction = 0
                gestureStartDragOffset = 0
            } else {
                gesture.isEnabled = false
                gesture.isEnabled = true
            }
        case .changed:
            guard let interaction else { return }
            if !interaction.isPresenting, interaction.isDragging {
                let offset = PopupGestureMath.rubberBandedOffset(
                    translation: gestureStartDragOffset + gesture.translation(in: space).y,
                    height: interaction.containerHeight
                )
                interaction.updateDrag(offset: offset)
                return
            }
            let delta = progressDelta(gesture.translation(in: space).y, presenting: interaction.isPresenting)
            interaction.update(min(max(gestureStartFraction + delta, 0), 1))
        case .ended, .cancelled, .failed:
            guard let interaction else { return }
            if !interaction.isPresenting, interaction.isDragging {
                let offset = PopupGestureMath.rubberBandedOffset(
                    translation: gestureStartDragOffset + gesture.translation(in: space).y,
                    height: interaction.containerHeight
                )
                let fraction = offset / transitionTravel
                let velocity = gesture.velocity(in: space).y / transitionTravel
                interaction.finishDrag(
                    complete: PopupGestureMath.shouldComplete(fraction: fraction, velocity: velocity),
                    velocity: gesture.velocity(in: space).y
                )
                return
            }
            let velocity = progressDelta(gesture.velocity(in: space).y, presenting: interaction.isPresenting)
            let fraction = min(max(gestureStartFraction + progressDelta(gesture.translation(in: space).y, presenting: interaction.isPresenting), 0), 1)
            let complete = gesture.state == .ended
                ? PopupGestureMath.shouldComplete(fraction: fraction, velocity: velocity)
                : fraction > 0.5
            interaction.finish(complete: complete, velocity: velocity)
        default:
            break
        }
    }

    /// Converts a vertical distance into transition progress; upward advances an open, downward advances a close.
    private func progressDelta(_ dy: CGFloat, presenting: Bool) -> CGFloat {
        (presenting ? -dy : dy) / transitionTravel
    }

    private func cancelTrackedScrolling() {
        for scrollView in trackedScrollViews.allObjects {
            scrollView.panGestureRecognizer.isEnabled = false
            scrollView.panGestureRecognizer.isEnabled = true
        }
        trackedScrollViews.removeAllObjects()
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension PopupController: UIViewControllerTransitioningDelegate {
    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        PopupPresentationController(presentedViewController: presented, presenting: presenting, popupController: self)
    }

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PopupTransitionAnimator(popupController: self, isPresenting: true)
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PopupTransitionAnimator(popupController: self, isPresenting: false)
    }

    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        attachInteraction(to: animator)
    }

    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        attachInteraction(to: animator)
    }

    /// Always vend the driver, even for taps, so UIKit allows the transition to be interrupted mid-flight.
    private func attachInteraction(to animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        guard let interaction, let animator = animator as? PopupTransitionAnimator else { return nil }
        interaction.animator = animator
        return interaction
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PopupController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        if let interaction, interaction.isActive {
            return true
        }
        let velocity = pan.velocity(in: pan.view)
        guard abs(velocity.y) > abs(velocity.x) else { return false }
        if pan === barPanGesture {
            return state == .barPresented && velocity.y < 0
        }
        guard pan === contentPanGesture, state == .open, velocity.y > 0, let contentView = contentViewController?.view else {
            return false
        }
        let location = pan.location(in: contentView)
        guard let hitView = contentView.hitTest(location, with: nil) else { return true }
        var view: UIView? = hitView
        while let current = view, current !== contentView.superview {
            if current is UISlider || current is UISwitch { return false }
            if let scrollView = current as? UIScrollView, scrollView.isScrollEnabled, scrollView.popupScrollsVertically,
               scrollView.contentOffset.y > -scrollView.adjustedContentInset.top + 0.5 {
                return false
            }
            view = current.superview
        }
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === contentPanGesture, let scrollView = otherGestureRecognizer.view as? UIScrollView,
              otherGestureRecognizer === scrollView.panGestureRecognizer else { return false }
        trackedScrollViews.add(scrollView)
        return true
    }
}

private extension UIScrollView {
    var popupScrollsVertically: Bool {
        alwaysBounceVertical || contentSize.height + adjustedContentInset.top + adjustedContentInset.bottom > bounds.height
    }
}

extension UIScreen {
    /// The physical corner radius of the display, or 0 when unavailable.
    var popupDisplayCornerRadius: CGFloat {
        let key = "_displayCornerRadius"
        guard responds(to: NSSelectorFromString(key)) else { return 0 }
        return (value(forKey: key) as? CGFloat) ?? 0
    }
}

@MainActor
enum PopupGeometry {
    /// The frame `view` occupies in `presenter`'s untransformed window space, ignoring any
    /// scale applied to the presenter while the popup is open.
    static func restingFrame(of view: UIView, in presenter: UIView) -> CGRect {
        let local = view.convert(view.bounds, to: presenter)
        let origin = CGPoint(x: presenter.center.x - presenter.bounds.width / 2, y: presenter.center.y - presenter.bounds.height / 2)
        return local.offsetBy(dx: origin.x - presenter.bounds.minX, dy: origin.y - presenter.bounds.minY)
    }
}
