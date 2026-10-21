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
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?

    private(set) var value: CGFloat
    private(set) var velocity: CGFloat
    private(set) var isRunning = true

    init(
        spring: PopupSpring,
        from: CGFloat,
        to: CGFloat,
        velocity: CGFloat,
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

        let proxy = SpringDisplayLinkProxy()
        proxy.driver = self
        let displayLink = CADisplayLink(target: proxy, selector: #selector(SpringDisplayLinkProxy.tick(_:)))
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        self.displayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
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

    fileprivate func displayLinkDidFire(_ displayLink: CADisplayLink) {
        let dt: TimeInterval
        if let lastTimestamp {
            dt = displayLink.targetTimestamp - lastTimestamp
        } else {
            dt = displayLink.duration
        }
        lastTimestamp = displayLink.targetTimestamp
        step(dt)
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
        displayLink?.invalidate()
        displayLink = nil
    }
}

@MainActor
private final class SpringDisplayLinkProxy: NSObject {
    weak var driver: SpringDriver?

    @objc func tick(_ displayLink: CADisplayLink) {
        guard let driver else {
            displayLink.invalidate()
            return
        }
        driver.displayLinkDidFire(displayLink)
    }
}
