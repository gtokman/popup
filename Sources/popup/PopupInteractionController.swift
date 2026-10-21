import UIKit

/// Drives a `PopupTransitionAnimator`'s interruptible animator from a pan gesture.
///
/// Vended for every popup transition: when `wantsInteractiveStart` is false the animation
/// starts on its own and the user can still grab it mid-flight, scrub it, and fling it either way.
@MainActor
final class PopupInteractionController: NSObject, UIViewControllerInteractiveTransitioning {
    let isPresenting: Bool
    let wantsInteractiveStart: Bool
    weak var animator: PopupTransitionAnimator?

    private weak var context: UIViewControllerContextTransitioning?
    private var propertyAnimator: UIViewPropertyAnimator?
    private var pendingFraction: CGFloat?
    private var pendingFinish: (complete: Bool, velocity: CGFloat, dampingRatio: CGFloat)?
    private var hasEnded = false

    init(isPresenting: Bool, wantsInteractiveStart: Bool) {
        self.isPresenting = isPresenting
        self.wantsInteractiveStart = wantsInteractiveStart
    }

    /// True from the moment the transition is requested until UIKit settles it.
    var isActive: Bool { !hasEnded }

    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        guard let animator else {
            transitionContext.completeTransition(false)
            return
        }
        context = transitionContext
        let propertyAnimator = animator.propertyAnimator(using: transitionContext)
        propertyAnimator.addCompletion { [weak self] _ in self?.hasEnded = true }
        self.propertyAnimator = propertyAnimator

        guard wantsInteractiveStart else {
            propertyAnimator.startAnimation()
            return
        }
        propertyAnimator.pauseAnimation()
        if let pendingFraction { update(pendingFraction) }
        if let pendingFinish { finish(complete: pendingFinish.complete, velocity: pendingFinish.velocity, dampingRatio: pendingFinish.dampingRatio) }
        pendingFraction = nil
        pendingFinish = nil
    }

    /// Freezes the transition wherever it is and returns its progress toward the target state.
    func pause() -> CGFloat {
        guard let context, let propertyAnimator else { return pendingFraction ?? 0 }
        if propertyAnimator.state == .active, propertyAnimator.isRunning {
            context.pauseInteractiveTransition()
            propertyAnimator.pauseAnimation()
        }
        if propertyAnimator.isReversed {
            propertyAnimator.isReversed = false
        }
        return propertyAnimator.fractionComplete
    }

    func update(_ fraction: CGFloat) {
        guard let context, let propertyAnimator else {
            pendingFraction = fraction
            return
        }
        propertyAnimator.fractionComplete = fraction
        context.updateInteractiveTransition(fraction)
    }

    /// Releases the gesture: settles toward open or closed with a spring seeded by the finger's velocity.
    /// - Parameter velocity: progress per second toward the target state.
    func finish(complete: Bool, velocity: CGFloat, dampingRatio: CGFloat) {
        guard let context, let propertyAnimator else {
            pendingFinish = (complete, velocity, dampingRatio)
            return
        }
        let fraction = propertyAnimator.fractionComplete
        if complete {
            context.finishInteractiveTransition()
        } else {
            context.cancelInteractiveTransition()
        }
        propertyAnimator.isReversed = !complete
        let initialVelocity = PopupGestureMath.relativeInitialVelocity(fraction: fraction, velocity: velocity, complete: complete)
        let timing = UISpringTimingParameters(dampingRatio: dampingRatio, initialVelocity: CGVector(dx: initialVelocity, dy: initialVelocity))
        propertyAnimator.continueAnimation(withTimingParameters: timing, durationFactor: 0)
    }
}

/// Release heuristics shared by every popup gesture.
enum PopupGestureMath {
    /// How far ahead (seconds) a release velocity is projected when picking the final state.
    static let projectionTime: CGFloat = 0.2
    /// Velocities (progress/second) above this always win, regardless of position.
    static let flickThreshold: CGFloat = 1.0

    static func shouldComplete(fraction: CGFloat, velocity: CGFloat) -> Bool {
        if abs(velocity) > flickThreshold {
            return velocity > 0
        }
        return fraction + velocity * projectionTime > 0.5
    }

    /// The spring's initial velocity, expressed relative to the remaining distance as UIKit expects.
    static func relativeInitialVelocity(fraction: CGFloat, velocity: CGFloat, complete: Bool) -> CGFloat {
        let remaining = complete ? 1 - fraction : fraction
        guard remaining > 0.001 else { return 0 }
        let towardTarget = complete ? velocity : -velocity
        return min(max(towardTarget / remaining, -10), 30)
    }
}
