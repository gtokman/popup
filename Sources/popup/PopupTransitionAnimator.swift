import UIKit

/// Morphs the popup bar into the full content (and back) as a single shared surface.
@MainActor
final class PopupTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    unowned let popupController: PopupController
    let isPresenting: Bool
    private var fallbackDriver: SpringDriver?

    init(popupController: PopupController, isPresenting: Bool) {
        self.popupController = popupController
        self.isPresenting = isPresenting
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        popupController.transitionDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let scene = makeScene(using: transitionContext)
        if !isPresenting {
            scene.beginCloseMorph()
        }
        scene.apply(progress: 0)

        let spring = isPresenting ? popupController.openSpring : popupController.closeSpring
        fallbackDriver = SpringDriver(
            spring: spring,
            from: 0,
            to: 1,
            velocity: 0,
            view: transitionContext.containerView,
            onUpdate: { scene.apply(progress: $0) },
            onComplete: { [weak self] in
                scene.complete(reachedTarget: true)
                transitionContext.completeTransition(true)
                self?.fallbackDriver = nil
            }
        )
    }

    func animationEnded(_ transitionCompleted: Bool) {
        if !transitionCompleted {
            _ = fallbackDriver?.stop()
            fallbackDriver = nil
        }
    }

    func makeScene(using context: UIViewControllerContextTransitioning) -> PopupTransitionScene {
        PopupTransitionScene(
            context: context,
            popupController: popupController,
            isPresenting: isPresenting
        )
    }
}

@MainActor
final class PopupTransitionScene {
    private let isPresenting: Bool
    private weak var popupController: PopupController?

    private var isNoOp = false
    private var isCloseMorphing = false
    private var hasCompleted = false

    private var containerView: UIView?
    private var contentViewController: UIViewController?
    private var contentView: UIView?
    private var presenterView: UIView?
    private var bar: PopupBar?
    private var dimmingView: UIView?
    private var artworkView: UIView?
    private var morphView: UIView?
    private var backdrop: UIVisualEffectView?
    private var barSnapshot: UIImageView?
    private var flyer: UIImageView?

    private var openFrame: CGRect = .zero
    private var barFrame: CGRect = .zero
    private var barArtworkFrame: CGRect = .zero
    private var artworkFrame: CGRect?
    private var openRadius: CGFloat = 0
    private var barRadius: CGFloat = 0
    private var artworkRadius: CGFloat = 0
    private var barArtworkRadius: CGFloat = 0
    private var artworkAlpha: CGFloat = 1
    private var backgroundScale: CGFloat = 1
    private var dimmingAlpha: CGFloat = 0

    private var closeStartFrame: CGRect?
    private var closeStartArtworkFrame: CGRect?
    private var closeStartScale: CGFloat?
    private var closeStartDimming: CGFloat?

    var dragOffset: CGFloat = 0 {
        didSet {
            if !isPresenting && !isCloseMorphing {
                apply(progress: 0)
            }
        }
    }

    var isDragging: Bool {
        !isNoOp && !isPresenting && !isCloseMorphing && !hasCompleted
    }

    var containerHeight: CGFloat {
        max(containerView?.bounds.height ?? 1, 1)
    }

    init(
        context: UIViewControllerContextTransitioning,
        popupController: PopupController,
        isPresenting: Bool
    ) {
        self.isPresenting = isPresenting
        self.popupController = popupController
        let contentKey: UITransitionContextViewControllerKey = isPresenting ? .to : .from
        let presenterKey: UITransitionContextViewControllerKey = isPresenting ? .from : .to
        guard let content = context.viewController(forKey: contentKey),
              let presenterView = context.viewController(forKey: presenterKey)?.view else {
            isNoOp = true
            return
        }

        let container = context.containerView
        let contentView = context.view(forKey: isPresenting ? .to : .from) ?? content.view!
        let presentation = content.presentationController as? PopupPresentationController
        let bar = popupController.bar

        var openFrame = isPresenting ? context.finalFrame(for: content) : context.initialFrame(for: content)
        if openFrame.isEmpty { openFrame = container.bounds }
        let barFrame = bar.convert(bar.bounds, to: container)
        let barArtworkFrame = bar.imageView.convert(bar.imageView.bounds, to: container)
        let openRadius = popupController.resolvedOpenCornerRadius
        let barRadius = barFrame.height / 2
        let backgroundScale = popupController.backgroundScale
        let dimmingAlpha = popupController.dimmingAlpha
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
        let artworkImage: UIImage?
        if let artworkView, let barImage = bar.imageView.image {
            artworkImage = (artworkView as? UIImageView)?.image ?? barImage
        } else {
            artworkImage = nil
        }
        let artworkRadius = artworkView?.layer.cornerRadius ?? 0
        let barArtworkRadius = bar.imageView.layer.cornerRadius
        let flyer: UIImageView?
        if let artworkImage, artworkFrame != nil {
            flyer = UIImageView(image: artworkImage)
        } else {
            flyer = nil
        }
        if flyer != nil { artworkView?.alpha = 0 }

        bar.imageView.isHidden = flyer != nil
        let barRender = UIGraphicsImageRenderer(bounds: bar.contentView.bounds).image { renderer in
            bar.contentView.layer.render(in: renderer.cgContext)
        }
        bar.imageView.isHidden = false
        bar.alpha = 0
        popupController.setBarHiddenForTransition(true)

        let morphView = UIView(frame: openFrame)
        morphView.clipsToBounds = true
        morphView.layer.cornerCurve = .continuous
        let backdrop = UIVisualEffectView(effect: bar.backgroundView.effect)
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let barSnapshot = UIImageView(image: barRender)
        barSnapshot.bounds = CGRect(origin: .zero, size: barFrame.size)
        contentView.autoresizingMask = []
        contentView.frame = CGRect(origin: .zero, size: openFrame.size)
        contentView.alpha = 0
        morphView.addSubview(backdrop)
        morphView.addSubview(contentView)
        contentView.layoutIfNeeded()
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

        self.containerView = container
        contentViewController = content
        self.contentView = contentView
        self.presenterView = presenterView
        self.bar = bar
        dimmingView = presentation?.dimmingView
        self.artworkView = artworkView
        self.morphView = morphView
        self.backdrop = backdrop
        self.barSnapshot = barSnapshot
        self.flyer = flyer
        self.openFrame = openFrame
        self.barFrame = barFrame
        self.barArtworkFrame = barArtworkFrame
        self.artworkFrame = artworkFrame
        self.openRadius = openRadius
        self.barRadius = barRadius
        self.artworkRadius = artworkRadius
        self.barArtworkRadius = barArtworkRadius
        self.artworkAlpha = artworkAlpha
        self.backgroundScale = backgroundScale
        self.dimmingAlpha = dimmingAlpha

        apply(progress: 0)
    }

    func apply(progress: CGFloat) {
        guard !isNoOp, !hasCompleted,
              let morphView,
              let backdrop,
              let contentView,
              let barSnapshot,
              let presenterView else { return }

        UIView.performWithoutAnimation {
            let geometryProgress = PopupGestureMath.softenedOvershoot(progress)
            let frame: CGRect
            let scale: CGFloat
            let dimming: CGFloat
            let cornerRadius: CGFloat
            let flyerFrame: CGRect?
            let flyerRadius: CGFloat
            let presenterCornerRadius: CGFloat

            if !isPresenting && !isCloseMorphing {
                let factor = Self.clamp(dragOffset / containerHeight * 1.5, 0, 1)
                frame = openFrame.offsetBy(dx: 0, dy: dragOffset)
                scale = Self.interpolate(backgroundScale, 1, factor)
                dimming = dimmingAlpha * (1 - factor)
                cornerRadius = openRadius
                flyerFrame = artworkFrame?.offsetBy(dx: 0, dy: dragOffset)
                flyerRadius = artworkRadius
                presenterCornerRadius = openRadius
            } else if isPresenting {
                frame = Self.interpolate(barFrame, openFrame, geometryProgress)
                scale = Self.interpolate(1, backgroundScale, geometryProgress)
                dimming = Self.interpolate(0, dimmingAlpha, progress)
                cornerRadius = max(0, Self.interpolate(barRadius, openRadius, geometryProgress))
                flyerFrame = artworkFrame.map { Self.interpolate(barArtworkFrame, $0, geometryProgress) }
                flyerRadius = max(0, Self.interpolate(barArtworkRadius, artworkRadius, geometryProgress))
                presenterCornerRadius = max(0, Self.interpolate(0, openRadius, geometryProgress))
            } else {
                let startFrame = closeStartFrame ?? openFrame
                let startArtworkFrame = closeStartArtworkFrame ?? artworkFrame
                frame = Self.interpolate(startFrame, barFrame, geometryProgress)
                scale = Self.interpolate(closeStartScale ?? backgroundScale, 1, geometryProgress)
                dimming = Self.interpolate(closeStartDimming ?? dimmingAlpha, 0, progress)
                cornerRadius = max(0, Self.interpolate(openRadius, barRadius, geometryProgress))
                flyerFrame = startArtworkFrame.map { Self.interpolate($0, barArtworkFrame, geometryProgress) }
                flyerRadius = max(0, Self.interpolate(artworkRadius, barArtworkRadius, geometryProgress))
                presenterCornerRadius = max(0, Self.interpolate(openRadius, 0, geometryProgress))
            }

            morphView.frame = frame
            backdrop.frame = morphView.bounds
            morphView.layer.cornerRadius = max(0, cornerRadius)

            let contentScale = openFrame.width == 0 ? 1 : frame.width / openFrame.width
            contentView.transform = CGAffineTransform(scaleX: contentScale, y: contentScale)
            contentView.center = CGPoint(
                x: frame.width / 2,
                y: openFrame.height * contentScale / 2
            )
            barSnapshot.center = CGPoint(x: frame.width / 2, y: barFrame.height / 2)

            if isPresenting {
                barSnapshot.alpha = Self.clamp(1 - progress / 0.2, 0, 1)
                contentView.alpha = Self.clamp(progress / 0.35, 0, 1)
            } else {
                contentView.alpha = Self.clamp(1 - (progress - 0.45) / 0.4, 0, 1)
                barSnapshot.alpha = Self.clamp((progress - 0.6) / 0.3, 0, 1)
            }

            if let flyer, let flyerFrame {
                flyer.frame = flyerFrame
                flyer.layer.cornerRadius = max(0, flyerRadius)
            }

            presenterView.transform = CGAffineTransform(scaleX: scale, y: scale)
            presenterView.layer.cornerRadius = presenterCornerRadius
            dimmingView?.alpha = Self.clamp(dimming, 0, 1)
        }
    }

    func beginCloseMorph() {
        guard !isNoOp, !isPresenting, !hasCompleted else { return }
        let factor = Self.clamp(dragOffset / containerHeight * 1.5, 0, 1)
        closeStartFrame = openFrame.offsetBy(dx: 0, dy: dragOffset)
        closeStartArtworkFrame = artworkFrame?.offsetBy(dx: 0, dy: dragOffset)
        closeStartScale = Self.interpolate(backgroundScale, 1, factor)
        closeStartDimming = dimmingAlpha * (1 - factor)
        isCloseMorphing = true
        apply(progress: 0)
    }

    func closeProgressVelocity(forDragVelocity velocity: CGFloat) -> CGFloat {
        let distance = barFrame.midY - (openFrame.midY + dragOffset)
        guard abs(distance) > 0.001 else { return 0 }
        return velocity / distance
    }

    func complete(reachedTarget: Bool) {
        guard !isNoOp, !hasCompleted,
              let morphView,
              let contentView,
              let containerView,
              let presenterView,
              bar != nil else { return }

        let isOpen = reachedTarget == isPresenting
        if !isPresenting && !reachedTarget {
            isCloseMorphing = false
            closeStartFrame = nil
            closeStartArtworkFrame = nil
            closeStartScale = nil
            closeStartDimming = nil
            dragOffset = 0
        }

        UIView.performWithoutAnimation {
            apply(progress: reachedTarget ? 1 : 0)
            morphView.removeFromSuperview()
            flyer?.removeFromSuperview()
            artworkView?.alpha = artworkAlpha
            contentView.alpha = 1
            if isOpen {
                if contentView.superview !== containerView {
                    if let dimmingView, dimmingView.superview === containerView {
                        containerView.insertSubview(contentView, aboveSubview: dimmingView)
                    } else {
                        containerView.addSubview(contentView)
                    }
                }
                contentView.transform = .identity
                contentView.frame = openFrame
                contentView.layoutIfNeeded()
            } else {
                contentView.removeFromSuperview()
                presenterView.layer.masksToBounds = false
            }
            popupController?.setBarHiddenForTransition(isOpen)
        }
        hasCompleted = true
    }

    private static func interpolate(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    private static func interpolate(_ from: CGRect, _ to: CGRect, _ progress: CGFloat) -> CGRect {
        CGRect(
            x: interpolate(from.minX, to.minX, progress),
            y: interpolate(from.minY, to.minY, progress),
            width: interpolate(from.width, to.width, progress),
            height: interpolate(from.height, to.height, progress)
        )
    }

    private static func clamp(_ value: CGFloat, _ lowerBound: CGFloat, _ upperBound: CGFloat) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }
}
