import UIKit

final class AppleMusicExampleViewController: UITabBarController {
    private let player = PlayerModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .onScrollDown
        }

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
