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
    item.attributedTitle = NSAttributedString(string: "Attributed title")
    item.subtitle = "Subtitle"
    item.image = UIImage(systemName: "music.note")
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
func popupGeometryRestingFrameIgnoresPresenterScale() {
    let root = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
    let presenter = UIView(frame: CGRect(x: 20, y: 30, width: 300, height: 700))
    root.addSubview(presenter)
    let bar = UIView(frame: CGRect(x: 15, y: 620, width: 270, height: 56))
    presenter.addSubview(bar)

    presenter.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)

    let restingFrame = PopupGeometry.restingFrame(of: bar, in: presenter)
    let liveFrame = bar.convert(bar.bounds, to: root)
    #expect(abs(restingFrame.minX - 35) < 0.001)
    #expect(abs(restingFrame.minY - 650) < 0.001)
    #expect(restingFrame.size == bar.bounds.size)
    #expect(liveFrame != restingFrame)
}

@Test @MainActor
func popupBarWithoutArtworkOrButtonsKeepsTitleInset() {
    let bar = PopupBar(frame: CGRect(x: 0, y: 0, width: 300, height: 56))
    bar.popupItem = PopupItem(title: "Title", subtitle: "Subtitle")
    bar.layoutIfNeeded()

    #expect(bar.imageView.isHidden)
    #expect(bar.labelsStack.frame.minX >= 16)
}

@Test @MainActor
func popupBarCentersSymbolArtwork() {
    let bar = PopupBar(frame: CGRect(x: 0, y: 0, width: 300, height: 56))
    bar.popupItem = PopupItem(image: UIImage(systemName: "doc.on.doc"))
    bar.layoutIfNeeded()

    #expect(bar.imageView.contentMode == .center)
}

@Test @MainActor
func preferredHeightDrivesConcentricArtworkRadius() {
    let bar = PopupBar(frame: CGRect(x: 0, y: 0, width: 300, height: 56))
    bar.preferredHeight = 46
    bar.frame.size.height = bar.preferredHeight
    bar.layoutIfNeeded()

    #expect(bar.intrinsicContentSize.height == 46)
    #expect(bar.imageView.layer.cornerRadius == 15)
}

@Test @MainActor
func fittedPopupBarUsesAttributedTitleWidth() {
    let item = PopupItem(title: "Short")
    item.attributedTitle = NSAttributedString(string: "2 files changed +6 −9")
    let bar = PopupBar()
    bar.popupItem = item
    bar.widthMode = .fitsContent

    #expect(bar.intrinsicContentSize.width > 40)
    #expect(bar.intrinsicContentSize.width < 300)
}

@Test @MainActor
func popupBarAccessoryStyleKeepsContentVisible() {
    let bar = PopupBar()
    bar.setSystemAccessoryStyle(true)

    #expect(!bar.backgroundView.isHidden)
    #expect(bar.backgroundView.effect == nil)
}

@Test @MainActor
func popupBarInlineAccessoryFitsVisibleControls() {
    let bar = PopupBar()
    let item = PopupItem()
    item.image = UIImage(systemName: "music.note")
    item.title = "Velvet Skies"
    item.subtitle = "The Paper Moons"
    item.barButtonItems = [
        UIBarButtonItem(image: UIImage(systemName: "pause.fill"), style: .plain, target: nil, action: nil),
        UIBarButtonItem(image: UIImage(systemName: "forward.fill"), style: .plain, target: nil, action: nil)
    ]
    bar.popupItem = item

    let regularWidth = bar.preferredContentWidth
    bar.isInlineAccessory = true

    #expect(bar.preferredContentWidth < regularWidth)
}

@Test @MainActor
func popupBarFitsTextOnlyContentWithCapsulePadding() {
    let bar = PopupBar()
    bar.preferredHeight = 35
    bar.widthMode = .fitsContent
    let item = PopupItem()
    item.attributedTitle = NSAttributedString(
        string: "2 files changed +6 −9",
        attributes: [.font: UIFont.systemFont(ofSize: 15, weight: .semibold)]
    )
    bar.popupItem = item

    let label = UILabel()
    label.attributedText = item.attributedTitle
    let textWidth = label.sizeThatFits(
        CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    ).width
    let horizontalPadding = bar.preferredHeight / 2 - 4

    #expect(bar.preferredContentWidth == ceil(textWidth + horizontalPadding * 2))
}

@Test @MainActor
func popupBarCanDockAboveNavigationToolbar() {
    let navigationController = UINavigationController(rootViewController: UIViewController())
    navigationController.setToolbarHidden(false, animated: false)
    navigationController.loadViewIfNeeded()
    navigationController.presentPopupBar(with: UIViewController(), animated: false)

    #expect(navigationController.popupBar.superview === navigationController.view)
}

@Test @MainActor
func popupBarDocksAboveTabBarWithoutOverlapping() {
    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [UIViewController()]
    tabBarController.popupController.usesTabBarAccessory = false
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    window.rootViewController = tabBarController
    window.isHidden = false
    tabBarController.presentPopupBar(with: UIViewController(), animated: false)
    tabBarController.view.layoutIfNeeded()

    let bar = tabBarController.popupBar
    let barFrame = bar.convert(bar.bounds, to: tabBarController.view)
    let tabBarFrame = tabBarController.tabBar.convert(tabBarController.tabBar.bounds, to: tabBarController.view)

    #expect(barFrame.maxY == tabBarFrame.minY - tabBarController.popupController.barSpacing)
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
        view: UIView(),
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
        view: UIView(),
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
            view: UIView(),
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
        view: UIView(),
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
func largeSpringTickDeltaIsClamped() {
    let driver = SpringDriver(
        spring: .close,
        from: 0,
        to: 1,
        velocity: 0,
        view: UIView(),
        onUpdate: { _ in },
        onComplete: {}
    )
    driver.tick(now: 10)
    driver.tick(now: 10_000)

    #expect(driver.value.isFinite)
    #expect(driver.velocity.isFinite)
    #expect(driver.value <= 2)

    driver.stop()
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

@Test
func softenedOvershootIsIdentityMonotonicAndBounded() {
    let inRange = stride(from: CGFloat(0), through: 1, by: 0.1).map {
        PopupGestureMath.softenedOvershoot($0)
    }
    #expect(inRange == stride(from: CGFloat(0), through: 1, by: 0.1).map { $0 })

    let inputs: [CGFloat] = [-50, -10, -1, 0, 0.5, 1, 2, 10, 50]
    let outputs = inputs.map { PopupGestureMath.softenedOvershoot($0) }
    #expect(zip(outputs, outputs.dropFirst()).allSatisfy { $0 <= $1 })
    #expect(outputs.first! >= -0.03)
    #expect(outputs.last! <= 1.03)
}
