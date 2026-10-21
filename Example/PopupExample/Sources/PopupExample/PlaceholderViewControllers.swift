import UIKit

final class SearchViewController: UITableViewController {
    private let suggestions = ["Made for You", "New Releases", "Moods", "Charts", "Genres"]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search"
        navigationItem.largeTitleDisplayMode = .always
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Suggestion")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        suggestions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Suggestion", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = suggestions[indexPath.row]
        content.image = UIImage(systemName: "magnifyingglass")
        cell.contentConfiguration = content
        return cell
    }
}

final class TabAccessorySearchViewController: UITableViewController, UISearchResultsUpdating {
    private let songs = Song.library
    private var filteredSongs = Song.library
    private let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        definesPresentationContext = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResult")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredSongs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResult", for: indexPath)
        let song = filteredSongs[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = song.title
        content.secondaryText = song.artist
        content.image = UIImage(systemName: "music.note")
        cell.contentConfiguration = content
        return cell
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        filteredSongs = query.isEmpty
            ? songs
            : songs.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.artist.localizedCaseInsensitiveContains(query) }
        tableView.reloadData()
    }
}

final class RadioViewController: UICollectionViewController {
    private let stations = ["Chill", "Indie", "Focus", "Acoustic", "Discovery", "Classics"]

    init() {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.5),
                heightDimension: .fractionalHeight(1)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(150)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            return section
        }
        super.init(collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        tabBarItem = UITabBarItem(title: "Radio", image: UIImage(systemName: "dot.radiowaves.left.and.right"), tag: 2)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Radio"
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Station")
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        stations.count
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Station", for: indexPath)
        cell.contentView.backgroundColor = UIColor(
            hue: CGFloat(indexPath.item) / CGFloat(stations.count),
            saturation: 0.7,
            brightness: 0.75,
            alpha: 1
        )
        cell.contentView.layer.cornerRadius = 16
        cell.contentView.layer.cornerCurve = .continuous
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        let label = UILabel()
        label.text = stations[indexPath.item]
        label.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .title3).pointSize, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -16)
        ])
        return cell
    }
}
