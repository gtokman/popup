import UIKit

/// Morphs the popup bar into the full content (and back) as a single shared surface.
///
/// Scene built inside the transition container:
/// - a morph view whose frame and corner radius travel between the bar's capsule and the full screen,
///   backed by the bar's own material, holding a scaled snapshot of the content and a render of the
///   bar's labels/buttons that cross-fade as it grows;
/// - the artwork, flying between the bar's thumbnail and the content's `popupArtworkView`;
/// - the container scaling back behind a dimming layer.
///
/// Everything is driven by one `UIViewPropertyAnimator`, returned from
/// `interruptibleAnimator(using:)`, so the same animation can be scrubbed, paused and reversed.
@MainActor
final class PopupTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    unowned let popupController: PopupController
    let isPresenting: Bool
    private var animator: UIViewPropertyAnimator?

    init(popupController: PopupController, isPresenting: Bool) {
        self.popupController = popupController
        self.isPresenting = isPresenting
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        popupController.transitionDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        propertyAnimator(using: transitionContext).startAnimation()
    }

    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        propertyAnimator(using: transitionContext)
    }

    func animationEnded(_ transitionCompleted: Bool) {
        animator = nil
    }

    func propertyAnimator(using context: UIViewControllerContextTransitioning) -> UIViewPropertyAnimator {
        if let animator { return animator }
        let animator = makeAnimator(using: context)
        self.animator = animator
        return animator
    }

    // MARK: - Scene

    private func makeAnimator(using context: UIViewControllerContextTransitioning) -> UIViewPropertyAnimator {
        let timing = UISpringTimingParameters(dampingRatio: popupController.dampingRatio)
        let animator = UIViewPropertyAnimator(duration: popupController.transitionDuration, timingParameters: timing)

        let contentKey: UITransitionContextViewControllerKey = isPresenting ? .to : .from
        let presenterKey: UITransitionContextViewControllerKey = isPresenting ? .from : .to
        guard let content = context.viewController(forKey: contentKey),
              let presenterView = context.viewController(forKey: presenterKey)?.view else {
            animator.addCompletion { _ in context.completeTransition(!context.transitionWasCancelled) }
            return animator
        }

        let container = context.containerView
        let contentView = context.view(forKey: isPresenting ? .to : .from) ?? content.view!
        let presentation = content.presentationController as? PopupPresentationController
        let controller = popupController
        let bar = controller.bar

        var openFrame = isPresenting ? context.finalFrame(for: content) : context.initialFrame(for: content)
        if openFrame.isEmpty { openFrame = container.bounds }
        let barFrame = container.convert(PopupGeometry.restingFrame(of: bar, in: presenterView), from: presenterView.superview)
        let barArtworkFrame = container.convert(PopupGeometry.restingFrame(of: bar.imageView, in: presenterView), from: presenterView.superview)
        let openRadius = controller.resolvedOpenCornerRadius
        let barRadius = barFrame.height / 2
        let backgroundScale = controller.backgroundScale
        let dimmingAlpha = controller.dimmingAlpha
        let isPresenting = isPresenting

        // Lay the real content out at its final size so the snapshot and artwork target are exact.
        let artworkView = (content as? PopupContentTransitioning)?.popupArtworkView
        let artworkAlpha = artworkView?.alpha ?? 1
        UIView.performWithoutAnimation {
            if contentView.superview !== container {
                if let dimming = presentation?.dimmingView, dimming.superview === container {
                    container.insertSubview(contentView, aboveSubview: dimming)
                } else {
                    container.addSubview(contentView)
                }
            }
            contentView.transform = .identity
            contentView.alpha = 1
            contentView.frame = openFrame
            contentView.layoutIfNeeded()
        }
        let artworkFrame = artworkView.map { container.convert($0.bounds, from: $0) }
        let artworkImage = (artworkView as? UIImageView)?.image ?? bar.imageView.image
        let artworkRadius = artworkView?.layer.cornerRadius ?? 0
        let barArtworkRadius = bar.imageView.layer.cornerRadius
        let flyer: UIImageView? = (artworkImage != nil && artworkFrame != nil) ? UIImageView(image: artworkImage) : nil
        if flyer != nil { artworkView?.alpha = 0 }

        let contentSnapshot = contentView.snapshotView(afterScreenUpdates: true) ?? UIView()
        contentView.alpha = 0

        bar.imageView.isHidden = flyer != nil
        let barRender = UIGraphicsImageRenderer(bounds: bar.contentView.bounds).image { renderer in
            bar.contentView.layer.render(in: renderer.cgContext)
        }
        bar.imageView.isHidden = false
        bar.alpha = 0

        let morphView = UIView()
        morphView.clipsToBounds = true
        morphView.layer.cornerCurve = .continuous
        let backdrop = UIVisualEffectView(effect: bar.backgroundView.effect)
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let barSnapshot = UIImageView(image: barRender)
        barSnapshot.bounds = CGRect(origin: .zero, size: barFrame.size)
        contentSnapshot.autoresizingMask = []
        contentSnapshot.bounds = CGRect(origin: .zero, size: openFrame.size)
        morphView.addSubview(backdrop)
        morphView.addSubview(contentSnapshot)
        morphView.addSubview(barSnapshot)
        container.addSubview(morphView)

        if let flyer {
            flyer.contentMode = (artworkView as? UIImageView)?.contentMode ?? bar.imageView.contentMode
            flyer.clipsToBounds = true
            flyer.layer.cornerCurve = .continuous
            container.addSubview(flyer)
        }

        if let window = presenterView.window, window.backgroundColor == nil || window.backgroundColor == .clear {
            window.backgroundColor = .black
        }
        presenterView.layer.cornerCurve = .continuous
        presenterView.layer.masksToBounds = true

        func apply(open: Bool) {
            let frame = open ? openFrame : barFrame
            morphView.frame = frame
            backdrop.frame = morphView.bounds
            morphView.layer.cornerRadius = open ? openRadius : barRadius
            let scale = frame.width / openFrame.width
            contentSnapshot.transform = CGAffineTransform(scaleX: scale, y: scale)
            contentSnapshot.center = CGPoint(x: frame.width / 2, y: openFrame.height * scale / 2)
            barSnapshot.center = CGPoint(x: frame.width / 2, y: barFrame.height / 2)
            if let flyer, let artworkFrame {
                flyer.frame = open ? artworkFrame : barArtworkFrame
                flyer.layer.cornerRadius = open ? artworkRadius : barArtworkRadius
            }
            presentation?.dimmingView.alpha = open ? dimmingAlpha : 0
            presenterView.transform = open ? CGAffineTransform(scaleX: backgroundScale, y: backgroundScale) : .identity
            presenterView.layer.cornerRadius = open ? openRadius : 0
        }

        UIView.performWithoutAnimation {
            apply(open: !isPresenting)
            contentSnapshot.alpha = isPresenting ? 0 : 1
            barSnapshot.alpha = isPresenting ? 1 : 0
        }

        animator.addAnimations {
            apply(open: isPresenting)
        }
        animator.addAnimations {
            UIView.animateKeyframes(withDuration: 0, delay: 0, options: [.calculationModeLinear]) {
                if isPresenting {
                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2) { barSnapshot.alpha = 0 }
                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.35) { contentSnapshot.alpha = 1 }
                } else {
                    UIView.addKeyframe(withRelativeStartTime: 0.45, relativeDuration: 0.4) { contentSnapshot.alpha = 0 }
                    UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.3) { barSnapshot.alpha = 1 }
                }
            }
        }
        animator.addCompletion { position in
            let isOpen = (position == .end) == isPresenting
            UIView.performWithoutAnimation {
                apply(open: isOpen)
                morphView.removeFromSuperview()
                flyer?.removeFromSuperview()
                artworkView?.alpha = artworkAlpha
                contentView.alpha = 1
                if isOpen {
                    contentView.frame = openFrame
                } else {
                    contentView.removeFromSuperview()
                    presenterView.layer.masksToBounds = false
                }
                bar.alpha = isOpen ? 0 : 1
            }
            context.completeTransition(!context.transitionWasCancelled)
        }
        return animator
    }
}
