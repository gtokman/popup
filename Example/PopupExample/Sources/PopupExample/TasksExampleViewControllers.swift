import popup
import UIKit

final class TasksDashboardViewController: UIViewController {
    private let tasksViewController = TasksViewController()
    private var didPresentPopupBar = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dashboard"
        view.backgroundColor = .black

        let message = UILabel()
        message.text = "Your workspace is ready."
        message.font = .preferredFont(forTextStyle: .title3)
        message.textColor = .secondaryLabel
        message.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(message)
        NSLayoutConstraint.activate([
            message.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            message.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeExample)
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPresentPopupBar, let navigationController else { return }
        didPresentPopupBar = true
        navigationController.popupBar.preferredHeight = 46
        navigationController.popupBar.horizontalMargin = 17
        navigationController.popupBar.showsImageBackground = false
        navigationController.popupController.barSpacing = 14
        navigationController.presentPopupBar(with: tasksViewController, animated: true)
    }

    @objc private func closeExample() {
        navigationController?.dismissPopupBar(animated: false)
        navigationController?.dismiss(animated: true)
    }
}

final class TasksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let taskTitles = [
        "Build the task dashboard",
        "Connect persistent task storage",
        "Verify task management flows"
    ]
    private var completedTasks = [false, false, false]
    private let tableView = UITableView(frame: .zero, style: .plain)

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init() {
        super.init(nibName: nil, bundle: nil)
        popupItem.barButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain,
                target: self,
                action: #selector(dismissPopupBar)
            )
        ]
        updatePopupItem()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let titleLabel = UILabel()
        titleLabel.text = "Tasks"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(closePopup), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeButton)

        tableView.backgroundColor = .black
        tableView.separatorStyle = .none
        tableView.rowHeight = 47
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(TaskRowCell.self, forCellReuseIdentifier: "Task")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 54),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 30),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        taskTitles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Task", for: indexPath) as! TaskRowCell
        cell.configure(
            title: taskTitles[indexPath.row],
            isComplete: completedTasks[indexPath.row],
            isInProgress: indexPath.row == 0 && !completedTasks[indexPath.row]
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        completedTasks[indexPath.row].toggle()
        updatePopupItem()
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    private func updatePopupItem() {
        let completedCount = completedTasks.filter { $0 }.count
        popupItem.title = "Task \(completedCount) of \(taskTitles.count) complete"
        popupItem.subtitle = "Paused · Build the task dashboard"
        popupItem.image = Self.progressRing(completed: completedCount, total: taskTitles.count)
    }

    private static func progressRing(completed: Int, total: Int) -> UIImage {
        let size = CGSize(width: 32, height: 32)
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let context = renderer.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius: CGFloat = 12
            let startAngle = -CGFloat.pi / 2
            context.setLineWidth(2)
            context.setLineCap(.round)
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.42).cgColor)
            context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + 2 * .pi, clockwise: false)
            context.strokePath()
            if completed == 0 {
                context.setStrokeColor(UIColor.white.cgColor)
                context.move(to: CGPoint(x: center.x - 4, y: center.y))
                context.addLine(to: CGPoint(x: center.x + 4, y: center.y))
                context.strokePath()
            } else {
                context.setStrokeColor(UIColor.systemGreen.cgColor)
                context.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: startAngle + 2 * .pi * CGFloat(completed) / CGFloat(total),
                    clockwise: false
                )
                context.strokePath()
            }
        }.withRenderingMode(.alwaysOriginal)
    }

    @objc private func dismissPopupBar() {
        popupContainer?.dismissPopupBar(animated: true)
    }

    @objc private func closePopup() {
        popupContainer?.closePopup(animated: true)
    }
}

private final class TaskRowCell: UITableViewCell {
    private let statusView = TaskStatusView()
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .black
        selectionStyle = .none
        titleLabel.font = .systemFont(ofSize: 17)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statusView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusView)
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            statusView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusView.widthAnchor.constraint(equalToConstant: 22),
            statusView.heightAnchor.constraint(equalToConstant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, isComplete: Bool, isInProgress: Bool) {
        titleLabel.text = title
        statusView.isComplete = isComplete
        statusView.isInProgress = isInProgress
    }
}

private final class TaskStatusView: UIView {
    var isComplete = false { didSet { setNeedsLayout() } }
    var isInProgress = false { didSet { setNeedsLayout() } }

    private let circle = CAShapeLayer()
    private let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        circle.fillColor = UIColor.clear.cgColor
        circle.strokeColor = UIColor.white.withAlphaComponent(0.75).cgColor
        circle.lineWidth = 1.5
        layer.addSublayer(circle)
        checkmark.tintColor = .systemGreen
        addSubview(checkmark)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        circle.frame = bounds
        circle.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).cgPath
        circle.lineDashPattern = isInProgress && !isComplete ? [1, 3] : nil
        circle.isHidden = isComplete
        checkmark.frame = bounds
        checkmark.isHidden = !isComplete
    }
}
