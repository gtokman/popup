import QuartzCore
import UIKit

public struct PopupSpring: Equatable, Sendable {
    public var response: CGFloat
    public var dampingRatio: CGFloat

    public init(response: CGFloat, dampingRatio: CGFloat) {
        self.response = response
        self.dampingRatio = dampingRatio
    }

    public static let open = PopupSpring(response: 0.5, dampingRatio: 0.9)
    public static let close = PopupSpring(response: 0.55, dampingRatio: 0.72)
    public static let settle = PopupSpring(response: 0.4, dampingRatio: 1.0)
}

@MainActor
final class SpringDriver {
    private let target: CGFloat
    private let stiffness: CGFloat
    private let damping: CGFloat
    private let onUpdate: (CGFloat) -> Void
    private let onComplete: () -> Void
    private var updateLink: UIUpdateLink?
    private var lastTime: TimeInterval?

    private(set) var value: CGFloat
    private(set) var velocity: CGFloat
    private(set) var isRunning = true

    init(
        spring: PopupSpring,
        from: CGFloat,
        to: CGFloat,
        velocity: CGFloat,
        view: UIView,
        onUpdate: @escaping (CGFloat) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.value = from
        self.target = to
        self.velocity = velocity
        self.onUpdate = onUpdate
        self.onComplete = onComplete

        let response = max(spring.response, 0.001)
        let angularFrequency = 2 * CGFloat.pi / response
        stiffness = angularFrequency * angularFrequency
        damping = 4 * CGFloat.pi * spring.dampingRatio / response

        let updateLink = UIUpdateLink(view: view)
        updateLink.addAction(to: .beforeCATransactionCommit) { [weak self] _, info in
            self?.tick(now: info.modelTime)
        }
        updateLink.requiresContinuousUpdates = true
        updateLink.wantsLowLatencyEventDispatch = false
        updateLink.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        self.updateLink = updateLink
        updateLink.isEnabled = true
    }

    @discardableResult
    func step(_ dt: TimeInterval) -> (value: CGFloat, velocity: CGFloat) {
        guard isRunning, dt.isFinite, dt > 0 else { return (value, velocity) }

        let substepCount = max(Int(ceil(dt / 0.001)), 1)
        let substep = CGFloat(dt / Double(substepCount))
        for _ in 0..<substepCount {
            let acceleration = -stiffness * (value - target) - damping * velocity
            velocity += acceleration * substep
            value += velocity * substep
        }

        if abs(value - target) < 0.0005, abs(velocity) < 0.01 {
            complete()
        } else {
            onUpdate(value)
        }
        return (value, velocity)
    }

    func stop() -> (value: CGFloat, velocity: CGFloat) {
        invalidate()
        return (value, velocity)
    }

    func tick(now: TimeInterval) {
        let dt: TimeInterval
        if let lastTime {
            dt = now - lastTime
        } else {
            dt = 1.0 / 120.0
        }
        self.lastTime = now
        step(min(dt, 1.0 / 30.0))
    }

    private func complete() {
        value = target
        velocity = 0
        onUpdate(target)
        invalidate()
        onComplete()
    }

    private func invalidate() {
        guard isRunning else { return }
        isRunning = false
        updateLink?.isEnabled = false
        updateLink = nil
    }
}
