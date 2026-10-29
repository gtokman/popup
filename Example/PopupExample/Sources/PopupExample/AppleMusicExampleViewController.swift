import UIKit

final class AppleMusicExampleViewController: UITabBarController {
    private let player = PlayerModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        popupController.usesTabBarAccessory = false

        let nowPlaying = NowPlayingViewController(player: player)
        player.nowPlayingViewController = nowPlaying

        let library = UINavigationController(rootViewController: LibraryViewController(player: player))
        library.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "books.vertical"), tag: 0)

        let search = SearchViewController()
        search.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 1)

        let radio = RadioViewController()
        radio.tabBarItem = UITabBarItem(title: "Radio", image: UIImage(systemName: "dot.radiowaves.left.and.right"), tag: 2)

        viewControllers = [library, search, radio]
    }
}

final class AppleMusicAccessoryExampleViewController: UITabBarController {
    private let player = PlayerModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        popupController.usesTabBarAccessory = true
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .onScrollDown
        }

        let nowPlaying = NowPlayingViewController(player: player)
        player.nowPlayingViewController = nowPlaying

        let library = UINavigationController(rootViewController: LibraryViewController(player: player))
        let libraryTab = UITab(
            title: "Library",
            image: UIImage(systemName: "books.vertical"),
            identifier: "library",
            viewControllerProvider: { _ in library }
        )
        let radioTab = UITab(
            title: "Radio",
            image: UIImage(systemName: "dot.radiowaves.left.and.right"),
            identifier: "radio",
            viewControllerProvider: { _ in RadioViewController() }
        )
        let searchTab = UISearchTab(viewControllerProvider: { _ in
            UINavigationController(rootViewController: TabAccessorySearchViewController())
        })
        tabs = [libraryTab, radioTab, searchTab]
    }
}
