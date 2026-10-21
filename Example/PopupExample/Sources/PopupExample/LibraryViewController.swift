import popup
import UIKit

final class LibraryViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Library"
        navigationController?.navigationBar.prefersLargeTitles = true
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
        let player = PlayerModel.shared
        player.play(Song.library[indexPath.row])
        guard let nowPlaying = player.nowPlayingViewController,
              nowPlaying.popupContainer == nil else { return }
        tabBarController?.presentPopupBar(with: nowPlaying, animated: true)
    }
}
