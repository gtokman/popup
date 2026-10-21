import popup
import UIKit

final class LibraryViewController: UITableViewController {
    private let player: PlayerModel

    init(player: PlayerModel) {
        self.player = player
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Library"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeExample)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Song")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Song.library.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Song", for: indexPath)
        var content = cell.defaultContentConfiguration()
        let song = Song.library[indexPath.row]
        content.text = song.title
        content.secondaryText = song.artist
        content.image = Artwork.image(for: song.artworkIndex, size: CGSize(width: 88, height: 88))
        content.imageProperties.cornerRadius = 8
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        player.play(Song.library[indexPath.row])
        guard let nowPlaying = player.nowPlayingViewController,
              nowPlaying.popupContainer == nil else { return }
        tabBarController?.presentPopupBar(with: nowPlaying, animated: true)
    }

    @objc private func closeExample() {
        tabBarController?.dismissPopupBar(animated: false)
        player.stop()
        tabBarController?.dismiss(animated: true)
    }
}
