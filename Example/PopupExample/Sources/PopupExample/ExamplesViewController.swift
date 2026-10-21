import UIKit

final class ExamplesViewController: UITableViewController {
    private enum Example: CaseIterable {
        case appleMusic
        case tasks
        case agentChat
        case codingFiles

        var title: String {
            switch self {
            case .appleMusic: "Apple Music"
            case .tasks: "Tasks"
            case .agentChat: "Agent chat · Tasks"
            case .codingFiles: "Coding · Files changed"
            }
        }

        var subtitle: String {
            switch self {
            case .appleMusic: "An artwork-led music player"
            case .tasks: "A checklist with live popup updates"
            case .agentChat: "A task popup above a growing chat composer"
            case .codingFiles: "A compact change-summary popup above the composer"
            }
        }

        func makeViewController() -> UIViewController {
            switch self {
            case .appleMusic:
                return AppleMusicExampleViewController()
            case .tasks:
                let navigationController = UINavigationController(rootViewController: TasksDashboardViewController())
                navigationController.overrideUserInterfaceStyle = .dark
                return navigationController
            case .agentChat:
                let navigationController = UINavigationController(rootViewController: AgentChatViewController())
                navigationController.overrideUserInterfaceStyle = .dark
                return navigationController
            case .codingFiles:
                let navigationController = UINavigationController(rootViewController: CodingFilesExampleViewController())
                navigationController.overrideUserInterfaceStyle = .dark
                return navigationController
            }
        }
    }

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Examples"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 68
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Example.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Example")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Example")
        let example = Example.allCases[indexPath.row]
        cell.textLabel?.text = example.title
        cell.detailTextLabel?.text = example.subtitle
        cell.detailTextLabel?.numberOfLines = 0
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let controller = Example.allCases[indexPath.row].makeViewController()
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }
}
