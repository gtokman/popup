import popup
import UIKit

final class NowPlayingViewController: UIViewController, PopupContentTransitioning {
    var popupArtworkView: UIView? {
        artworkView
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundGradient = CAGradientLayer()
    private let artworkWrapper = UIView()
    private let artworkView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let timeElapsedLabel = UILabel()
    private let timeRemainingLabel = UILabel()
    private let scrubber = UISlider()
    private let playPauseButton = UIButton(type: .system)
    private let volumeSlider = UISlider()
    private lazy var playPauseItem = UIBarButtonItem(
        image: UIImage(systemName: "play.fill"),
        style: .plain,
        target: self,
        action: #selector(togglePlayback)
    )
    private lazy var forwardItem = UIBarButtonItem(
        image: UIImage(systemName: "forward.fill"),
        style: .plain,
        target: self,
        action: #selector(skipForward)
    )

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationCapturesStatusBarAppearance = true
        configureViews()
        playerDidUpdate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
    }

    func playerDidUpdate() {
        let player = PlayerModel.shared
        let song = player.currentSong
        if let song {
            popupItem.title = song.title
            popupItem.subtitle = song.artist
            popupItem.image = Artwork.image(for: song.artworkIndex, size: CGSize(width: 120, height: 120))
            popupItem.progress = song.duration == 0 ? 0 : Float(player.elapsedTime / song.duration)
        } else {
            popupItem.title = "Nothing Playing"
            popupItem.subtitle = nil
            popupItem.image = nil
            popupItem.progress = 0
        }
        playPauseItem.image = UIImage(systemName: player.isPlaying ? "pause.fill" : "play.fill")
        popupItem.barButtonItems = [playPauseItem, forwardItem]

        guard isViewLoaded else { return }
        titleLabel.text = song?.title ?? "Nothing Playing"
        artistLabel.text = song?.artist ?? "Choose a song from your library"
        if let song {
            artworkView.image = Artwork.image(for: song.artworkIndex)
            let hue = CGFloat((song.artworkIndex * 37) % 360) / 360
            backgroundGradient.colors = [
                UIColor(hue: hue, saturation: 0.68, brightness: 0.36, alpha: 1).cgColor,
                UIColor(hue: (hue + 0.18).truncatingRemainder(dividingBy: 1), saturation: 0.72, brightness: 0.12, alpha: 1).cgColor,
                UIColor.black.cgColor
            ]
            scrubber.value = song.duration == 0 ? 0 : Float(player.elapsedTime / song.duration)
            timeElapsedLabel.text = Self.timeString(player.elapsedTime)
            timeRemainingLabel.text = "−\(Self.timeString(max(0, song.duration - player.elapsedTime)))"
        } else {
            artworkView.image = nil
            backgroundGradient.colors = [UIColor.darkGray.cgColor, UIColor.black.cgColor]
            scrubber.value = 0
            timeElapsedLabel.text = "0:00"
            timeRemainingLabel.text = "−0:00"
        }
        playPauseButton.setImage(UIImage(systemName: player.isPlaying ? "pause.fill" : "play.fill"), for: .normal)
        UIView.animate(withDuration: 0.35, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.artworkWrapper.transform = player.isPlaying ? .identity : CGAffineTransform(scaleX: 0.85, y: 0.85)
        }
    }

    @objc private func togglePlayback() {
        PlayerModel.shared.togglePlayback()
    }

    @objc private func skipForward() {
        PlayerModel.shared.skipForward()
    }

    @objc private func skipBackward() {
        PlayerModel.shared.skipBackward()
    }

    @objc private func seek(_ sender: UISlider) {
        PlayerModel.shared.seek(to: sender.value)
    }

    private func configureViews() {
        view.backgroundColor = .black
        backgroundGradient.colors = [UIColor.darkGray.cgColor, UIColor.black.cgColor]
        backgroundGradient.startPoint = CGPoint(x: 0, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(backgroundGradient, at: 0)

        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let header = makeHeader()
        contentStack.addArrangedSubview(header)
        contentStack.setCustomSpacing(20, after: header)

        configureArtwork()
        contentStack.addArrangedSubview(artworkWrapper)
        NSLayoutConstraint.activate([
            artworkWrapper.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -64),
            artworkWrapper.heightAnchor.constraint(equalTo: artworkWrapper.widthAnchor)
        ])
        contentStack.setCustomSpacing(24, after: artworkWrapper)

        titleLabel.font = .systemFont(ofSize: 25, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        artistLabel.font = .preferredFont(forTextStyle: .title3)
        artistLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        artistLabel.numberOfLines = 1
        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(3, after: titleLabel)
        contentStack.addArrangedSubview(artistLabel)
        contentStack.setCustomSpacing(14, after: artistLabel)

        let timeline = makeTimeline()
        contentStack.addArrangedSubview(timeline)
        contentStack.setCustomSpacing(20, after: timeline)
        let transportControls = makeTransportControls()
        contentStack.addArrangedSubview(transportControls)
        contentStack.setCustomSpacing(22, after: transportControls)
        let volumeControl = makeVolumeControl()
        contentStack.addArrangedSubview(volumeControl)
        contentStack.setCustomSpacing(26, after: volumeControl)
        contentStack.addArrangedSubview(makeUpNextSection())

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 32),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -32),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -64)
        ])
    }

    private func makeHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        closeButton.layer.cornerRadius = 18
        closeButton.addAction(UIAction { [weak self] _ in
            self?.popupContainer?.closePopup(animated: true)
        }, for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeButton)

        let grabber = UIView()
        grabber.backgroundColor = UIColor.white.withAlphaComponent(0.52)
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(grabber)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 36),
            closeButton.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            grabber.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            grabber.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5)
        ])
        return header
    }

    private func configureArtwork() {
        artworkWrapper.translatesAutoresizingMaskIntoConstraints = false
        artworkWrapper.layer.shadowColor = UIColor.black.cgColor
        artworkWrapper.layer.shadowOpacity = 0.28
        artworkWrapper.layer.shadowRadius = 22
        artworkWrapper.layer.shadowOffset = CGSize(width: 0, height: 14)
        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 14
        artworkView.layer.cornerCurve = .continuous
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkWrapper.addSubview(artworkView)
        NSLayoutConstraint.activate([
            artworkView.leadingAnchor.constraint(equalTo: artworkWrapper.leadingAnchor),
            artworkView.trailingAnchor.constraint(equalTo: artworkWrapper.trailingAnchor),
            artworkView.topAnchor.constraint(equalTo: artworkWrapper.topAnchor),
            artworkView.bottomAnchor.constraint(equalTo: artworkWrapper.bottomAnchor)
        ])
    }

    private func makeTimeline() -> UIView {
        let container = UIView()
        let labels = UIStackView(arrangedSubviews: [timeElapsedLabel, timeRemainingLabel])
        labels.axis = .horizontal
        labels.distribution = .equalSpacing
        labels.translatesAutoresizingMaskIntoConstraints = false
        [timeElapsedLabel, timeRemainingLabel].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            $0.textColor = UIColor.white.withAlphaComponent(0.7)
        }

        scrubber.minimumTrackTintColor = .white
        scrubber.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.22)
        scrubber.addTarget(self, action: #selector(seek(_:)), for: .valueChanged)
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labels)
        container.addSubview(scrubber)
        NSLayoutConstraint.activate([
            labels.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labels.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            labels.topAnchor.constraint(equalTo: container.topAnchor),
            scrubber.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: -4),
            scrubber.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 4),
            scrubber.topAnchor.constraint(equalTo: labels.bottomAnchor, constant: 1),
            scrubber.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func makeTransportControls() -> UIStackView {
        let backwardButton = UIButton(type: .system)
        backwardButton.setImage(UIImage(systemName: "backward.fill"), for: .normal)
        backwardButton.addTarget(self, action: #selector(skipBackward), for: .touchUpInside)

        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)

        let forwardButton = UIButton(type: .system)
        forwardButton.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        forwardButton.addTarget(self, action: #selector(skipForward), for: .touchUpInside)

        [backwardButton, playPauseButton, forwardButton].forEach {
            $0.tintColor = .white
        }
        playPauseButton.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        playPauseButton.layer.cornerRadius = 32
        let controls = UIStackView(arrangedSubviews: [backwardButton, playPauseButton, forwardButton])
        controls.axis = .horizontal
        controls.alignment = .center
        controls.distribution = .equalSpacing
        controls.isLayoutMarginsRelativeArrangement = true
        controls.layoutMargins = UIEdgeInsets(top: 0, left: 34, bottom: 0, right: 34)
        controls.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controls.heightAnchor.constraint(equalToConstant: 64),
            backwardButton.widthAnchor.constraint(equalToConstant: 44),
            backwardButton.heightAnchor.constraint(equalToConstant: 52),
            playPauseButton.widthAnchor.constraint(equalToConstant: 64),
            playPauseButton.heightAnchor.constraint(equalToConstant: 64),
            forwardButton.widthAnchor.constraint(equalToConstant: 44),
            forwardButton.heightAnchor.constraint(equalToConstant: 52)
        ])
        return controls
    }

    private func makeVolumeControl() -> UIStackView {
        let lowVolume = UIImageView(image: UIImage(systemName: "speaker.fill"))
        lowVolume.tintColor = UIColor.white.withAlphaComponent(0.62)
        let highVolume = UIImageView(image: UIImage(systemName: "speaker.wave.3.fill"))
        highVolume.tintColor = UIColor.white.withAlphaComponent(0.62)
        volumeSlider.minimumTrackTintColor = UIColor.white.withAlphaComponent(0.65)
        volumeSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.2)
        volumeSlider.value = 0.72

        let row = UIStackView(arrangedSubviews: [lowVolume, volumeSlider, highVolume])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        NSLayoutConstraint.activate([
            lowVolume.widthAnchor.constraint(equalToConstant: 16),
            highVolume.widthAnchor.constraint(equalToConstant: 20),
            row.heightAnchor.constraint(equalToConstant: 30)
        ])
        return row
    }

    private func makeUpNextSection() -> UIStackView {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 10

        let heading = UILabel()
        heading.text = "Up Next"
        heading.font = .systemFont(ofSize: 21, weight: .bold)
        heading.textColor = .white
        section.addArrangedSubview(heading)
        section.setCustomSpacing(8, after: heading)

        let currentIndex = PlayerModel.shared.currentSong.flatMap { Song.library.firstIndex(of: $0) } ?? -1
        for offset in 1...12 {
            let song = Song.library[(currentIndex + offset) % Song.library.count]
            section.addArrangedSubview(makeQueueRow(song))
        }
        return section
    }

    private func makeQueueRow(_ song: Song) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let imageView = UIImageView(image: Artwork.image(for: song.artworkIndex, size: CGSize(width: 96, height: 96)))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(imageView)

        let title = UILabel()
        title.text = song.title
        title.textColor = .white
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        let artist = UILabel()
        artist.text = song.artist
        artist.textColor = UIColor.white.withAlphaComponent(0.65)
        artist.font = .systemFont(ofSize: 13)
        let labels = UIStackView(arrangedSubviews: [title, artist])
        labels.axis = .vertical
        labels.spacing = 3
        labels.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(labels)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 56),
            imageView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),
            labels.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            labels.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            labels.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    private static func timeString(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
