import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let library = UINavigationController(rootViewController: LibraryViewController())
        library.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "books.vertical"), tag: 0)

        let search = SearchViewController()
        search.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 1)

        let radio = RadioViewController()
        radio.tabBarItem = UITabBarItem(title: "Radio", image: UIImage(systemName: "dot.radiowaves.left.and.right"), tag: 2)

        let tabs = UITabBarController()
        tabs.viewControllers = [library, search, radio]

        let nowPlaying = NowPlayingViewController()
        PlayerModel.shared.nowPlayingViewController = nowPlaying

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabs
        self.window = window
        window.makeKeyAndVisible()
    }
}
