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
