import popup
import SnapKit
import UIKit

final class AgentChatViewController: UIViewController {
    private let tasksViewController = TasksViewController()
    private let composer = MessageTextView()
    private var didPresentPopupBar = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Build todo app"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeExample)
        )
        view.backgroundColor = .black
        configureMessages()

        view.addSubview(composer)
        composer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top).offset(-12)
            make.height.greaterThanOrEqualTo(44)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPresentPopupBar, let navigationController else { return }
        didPresentPopupBar = true
        navigationController.setToolbarHidden(true, animated: false)
        navigationController.popupBar.preferredHeight = 46
        navigationController.popupBar.horizontalMargin = 17
        navigationController.popupBar.showsImageBackground = false
        navigationController.popupController.barSpacing = 14
        navigationController.popupController.dockingAnchorView = composer
        navigationController.presentPopupBar(with: tasksViewController, animated: true)
    }

    private func configureMessages() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        stack.addArrangedSubview(makeBubble("Run command", isUser: true))
        stack.addArrangedSubview(makeBubble(
            "The preview wasn't running, so I'll start the dev server and then confirm the blue background.",
            isUser: false
        ))
        stack.addArrangedSubview(makeCommandCard())

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func makeBubble(_ message: String, isUser: Bool) -> UIView {
        let row = UIView()
        let bubble = UIView()
        bubble.backgroundColor = isUser ? .systemBlue : UIColor.white.withAlphaComponent(0.1)
        bubble.layer.cornerRadius = 18
        bubble.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(bubble)

        let label = UILabel()
        label.text = message
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(label)
        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: row.topAnchor),
            bubble.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            bubble.widthAnchor.constraint(lessThanOrEqualToConstant: 290),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -12)
        ])
        if isUser {
            bubble.trailingAnchor.constraint(equalTo: row.trailingAnchor).isActive = true
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: row.leadingAnchor, constant: 70).isActive = true
        } else {
            bubble.leadingAnchor.constraint(equalTo: row.leadingAnchor).isActive = true
            bubble.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -40).isActive = true
        }
        return row
    }

    private func makeCommandCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        card.layer.cornerRadius = 16

        let command = UILabel()
        command.text = "Bash · pnpm dev"
        command.font = .systemFont(ofSize: 15, weight: .semibold)
        command.textColor = .white
        command.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(command)

        let skip = UIButton(type: .system)
        skip.setTitle("Skip", for: .normal)
        let allow = UIButton(type: .system)
        allow.setTitle("Allow", for: .normal)
        allow.tintColor = .white
        allow.backgroundColor = .systemBlue
        allow.layer.cornerRadius = 10
        let buttons = UIStackView(arrangedSubviews: [skip, allow])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(buttons)
        NSLayoutConstraint.activate([
            command.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            command.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            command.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            buttons.leadingAnchor.constraint(equalTo: command.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: command.trailingAnchor),
            buttons.topAnchor.constraint(equalTo: command.bottomAnchor, constant: 14),
            buttons.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            buttons.heightAnchor.constraint(equalToConstant: 40)
        ])
        return card
    }

    @objc private func closeExample() {
        navigationController?.dismissPopupBar(animated: false)
        navigationController?.dismiss(animated: true)
    }
}
