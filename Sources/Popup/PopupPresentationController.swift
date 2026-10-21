import UIKit

/// Keeps the container on screen behind the open popup, owns the dimming layer and the
/// container-wide pan that closes the content or grabs an in-flight transition.
final class PopupPresentationController: UIPresentationController {
    unowned let popupController: PopupController
    let dimmingView = UIView()

    init(presentedViewController: UIViewController, presenting: UIViewController?, popupController: PopupController) {
        self.popupController = popupController
        super.init(presentedViewController: presentedViewController, presenting: presenting)
        dimmingView.backgroundColor = .black
        dimmingView.alpha = 0
        dimmingView.isUserInteractionEnabled = false
    }

    override var shouldRemovePresentersView: Bool { false }

    override var frameOfPresentedViewInContainerView: CGRect {
        containerView?.bounds ?? .zero
    }

    override func presentationTransitionWillBegin() {
        guard let containerView else { return }
        dimmingView.frame = containerView.bounds
        dimmingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.insertSubview(dimmingView, at: 0)
        containerView.addGestureRecognizer(popupController.contentPanGesture)
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        if !completed {
            dimmingView.removeFromSuperview()
        }
        popupController.transitionDidEnd(isOpen: completed)
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            dimmingView.removeFromSuperview()
        }
        popupController.transitionDidEnd(isOpen: !completed)
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        guard popupController.state == .open else { return }
        presentedView?.frame = frameOfPresentedViewInContainerView
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Keep the scaled container centred and rounded across rotation and window resizes.
        let presenterView = presentingViewController.view
        let transform = presenterView?.transform ?? .identity
        presenterView?.transform = .identity
        coordinator.animate(alongsideTransition: nil) { _ in
            presenterView?.transform = transform
        }
    }
}
