//
//  Extensions.swift
//  OpenChat2
//
//  Created by Gary Tokman on 10/17/25.
//

import UIKit
import Then

extension Array where Element: UIView {

    func add(to stackView: UIStackView) {
        forEach { stackView.addArrangedSubview($0) }
    }
}

extension UILabel {

    /// The one chat body text style, shared by user bubbles, AI replies, and
    /// the thinking indicator.
    static func chatBody(color: UIColor = .white) -> UILabel {
        UILabel().with {
            $0.font = .systemFont(ofSize: 17, weight: .regular)
            $0.textColor = color
            $0.numberOfLines = 0
            $0.lineBreakMode = .byWordWrapping
        }
    }
}
