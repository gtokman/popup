import UIKit

enum Artwork {
    static func image(for index: Int, size: CGSize = CGSize(width: 600, height: 600)) -> UIImage {
        let hue = CGFloat((index * 37) % 360) / 360
        let colors = [
            UIColor(hue: hue, saturation: 0.9, brightness: 0.92, alpha: 1).cgColor,
            UIColor(hue: (hue + 0.22).truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 0.48, alpha: 1).cgColor
        ]
        let symbols = ["music.note", "waveform", "headphones", "sparkles", "guitars"]
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let drawingContext = context.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1]) else {
                return
            }
            drawingContext.drawLinearGradient(
                gradient,
                start: CGPoint.zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let symbol = UIImage(systemName: symbols[index % symbols.count])?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            let symbolSize = min(size.width, size.height) * 0.42
            let symbolRect = CGRect(
                x: (size.width - symbolSize) / 2,
                y: (size.height - symbolSize) / 2,
                width: symbolSize,
                height: symbolSize
            )
            drawingContext.saveGState()
            drawingContext.setAlpha(0.35)
            symbol?.draw(in: symbolRect)
            drawingContext.restoreGState()
        }
    }
}
