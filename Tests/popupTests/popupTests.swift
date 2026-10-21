import UIKit
import Testing
@testable import popup

private final class ObserverOwner {}

@Test @MainActor
func observerReceivesEveryPropertyChange() {
    let item = PopupItem()
    let owner = ObserverOwner()
    var notifications = 0
    item.addObserver(owner) { _ in notifications += 1 }

    item.title = "Title"
    item.subtitle = "Subtitle"
    item.image = UIImage(systemName: "music.note")
    item.progress = 0.5
    item.barButtonItems = [UIBarButtonItem(image: UIImage(systemName: "play.fill"), style: .plain, target: nil, action: nil)]

    #expect(notifications == 5)
}

@Test @MainActor
func removingObserverStopsNotifications() {
    let item = PopupItem()
    let owner = ObserverOwner()
    var notifications = 0
    item.addObserver(owner) { _ in notifications += 1 }
    item.removeObserver(owner)

    item.title = "Title"

    #expect(notifications == 0)
}

@Test @MainActor
func viewControllerPopupItemIsStable() {
    let viewController = UIViewController()

    #expect(viewController.popupItem === viewController.popupItem)
}

@Test @MainActor
func marqueeScrollsOnlyWhenEnabledAndTextOverflows() {
    let marqueeLabel = MarqueeLabel(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
    marqueeLabel.text = "Hi"
    marqueeLabel.layoutIfNeeded()

    #expect(marqueeLabel.isScrolling == false)

    marqueeLabel.text = "Somewhere Between the Static and the Sea (Extended Mix)"
    marqueeLabel.layoutIfNeeded()

    #expect(marqueeLabel.isScrolling == true)

    marqueeLabel.isScrollEnabled = false
    marqueeLabel.layoutIfNeeded()

    #expect(marqueeLabel.isScrolling == false)
}

@Test @MainActor
func closeSpringOvershootsAndSettlesAtTarget() {
    var maximumValue: CGFloat = 0
    var didComplete = false
    let driver = SpringDriver(
        spring: .close,
        from: 0,
        to: 1,
        velocity: 0,
        onUpdate: { maximumValue = max(maximumValue, $0) },
        onComplete: { didComplete = true }
    )

    for _ in 0..<2400 {
        guard driver.isRunning else { break }
        driver.step(1.0 / 120.0)
    }

    #expect(maximumValue > 1)
    #expect(didComplete)
    #expect(driver.value == 1)
}

@Test @MainActor
func settleSpringDoesNotOvershoot() {
    var maximumValue: CGFloat = 0
    let driver = SpringDriver(
        spring: .settle,
        from: 0,
        to: 1,
        velocity: 0,
        onUpdate: { maximumValue = max(maximumValue, $0) },
        onComplete: {}
    )

    for _ in 0..<2400 {
        guard driver.isRunning else { break }
        driver.step(1.0 / 120.0)
    }

    #expect(maximumValue <= 1.0001)
    #expect(driver.value == 1)
}

@Test @MainActor
func initialVelocityTowardTargetReachesMidpointSooner() {
    func stepsToMidpoint(initialVelocity: CGFloat) -> Int {
        let driver = SpringDriver(
            spring: .open,
            from: 0,
            to: 1,
            velocity: initialVelocity,
            onUpdate: { _ in },
            onComplete: {}
        )
        for step in 1...1200 {
            driver.step(1.0 / 120.0)
            if driver.value >= 0.5 {
                driver.stop()
                return step
            }
        }
        driver.stop()
        return Int.max
    }

    #expect(stepsToMidpoint(initialVelocity: 5) < stepsToMidpoint(initialVelocity: 0))
}

@Test @MainActor
func stoppingSpringReturnsStateWithoutCompleting() {
    var didComplete = false
    let driver = SpringDriver(
        spring: .close,
        from: 0,
        to: 1,
        velocity: 0,
        onUpdate: { _ in },
        onComplete: { didComplete = true }
    )
    driver.step(1.0 / 120.0)

    let stopped = driver.stop()

    #expect(stopped.value == driver.value)
    #expect(stopped.velocity == driver.velocity)
    #expect(didComplete == false)
}

@Test @MainActor
func upwardDragRubberBandIsMonotonicAndBounded() {
    let height: CGFloat = 800
    let offsets = [CGFloat(0), -40, -160, -320, -1_280].map {
        PopupGestureMath.rubberBandedOffset(translation: $0, height: height)
    }

    #expect(offsets[0] == 0)
    #expect(zip(offsets, offsets.dropFirst()).allSatisfy { $0 > $1 })
    #expect(offsets.allSatisfy { $0 >= -height && $0 <= 0 })
}
