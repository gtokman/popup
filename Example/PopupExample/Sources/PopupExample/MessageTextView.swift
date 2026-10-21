//
//  MessageTextView.swift
//  OpenChat2
//
//  Created by Gary Tokman on 11/1/25.
//

import UIKit
import Then
import SnapKit
import UITextView_Placeholder

class MessageTextView: UIView {

    let minComposerHeight: CGFloat = 44
    let maxComposerHeight: CGFloat = 160
    var onCamera: (() -> Void)?
    var onPhotoLibrary: (() -> Void)?
    private(set) var selectedImages: [ChatImage] = []
    var imagesForSending: [ChatImage] {
        guard selectedImages.count > 1 else { return selectedImages }
        let order = attachmentDeck.orderedImageIndices
        guard order.count == selectedImages.count else { return selectedImages }
        return order.map { selectedImages[$0] }
    }
    var attachmentTransitionView: UIView { selectedImages.count > 1 ? attachmentDeck : attachmentImageView }

    private let attachmentRow = UIView()
    let attachmentImageView = ChatImageView(frame: .zero)
    private let attachmentDeck = PhotoDeckView(images: []).with {
        $0.horizontalCardMargin = 8
        $0.verticalCardMargin = 12
    }
    private let attachmentDivider = UIView()
    private let removeImageButton = UIButton(type: .system)
    private var attachmentRowHeightConstraint: Constraint?
    private var attachmentImageWidthConstraint: Constraint?
    private var attachmentImageHeightConstraint: Constraint?
    private var attachmentDeckWidthConstraint: Constraint?
    private var attachmentDeckHeightConstraint: Constraint?
    private var previewSize: CGSize = .zero
    private var previewImageIDs: [UUID] = []
    private var imageRemovalID = UUID()
    private var sendButtonIsProminent = false
    private var isReplying = false

    lazy var textViewGlassContainer = UIVisualEffectView(effect: Self.composerEffect).with {
        $0.layer.cornerRadius = minComposerHeight / 2
        $0.contentView.clipsToBounds = false
        $0.contentView.addSubview(attachmentRow)
        $0.contentView.addSubview(textView)
        attachmentRow.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            self.attachmentRowHeightConstraint = make.height.equalTo(0).constraint
        }
        textView.snp.makeConstraints { make in
            make.top.equalTo(attachmentRow.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
            self.textViewHeightConstraint = make.height.equalTo(minComposerHeight).constraint
        }
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        $0.setContentHuggingPriority(.required, for: .vertical)
        $0.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    let sendButton = UIButton().with {
        var configuration = MessageTextView.glassButtonConfiguration()
        configuration.image = UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(font: .boldSystemFont(ofSize: 18), scale: .default))
        $0.configuration = configuration
    }

    let textView = UITextView().with {
        $0.font = .systemFont(ofSize: 17, weight: .regular)
        $0.textContainerInset = .init(top: 12, left: 12, bottom: 8, right: 12 + 36)
        $0.textContainer.lineFragmentPadding = 0
        $0.tintColor = .white
        $0.placeholder = "Share with AI..."
        $0.backgroundColor = .clear
    }

    lazy var plusMenu = UIButton().with {
        let menu = UIMenu(title: "", children: [
            UIAction(title: "Camera", image: UIImage(systemName: "camera"), handler: { [weak self] _ in
                self?.onCamera?()
            }),
            UIAction(title: "Photo Library", image: UIImage(systemName: "photo"), handler: { [weak self] _ in
                self?.onPhotoLibrary?()
            })
        ])
        $0.showsMenuAsPrimaryAction = true
        $0.menu = menu
        $0.configuration = Self.glassButtonConfiguration()
        let img = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(font: .boldSystemFont(ofSize: 18), scale: .default))
        $0.setImage(img, for: .normal)
        $0.snp.makeConstraints { make in
            make.width.equalTo(44).priority(.required)
            make.height.equalTo(44).priority(.required)
        }
    }

    lazy var composerStackView = UIStackView().with {
        $0.axis = .horizontal
        $0.spacing = 8
        $0.alignment = .bottom
        [
            plusMenu,
            textViewGlassContainer,
        ].add(to: $0)
    }

    private var textViewHeightConstraint: Constraint?

    var currentText: String {
        textView.text ?? ""
    }

    private static var composerEffect: UIVisualEffect {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.isInteractive = true
            return effect
        }
        return UIBlurEffect(style: .systemMaterial)
    }

    private static func glassButtonConfiguration() -> UIButton.Configuration {
        if #available(iOS 26.0, *) { return .glass() }
        return .plain()
    }

    private static func sendButtonConfiguration(hasContent: Bool) -> UIButton.Configuration {
        if #available(iOS 26.0, *) {
            return hasContent ? .prominentGlass() : .glass()
        }
        return hasContent ? .filled() : .plain()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(composerStackView)
        composerStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        attachmentRow.addSubview(attachmentImageView)
        attachmentImageView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(6)
            attachmentImageWidthConstraint = make.width.equalTo(1).constraint
            attachmentImageHeightConstraint = make.height.equalTo(1).constraint
        }
        attachmentRow.addSubview(attachmentDeck)
        attachmentDeck.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(6)
            attachmentDeckWidthConstraint = make.width.equalTo(1).constraint
            attachmentDeckHeightConstraint = make.height.equalTo(1).constraint
        }
        attachmentDeck.isHidden = true
        attachmentRow.addSubview(attachmentDivider)
        attachmentDivider.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        attachmentDivider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }

        attachmentRow.addSubview(removeImageButton)
        var removeConfiguration = Self.glassButtonConfiguration()
        removeConfiguration.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(font: .boldSystemFont(ofSize: 11)))
        removeConfiguration.baseForegroundColor = .label
        removeConfiguration.cornerStyle = .capsule
        removeConfiguration.contentInsets = .zero
        removeImageButton.configuration = removeConfiguration
        removeImageButton.tintColor = .label
        removeImageButton.accessibilityLabel = "Remove photo"
        removeImageButton.snp.makeConstraints { make in
            make.top.equalTo(attachmentImageView.snp.top).offset(5)
            make.trailing.equalTo(attachmentImageView.snp.trailing).offset(-5)
            make.width.height.equalTo(30)
        }
        removeImageButton.addTarget(self, action: #selector(didTapRemoveImage), for: .touchUpInside)
        attachmentRow.isHidden = true
        attachmentRow.clipsToBounds = true

        addSubview(sendButton)
        sendButton.snp.makeConstraints { make in
            make.bottom.equalTo(snp.bottom).offset(-5)
            make.trailing.equalTo(snp.trailing).offset(-6)
            make.width.equalTo(34)
            make.height.equalTo(34)
        }
        textView.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setReplyReference(_ reference: ChatReplyReference?, animated: Bool = true) {
        isReplying = reference != nil
        textView.placeholder = reference == nil
            ? (selectedImages.isEmpty ? "Share with AI..." : "Add comment or Send")
            : "Reply"
        textView.setNeedsLayout()
    }

    func clearText() {
        textView.text = ""
        textView.isScrollEnabled = false
        setComposerHeight(minComposerHeight)
        updateSendButtonAppearance()
    }

    func setDraft(text: String, images: [ChatImage]) {
        clearText()
        clearImage()
        textView.text = text
        textViewDidChange(textView)
        appendImages(images)
    }

    func appendImages(_ images: [ChatImage]) {
        guard !images.isEmpty, selectedImages.count < 5 else { return }
        imageRemovalID = UUID()
        selectedImages = imagesForSending
        selectedImages.append(contentsOf: images.prefix(max(0, 5 - selectedImages.count)))
        attachmentRow.isHidden = false
        attachmentRow.alpha = 1
        attachmentRow.isUserInteractionEnabled = true
        textView.placeholder = isReplying ? "Reply" : "Add comment or Send"
        updatePreviewSize()
        invalidateIntrinsicContentSize()
        updateSendButtonAppearance()
    }

    func clearImage() {
        imageRemovalID = UUID()
        selectedImages.removeAll()
        attachmentImageView.image = nil
        attachmentDeck.setImages([])
        attachmentRow.isHidden = true
        attachmentRow.alpha = 1
        attachmentRow.isUserInteractionEnabled = true
        textView.placeholder = isReplying ? "Reply" : "Share with AI..."
        previewSize = .zero
        previewImageIDs = []
        attachmentRowHeightConstraint?.update(offset: 0)
        attachmentImageWidthConstraint?.update(offset: 1)
        attachmentImageHeightConstraint?.update(offset: 1)
        attachmentDeckWidthConstraint?.update(offset: 1)
        attachmentDeckHeightConstraint?.update(offset: 1)
        invalidateIntrinsicContentSize()
        updateSendButtonAppearance()
    }

    override func layoutSubviews() {
        updatePreviewSize()
        super.layoutSubviews()
    }

    @objc private func didTapRemoveImage() {
        guard !selectedImages.isEmpty else { return }
        if selectedImages.count > 1 {
            removeForegroundImage()
            return
        }
        let removalID = UUID()
        imageRemovalID = removalID
        let layoutView = superview ?? self
        layoutView.layoutIfNeeded()

        selectedImages.removeAll()
        textView.placeholder = "Share with AI..."
        previewSize = .zero
        previewImageIDs = []
        attachmentRow.isUserInteractionEnabled = false
        attachmentRowHeightConstraint?.update(offset: 0)
        attachmentImageWidthConstraint?.update(offset: 1)
        attachmentImageHeightConstraint?.update(offset: 1)
        attachmentDeckWidthConstraint?.update(offset: 1)
        attachmentDeckHeightConstraint?.update(offset: 1)
        invalidateIntrinsicContentSize()
        updateSendButtonAppearance()

        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 1.1,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.attachmentRow.alpha = 0
            layoutView.layoutIfNeeded()
        } completion: { _ in
            guard self.imageRemovalID == removalID else { return }
            self.attachmentRow.isHidden = true
            self.attachmentRow.alpha = 1
            self.attachmentRow.isUserInteractionEnabled = true
            self.attachmentImageView.image = nil
            self.attachmentDeck.setImages([])
        }
    }

    private func removeForegroundImage() {
        guard !attachmentDeck.isCyclingCards else { return }
        let orderedImages = imagesForSending
        guard orderedImages.count > 1 else { return }
        let layoutView = superview ?? self
        layoutView.layoutIfNeeded()

        let frontCard = attachmentDeck.frontCardView
        let flyingCard = frontCard?.snapshotView(afterScreenUpdates: false)
        if let flyingCard, let frontCard {
            flyingCard.frame = frontCard.convert(frontCard.bounds, to: attachmentRow)
            attachmentRow.insertSubview(flyingCard, belowSubview: removeImageButton)
        }

        imageRemovalID = UUID()
        selectedImages = Array(orderedImages.dropFirst())
        previewImageIDs = []
        updatePreviewSize()
        invalidateIntrinsicContentSize()
        updateSendButtonAppearance()
        removeImageButton.isEnabled = false
        if selectedImages.count == 1 { attachmentImageView.alpha = 0 }

        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 1.1,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            flyingCard?.alpha = 0
            flyingCard?.transform = CGAffineTransform(translationX: -18, y: -12)
                .rotated(by: -0.08)
                .scaledBy(x: 0.84, y: 0.84)
            self.attachmentImageView.alpha = 1
            layoutView.layoutIfNeeded()
        } completion: { _ in
            flyingCard?.removeFromSuperview()
            self.removeImageButton.isEnabled = true
        }
    }

    private func updatePreviewSize() {
        guard !selectedImages.isEmpty else { return }
        let availableWidth = max(1, bounds.width - 64)
        let isDeck = selectedImages.count > 1
        let size: CGSize
        if isDeck {
            let scale = min(1, availableWidth / 180)
            size = CGSize(width: 180 * scale, height: 204 * scale)
        } else {
            size = selectedImages[0].displaySize(maxWidth: min(160, availableWidth), maxHeight: 160)
        }
        let imageIDs = selectedImages.map(\.id)
        if imageIDs != previewImageIDs {
            previewImageIDs = imageIDs
            removeImageButton.accessibilityLabel = isDeck ? "Remove foreground photo" : "Remove photo"
            attachmentImageView.isHidden = isDeck
            attachmentDeck.isHidden = !isDeck
            if isDeck {
                attachmentDeck.setImages(selectedImages.compactMap(\.uiImage))
            } else {
                attachmentImageView.image = selectedImages[0].uiImage
            }
            removeImageButton.snp.remakeConstraints { make in
                if isDeck {
                    make.top.equalTo(attachmentDeck.snp.top).offset(8)
                    make.trailing.equalTo(attachmentDeck.snp.trailing).offset(-11)
                } else {
                    make.top.equalTo(attachmentImageView.snp.top).offset(5)
                    make.trailing.equalTo(attachmentImageView.snp.trailing).offset(-5)
                }
                make.width.height.equalTo(30)
            }
        }
        guard abs(size.width - previewSize.width) > 0.5 || abs(size.height - previewSize.height) > 0.5 else { return }
        previewSize = size
        attachmentRowHeightConstraint?.update(offset: size.height + 13)
        attachmentImageWidthConstraint?.update(offset: isDeck ? 1 : size.width)
        attachmentImageHeightConstraint?.update(offset: isDeck ? 1 : size.height)
        attachmentDeckWidthConstraint?.update(offset: isDeck ? size.width : 1)
        attachmentDeckHeightConstraint?.update(offset: isDeck ? size.height : 1)
    }

    private func setComposerHeight(_ height: CGFloat) {
        textViewHeightConstraint?.update(offset: height)
    }

    private func updateSendButtonAppearance() {
        let hasContent = !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty
        guard hasContent != sendButtonIsProminent else { return }
        sendButtonIsProminent = hasContent
        var configuration = Self.sendButtonConfiguration(hasContent: hasContent)
        configuration.image = UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(font: .boldSystemFont(ofSize: 18), scale: .default))
        sendButton.configuration = configuration
    }
}

extension MessageTextView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let target = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)).height
        let clamped = min(max(target, minComposerHeight), maxComposerHeight)
        setComposerHeight(clamped)
        textView.isScrollEnabled = clamped >= maxComposerHeight
        layoutIfNeeded()
        updateSendButtonAppearance()
    }
}
