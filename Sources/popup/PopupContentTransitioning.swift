import UIKit

/// Adopted by a popup content controller to take part in the shared-element morph.
///
/// When provided, the popup bar's artwork flies into `popupArtworkView` while opening
/// and back into the bar while closing, so the bar and the full content read as one surface.
@MainActor
public protocol PopupContentTransitioning: AnyObject where Self: UIViewController {
    /// The view in the content hierarchy that matches the popup bar's artwork.
    var popupArtworkView: UIView? { get }
}
