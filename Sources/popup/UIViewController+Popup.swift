import ObjectiveC
import UIKit

@MainActor
private var popupControllerKey: UInt8 = 0
@MainActor
private var popupContainerKey: UInt8 = 0

@MainActor
private final class WeakViewControllerBox {
    weak var value: UIViewController?
    init(_ value: UIViewController?) { self.value = value }
}

extension UIViewController {
    /// The popup controller hosted by this container controller, created on first access.
    public var popupController: PopupController {
        if let existing = existingPopupController { return existing }
        let controller = PopupController(containerViewController: self)
        objc_setAssociatedObject(self, &popupControllerKey, controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return controller
    }

    var existingPopupController: PopupController? {
        objc_getAssociatedObject(self, &popupControllerKey) as? PopupController
    }

    /// The bar docked by this container controller.
    public var popupBar: PopupBar { popupController.bar }

    /// For a popup content controller: the container controller currently hosting it.
    public internal(set) var popupContainer: UIViewController? {
        get { (objc_getAssociatedObject(self, &popupContainerKey) as? WeakViewControllerBox)?.value }
        set { objc_setAssociatedObject(self, &popupContainerKey, WeakViewControllerBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Docks the popup bar for `contentViewController`, or swaps the content if a bar is already shown.
    public func presentPopupBar(with contentViewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        popupController.presentBar(with: contentViewController, animated: animated, completion: completion)
    }

    /// Opens the popup content from the bar through the shared transition.
    public func openPopup(animated: Bool = true, completion: (() -> Void)? = nil) {
        resolvedPopupController?.open(animated: animated, completion: completion)
    }

    /// Closes the popup content back into the bar. Callable on the container or on the content controller.
    public func closePopup(animated: Bool = true, completion: (() -> Void)? = nil) {
        resolvedPopupController?.close(animated: animated, completion: completion)
    }

    /// Closes the popup if needed and removes the bar.
    public func dismissPopupBar(animated: Bool = true, completion: (() -> Void)? = nil) {
        resolvedPopupController?.dismissBar(animated: animated, completion: completion)
    }

    private var resolvedPopupController: PopupController? {
        existingPopupController ?? popupContainer?.existingPopupController
    }
}
