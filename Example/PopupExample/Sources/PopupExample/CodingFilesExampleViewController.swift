import popup
import SnapKit
import UIKit

final class CodingFilesExampleViewController: UIViewController {
    private let filesViewController = ChangedFilesViewController()
    private let composer = MessageTextView()
    private var didPresentPopup = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Files changed"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeExample)
        )
        view.backgroundColor = .black

        view.addSubview(composer)
        composer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top).offset(-12)
            make.height.greaterThanOrEqualTo(44)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPresentPopup, let navigationController else { return }
        didPresentPopup = true
        navigationController.setToolbarHidden(true, animated: false)
        navigationController.popupBar.preferredHeight = 35
        navigationController.popupBar.horizontalMargin = 13
        navigationController.popupBar.widthMode = .fitsContent
        navigationController.popupBar.showsImageBackground = false
        navigationController.popupController.barSpacing = 13
        navigationController.popupController.dockingAnchorView = composer
        navigationController.presentPopupBar(with: filesViewController, animated: true)
    }

    @objc private func closeExample() {
        navigationController?.dismissPopupBar(animated: false)
        navigationController?.dismiss(animated: true)
    }
}

final class ChangedFilesViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init() {
        super.init(nibName: nil, bundle: nil)
        popupItem.title = "2 files changed"
        popupItem.attributedTitle = Self.popupTitle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let heading = UILabel()
        heading.text = "Changed files"
        heading.font = .systemFont(ofSize: 34, weight: .bold)
        heading.textColor = .white
        heading.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(heading)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(closePopup), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        let files = UIStackView(arrangedSubviews: [
            makeFileRow(path: "app/page.tsx", additions: "+4", deletions: "−7"),
            makeFileRow(path: "app/globals.css", additions: "+2", deletions: "−2")
        ])
        files.axis = .vertical
        files.spacing = 18
        files.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(files)

        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            heading.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: heading.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            files.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            files.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            files.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 28)
        ])
    }

    private func makeFileRow(path: String, additions: String, deletions: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8

        let file = UILabel()
        file.text = path
        file.font = .systemFont(ofSize: 17)
        file.textColor = .white
        let added = UILabel()
        added.text = additions
        added.font = .systemFont(ofSize: 15, weight: .semibold)
        added.textColor = .systemGreen
        let removed = UILabel()
        removed.text = deletions
        removed.font = .systemFont(ofSize: 15, weight: .semibold)
        removed.textColor = .systemRed
        row.addArrangedSubview(file)
        row.addArrangedSubview(added)
        row.addArrangedSubview(removed)
        return row
    }

    @objc private func closePopup() {
        popupContainer?.closePopup(animated: true)
    }

    private static var popupTitle: NSAttributedString {
        let titleFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let countFont = UIFont.systemFont(ofSize: 14, weight: .medium)
        let title = NSMutableAttributedString(
            string: "2 files changed",
            attributes: [.font: titleFont, .foregroundColor: UIColor.label]
        )
        title.append(NSAttributedString(
            string: " +6",
            attributes: [.font: countFont, .foregroundColor: UIColor.systemGreen]
        ))
        title.append(NSAttributedString(
            string: " −9",
            attributes: [.font: countFont, .foregroundColor: UIColor.systemRed]
        ))
        return title
    }
}
