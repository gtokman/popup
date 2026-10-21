//
//  ChatImage.swift
//  OpenChat2
//

import UIKit

/// A bounded, orientation-correct image that can be displayed in the composer
/// and transcript without keeping the full camera original in memory.
struct ChatImage: Hashable, Sendable {
    let id = UUID()
    let data: Data
    let pixelSize: CGSize

    var uiImage: UIImage? { UIImage(data: data) }

    static func == (lhs: ChatImage, rhs: ChatImage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func displaySize(maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return .zero }
        let scale = min(maxWidth / pixelSize.width, maxHeight / pixelSize.height)
        return CGSize(
            width: max(1, ceil(pixelSize.width * scale)),
            height: max(1, ceil(pixelSize.height * scale))
        )
    }

    static func prepare(_ image: UIImage) -> ChatImage? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let scale = min(1, 2048 / max(sourceSize.width, sourceSize.height))
        let size = CGSize(width: ceil(sourceSize.width * scale), height: ceil(sourceSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = rendered.pngData() else { return nil }
        return ChatImage(data: data, pixelSize: size)
    }
}

/// The same surface is used for the composer preview, send overlay, and sent
/// image. Its frame follows the photo's aspect ratio, so aspectFit never crops.
final class ChatImageView: UIImageView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .scaleAspectFit
        clipsToBounds = true
        if #available(iOS 26.0, *) {
            cornerConfiguration = .uniformCorners(radius: .containerConcentric(minimum: 16))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
