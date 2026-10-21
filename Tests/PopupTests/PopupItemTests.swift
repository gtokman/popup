import UIKit
import XCTest
@testable import Popup

final class PopupItemTests: XCTestCase {
    private final class ObserverOwner {}

    func testObserverReceivesEveryPropertyChange() {
        let item = PopupItem()
        let owner = ObserverOwner()
        var notifications = 0
        item.addObserver(owner) { _ in notifications += 1 }

        item.title = "Title"
        item.subtitle = "Subtitle"
        item.image = UIImage(systemName: "music.note")
        item.progress = 0.5
        item.barButtonItems = [UIBarButtonItem(image: UIImage(systemName: "play.fill"), style: .plain, target: nil, action: nil)]

        XCTAssertEqual(notifications, 5)
    }

    func testRemovingObserverStopsNotifications() {
        let item = PopupItem()
        let owner = ObserverOwner()
        var notifications = 0
        item.addObserver(owner) { _ in notifications += 1 }
        item.removeObserver(owner)

        item.title = "Title"

        XCTAssertEqual(notifications, 0)
    }

    func testViewControllerPopupItemIsStable() {
        let viewController = UIViewController()

        XCTAssertTrue(viewController.popupItem === viewController.popupItem)
    }
}
