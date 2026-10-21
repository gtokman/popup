import ObjectiveC
import UIKit

@MainActor
public final class PopupItem {
    public var title: String? { didSet { notify() } }
    public var subtitle: String? { didSet { notify() } }
    public var image: UIImage? { didSet { notify() } }
    public var progress: Float = 0 { didSet { notify() } }
    public var barButtonItems: [UIBarButtonItem] = [] { didSet { notify() } }

    private final class Observer {
        weak var owner: AnyObject?
        let handler: (PopupItem) -> Void

        init(owner: AnyObject, handler: @escaping (PopupItem) -> Void) {
            self.owner = owner
            self.handler = handler
        }
    }

    private var observers: [ObjectIdentifier: Observer] = [:]

    public init(title: String? = nil, subtitle: String? = nil, image: UIImage? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
    }

    func addObserver(_ owner: AnyObject, _ handler: @escaping (PopupItem) -> Void) {
        observers[ObjectIdentifier(owner)] = Observer(owner: owner, handler: handler)
    }

    func removeObserver(_ owner: AnyObject) {
        observers.removeValue(forKey: ObjectIdentifier(owner))
    }

    private func notify() {
        let currentObservers = observers
        for (identifier, observer) in currentObservers {
            guard observer.owner != nil else {
                observers.removeValue(forKey: identifier)
                continue
            }
            observer.handler(self)
        }
    }
}

@MainActor
private var popupItemAssociationKey: UInt8 = 0

extension UIViewController {
    public var popupItem: PopupItem {
        if let item = objc_getAssociatedObject(self, &popupItemAssociationKey) as? PopupItem {
            return item
        }

        let item = PopupItem()
        objc_setAssociatedObject(self, &popupItemAssociationKey, item, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return item
    }
}
