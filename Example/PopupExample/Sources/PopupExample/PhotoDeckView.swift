import UIKit

// MARK: - Layout

/// Card-pile layout: every item shares the deck's center; depth (item
/// index) controls tilt, scale, and z-order. Only the top few cards are
/// returned from layoutAttributesForElements, so a deep stack never
/// instantiates cells until they surface — cells recycle through the
/// collection view's reuse pool as the pile cycles.
final class PhotoDeckLayout: UICollectionViewLayout {
    static let maxVisibleCards = 5

    /// Set by the deck view from its bounds; zero until first layout.
    var cardSize: CGSize = .zero

    private var visible: [UICollectionViewLayoutAttributes] = []

    /// Tilt per stack depth — alternating small angles so the pile reads as
    /// casually stacked prints; the front card is always straight.
    static func transform(forDepth depth: Int) -> CGAffineTransform {
        guard depth > 0 else { return .identity }
        let angles: [CGFloat] = [0, -0.14, 0.12, -0.09, 0.08, -0.11, 0.1]
        let angle = angles[min(depth, angles.count - 1)]
        let scale = max(0.9, 1 - CGFloat(depth) * 0.025)
        return CGAffineTransform(rotationAngle: angle).scaledBy(x: scale, y: scale)
    }

    private func attributes(forDepth depth: Int, count: Int) -> UICollectionViewLayoutAttributes {
        let attr = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: depth, section: 0))
        attr.size = cardSize
        attr.center = CGPoint(
            x: collectionView?.bounds.midX ?? 0,
            y: collectionView?.bounds.midY ?? 0
        )
        attr.zIndex = count - depth
        // Depths beyond the visible pile share the deepest slot so cycling
        // cards animate to/from a sensible resting place.
        attr.transform = Self.transform(forDepth: min(depth, Self.maxVisibleCards - 1))
        return attr
    }

    override func prepare() {
        visible.removeAll()
        guard let cv = collectionView, cardSize != .zero else { return }
        let count = cv.numberOfItems(inSection: 0)
        for depth in 0..<min(count, Self.maxVisibleCards) {
            visible.append(attributes(forDepth: depth, count: count))
        }
    }

    override var collectionViewContentSize: CGSize {
        collectionView?.bounds.size ?? .zero
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        visible
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributes(forDepth: indexPath.item, count: collectionView?.numberOfItems(inSection: 0) ?? 0)
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }

}

// MARK: - Cell

private final class PhotoCardCell: UICollectionViewCell {
    static let reuseID = "PhotoCardCell"

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 22
        imageView.layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(image: UIImage) {
        imageView.image = image
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 22).cgPath
    }
}

/// A pan that gives up as soon as the pre-begin movement is clearly
/// vertical, so an enclosing scroll view can take the drag. Deciding in
/// the recognizer itself sidesteps gestureRecognizerShouldBegin, which
/// UIKit asks of the hit-tested view (a deck card cell), not the deck.
///
/// The direction check runs BEFORE super sees the move: a fast flick can
/// jump past the pan's begin-threshold in a single touch sample, and once
/// super flips to .began the drag is already stolen from the scroll view.
private final class HorizontalPanGestureRecognizer: UIPanGestureRecognizer {
    private var startPoint: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        startPoint = touches.first?.location(in: view?.window)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible,
           let start = startPoint,
           let current = touches.first?.location(in: view?.window) {
            let dx = current.x - start.x
            let dy = current.y - start.y
            if abs(dy) > abs(dx), abs(dy) > 6 {
                state = .failed
            }
        }
        super.touchesMoved(touches, with: event)
    }

    override func reset() {
        super.reset()
        startPoint = nil
    }
}

// MARK: - Deck

/// iMessage-style photo pile: prints stacked with small alternating tilts,
/// front card straight. Drag the front card and it follows with a
/// proportional rotation, then flies out and tucks to the back while the
/// next print straightens into place. Tap the front card to Quick Look it.
public final class PhotoDeckView: UIView {
    /// Called with the image index of the front card when it's tapped.
    public var onTapFront: ((Int) -> Void)?

    public private(set) var images: [UIImage] = []
    /// Image indices, front first — rotated as cards cycle to the back.
    private var order: [Int] = []
    public var orderedImageIndices: [Int] { order }
    public var isCyclingCards: Bool { isCycling }
    private let layout = PhotoDeckLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private var isCycling = false

    /// Horizontal breathing room subtracted from bounds when sizing cards —
    /// the profile's full-width deck keeps the default; tighter homes
    /// (chat attachments) can shrink it.
    public var horizontalCardMargin: CGFloat = 96 {
        didSet { setNeedsLayout() }
    }
    public var verticalCardMargin: CGFloat = 44 {
        didSet { setNeedsLayout() }
    }

    /// The front card's cell — Quick Look zooms out of this.
    public var frontCardView: UIView? {
        collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
    }

    public init(images: [UIImage]) {
        super.init(frame: .zero)
        self.images = images
        order = Array(images.indices)

        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        // Fly-out and tilted cards draw past the deck's bounds
        collectionView.clipsToBounds = false
        collectionView.dataSource = self
        collectionView.register(PhotoCardCell.self, forCellWithReuseIdentifier: PhotoCardCell.reuseID)
        addSubview(collectionView)

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        addGestureRecognizer(panGesture)
    }

    /// Card-cycling pan. Horizontal-only so vertical drags fall through to
    /// whatever scroll view hosts the deck (chat thread, profile page).
    private lazy var panGesture = HorizontalPanGestureRecognizer(target: self, action: #selector(handlePan))

    required init?(coder: NSCoder) { fatalError() }

    /// Swap the deck's contents in place (cells recycle through reuse).
    public func setImages(_ images: [UIImage]) {
        self.images = images
        order = Array(images.indices)
        UIView.performWithoutAnimation {
            collectionView.reloadData()
            collectionView.layoutIfNeeded()
            reapplyDepthTransforms()
        }
    }

    /// Force every visible card back to its slot's transform. UIKit skips
    /// re-applying layout attributes it considers unchanged, so a reused
    /// cell that we manually animated (cycling) can keep a stale tilt —
    /// with exactly two cards the flown cell lands back in its old slot
    /// and stays crooked without this.
    private func reapplyDepthTransforms() {
        let visible = min(order.count, PhotoDeckLayout.maxVisibleCards)
        for depth in 0..<visible {
            guard let cell = collectionView.cellForItem(at: IndexPath(item: depth, section: 0)) else { continue }
            cell.transform = PhotoDeckLayout.transform(forDepth: depth)
            cell.layer.zPosition = 0
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = bounds
        let height = max(bounds.height - verticalCardMargin, 1)
        let width = min(height * 0.78, max(bounds.width - horizontalCardMargin, 1))
        let size = CGSize(width: width, height: width / 0.78)
        if size != layout.cardSize {
            layout.cardSize = size
            layout.invalidateLayout()
        }
    }

    // MARK: Gestures

    @objc private func handleTap() {
        guard let front = order.first else { return }
        onTapFront?(front)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !isCycling, let front = frontCardView else { return }
        let dx = gesture.translation(in: self).x

        switch gesture.state {
        case .changed:
            // The card shrinks as it travels, already heading toward its
            // tucked-in-back size.
            let progress = min(abs(dx) / max(bounds.width, 1), 1)
            let scale = 1 - progress * 0.3
            front.transform = CGAffineTransform(translationX: dx, y: 0)
                .rotated(by: dx / max(bounds.width, 1) * 0.35)
                .scaledBy(x: scale, y: scale)
        case .ended, .cancelled, .failed:
            let vx = gesture.velocity(in: self).x
            if gesture.state == .ended, abs(dx) > 70 || abs(vx) > 600 {
                cycle(towardsLeft: (dx + vx * 0.2) < 0)
            } else {
                UIView.animate(
                    withDuration: 0.45, delay: 0,
                    usingSpringWithDamping: 0.75, initialSpringVelocity: 0,
                    options: [.beginFromCurrentState, .allowUserInteraction]
                ) {
                    front.transform = .identity
                }
            }
        default:
            break
        }
    }

    /// Front card flies out in the swipe direction, the remaining cells
    /// spring one rank forward while the flown card tucks in at the deepest
    /// slot, then a non-animated reload syncs the data order with what's on
    /// screen. Deliberately avoids performBatchUpdates/moveItem: UIKit's
    /// move machinery leaks an animation cell each time a move's
    /// destination lies beyond the visible depth cap.
    private func cycle(towardsLeft: Bool) {
        guard order.count > 1, let front = frontCardView else { return }
        isCycling = true
        let sign: CGFloat = towardsLeft ? -1 : 1
        let visibleDepths = min(order.count, PhotoDeckLayout.maxVisibleCards)

        UIView.animate(
            withDuration: 0.22, delay: 0, options: [.curveEaseIn]
        ) {
            front.transform = CGAffineTransform(translationX: sign * self.bounds.width * 0.85, y: 0)
                .rotated(by: sign * 0.4)
                .scaledBy(x: 0.8, y: 0.8)
        } completion: { _ in
            // The collection view stacks cells by subview order (zPositions
            // are all zero), so dropping behind needs both a reorder and a
            // negative zPosition for good measure.
            front.layer.zPosition = -1
            self.collectionView.sendSubviewToBack(front)
            UIView.animate(
                withDuration: 0.5, delay: 0,
                usingSpringWithDamping: 0.8, initialSpringVelocity: 0
            ) {
                front.transform = PhotoDeckLayout.transform(forDepth: visibleDepths - 1)
                for depth in 1..<visibleDepths {
                    let cell = self.collectionView.cellForItem(at: IndexPath(item: depth, section: 0))
                    cell?.transform = PhotoDeckLayout.transform(forDepth: depth - 1)
                }
            } completion: { _ in
                // The cell goes back to the reuse pool — clear the stacking
                // override so it doesn't leak into its next incarnation.
                front.layer.zPosition = 0
                self.order.append(self.order.removeFirst())
                UIView.performWithoutAnimation {
                    self.collectionView.reloadData()
                    self.collectionView.layoutIfNeeded()
                    self.reapplyDepthTransforms()
                }
                self.isCycling = false
            }
        }
    }
}

extension PhotoDeckView: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoCardCell.reuseID, for: indexPath
        ) as! PhotoCardCell
        cell.configure(image: images[order[indexPath.item]])
        return cell
    }
}
