import UIKit

/// Drives a popup transition from a pan gesture or its release spring.
@MainActor
final class PopupInteractionController: NSObject, UIViewControllerInteractiveTransitioning {
    let isPresenting: Bool
    let wantsInteractiveStart: Bool
    weak var animator: PopupTransitionAnimator?

    private weak var context: UIViewControllerContextTransitioning?
    private var scene: PopupTransitionScene?
    private var springDriver: SpringDriver?
    private var springPurpose: SpringPurpose?
    private var pendingUpdate: PendingUpdate?
    private var pendingFinish: PendingFinish?
    private var hasSignaledFinish = false
    private var hasEnded = false
    private var currentProgress: CGFloat = 0
    private var contextProgressOrigin: CGFloat = 0
    private var contextProgressRange: CGFloat = 1

    init(isPresenting: Bool, wantsInteractiveStart: Bool) {
        self.isPresenting = isPresenting
        self.wantsInteractiveStart = wantsInteractiveStart
    }

    /// True from the moment the transition is requested until UIKit settles it.
    var isActive: Bool { !hasEnded }
    var isDragging: Bool { scene?.isDragging ?? (!isPresenting && wantsInteractiveStart) }
    var dragOffset: CGFloat { scene?.dragOffset ?? 0 }
    var containerHeight: CGFloat { scene?.containerHeight ?? context?.containerView.bounds.height ?? 1 }

    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        guard let animator else {
            transitionContext.completeTransition(false)
            hasEnded = true
            return
        }
        context = transitionContext
        let scene = animator.makeScene(using: transitionContext)
        self.scene = scene
        scene.apply(progress: 0)

        if !wantsInteractiveStart {
            if !isPresenting {
                scene.beginCloseMorph()
            }
            finish(complete: true, velocity: 0)
            return
        }

        if let pendingUpdate {
            switch pendingUpdate {
            case let .progress(progress):
                update(progress)
            case let .drag(offset):
                updateDrag(offset: offset)
            }
        }
        if let pendingFinish {
            switch pendingFinish {
            case let .progress(complete, velocity):
                finish(complete: complete, velocity: velocity)
            case let .drag(complete, velocity):
                finishDrag(complete: complete, velocity: velocity)
            }
        }
        pendingUpdate = nil
        pendingFinish = nil
    }

    /// Freezes the transition wherever it is and returns its progress toward the target state.
    func pause() -> CGFloat {
        guard let context else { return Self.clamp(currentProgress, 0, 1) }
        if let springDriver, springDriver.isRunning {
            switch springPurpose {
            case .progress:
                currentProgress = springDriver.stop().value
            case .dragOffset:
                let stopped = springDriver.stop()
                scene?.dragOffset = stopped.value
                currentProgress = stopped.value / (scene?.containerHeight ?? 1)
                context.updateInteractiveTransition(Self.clamp(currentProgress, 0, 1))
            case nil:
                _ = springDriver.stop()
            }
            self.springDriver = nil
            springPurpose = nil
            if hasSignaledFinish {
                context.pauseInteractiveTransition()
                hasSignaledFinish = false
            }
        }
        return Self.clamp(currentProgress, 0, 1)
    }

    func update(_ progress: CGFloat) {
        guard !hasEnded else { return }
        guard let context, let scene else {
            pendingUpdate = .progress(progress)
            return
        }
        currentProgress = progress
        scene.apply(progress: progress)
        context.updateInteractiveTransition(contextProgress(for: progress))
    }

    func updateDrag(offset: CGFloat) {
        guard !hasEnded else { return }
        guard let context, let scene else {
            pendingUpdate = .drag(offset)
            return
        }
        scene.dragOffset = offset
        currentProgress = offset / scene.containerHeight
        context.updateInteractiveTransition(Self.clamp(currentProgress, 0, 1))
    }

    /// Releases the gesture and settles a progress-driven transition.
    /// - Parameter velocity: progress per second toward the gesture's target direction.
    func finish(complete: Bool, velocity: CGFloat) {
        guard !hasEnded else { return }
        guard let context, let scene else {
            pendingFinish = .progress(complete: complete, velocity: velocity)
            return
        }
        if complete {
            context.finishInteractiveTransition()
        } else {
            context.cancelInteractiveTransition()
        }
        hasSignaledFinish = true

        let spring: PopupSpring
        if complete {
            spring = isPresenting ? animator?.popupController.openSpring ?? .open
                : animator?.popupController.closeSpring ?? .close
        } else {
            spring = animator?.popupController.settleSpring ?? .settle
        }
        runProgressSpring(
            spring: spring,
            from: currentProgress,
            to: complete ? 1 : 0,
            velocity: velocity,
            complete: complete,
            context: context,
            scene: scene
        )
    }

    /// Releases a downward card drag, preserving the full-size card until completion is chosen.
    /// - Parameter velocity: vertical finger velocity in points per second.
    func finishDrag(complete: Bool, velocity: CGFloat) {
        guard !hasEnded else { return }
        guard let context, let scene else {
            pendingFinish = .drag(complete: complete, velocity: velocity)
            return
        }
        if complete {
            context.finishInteractiveTransition()
        } else {
            context.cancelInteractiveTransition()
        }
        hasSignaledFinish = true

        if complete {
            let progressVelocity = scene.closeProgressVelocity(forDragVelocity: velocity)
            let origin = Self.clamp(scene.dragOffset / scene.containerHeight, 0, 1)
            contextProgressOrigin = origin
            contextProgressRange = 1 - origin
            scene.beginCloseMorph()
            currentProgress = 0
            runProgressSpring(
                spring: animator?.popupController.closeSpring ?? .close,
                from: 0,
                to: 1,
                velocity: progressVelocity,
                complete: true,
                context: context,
                scene: scene
            )
        } else {
            contextProgressOrigin = 0
            contextProgressRange = 1
            currentProgress = scene.dragOffset / scene.containerHeight
            springPurpose = .dragOffset
            springDriver = SpringDriver(
                spring: animator?.popupController.settleSpring ?? .settle,
                from: scene.dragOffset,
                to: 0,
                velocity: velocity,
                view: context.containerView,
                onUpdate: { [weak self, weak scene] offset in
                    guard let self, let scene else { return }
                    scene.dragOffset = offset
                    self.currentProgress = offset / scene.containerHeight
                    context.updateInteractiveTransition(Self.clamp(self.currentProgress, 0, 1))
                },
                onComplete: { [weak self, weak scene] in
                    guard let self, let scene else { return }
                    self.completeTransition(reachedTarget: false, context: context, scene: scene)
                }
            )
        }
    }

    private func runProgressSpring(
        spring: PopupSpring,
        from: CGFloat,
        to: CGFloat,
        velocity: CGFloat,
        complete: Bool,
        context: UIViewControllerContextTransitioning,
        scene: PopupTransitionScene
    ) {
        springPurpose = .progress
        springDriver = SpringDriver(
            spring: spring,
            from: from,
            to: to,
            velocity: velocity,
            view: context.containerView,
            onUpdate: { [weak self, weak scene] progress in
                guard let self, let scene else { return }
                self.currentProgress = progress
                scene.apply(progress: progress)
                context.updateInteractiveTransition(self.contextProgress(for: progress))
            },
            onComplete: { [weak self, weak scene] in
                guard let self, let scene else { return }
                self.completeTransition(reachedTarget: complete, context: context, scene: scene)
            }
        )
    }

    private func completeTransition(
        reachedTarget: Bool,
        context: UIViewControllerContextTransitioning,
        scene: PopupTransitionScene
    ) {
        scene.complete(reachedTarget: reachedTarget)
        context.completeTransition(reachedTarget)
        springDriver = nil
        springPurpose = nil
        hasSignaledFinish = false
        hasEnded = true
    }

    private func contextProgress(for progress: CGFloat) -> CGFloat {
        Self.clamp(contextProgressOrigin + progress * contextProgressRange, 0, 1)
    }

    private static func clamp(_ value: CGFloat, _ lowerBound: CGFloat, _ upperBound: CGFloat) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }

    private enum SpringPurpose {
        case progress
        case dragOffset
    }

    private enum PendingUpdate {
        case progress(CGFloat)
        case drag(CGFloat)
    }

    private enum PendingFinish {
        case progress(complete: Bool, velocity: CGFloat)
        case drag(complete: Bool, velocity: CGFloat)
    }
}

/// Release heuristics and drag resistance shared by popup gestures.
enum PopupGestureMath {
    static let projectionTime: CGFloat = 0.2
    static let flickThreshold: CGFloat = 1.0

    static func shouldComplete(fraction: CGFloat, velocity: CGFloat) -> Bool {
        if abs(velocity) > flickThreshold {
            return velocity > 0
        }
        return fraction + velocity * projectionTime > 0.5
    }

    static func rubberBandedOffset(translation: CGFloat, height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        guard translation < 0 else { return translation }
        let normalizedDistance = abs(translation) * 0.55 / height
        return -(1 - 1 / (normalizedDistance + 1)) * height
    }
}
