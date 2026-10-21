import UIKit

final class PlayerModel {
    static let shared = PlayerModel()

    private(set) var currentSong: Song?
    private(set) var isPlaying = false
    private(set) var elapsedTime: TimeInterval = 0
    weak var nowPlayingViewController: NowPlayingViewController?
    private var timer: Timer?

    private init() {}

    func play(_ song: Song) {
        currentSong = song
        elapsedTime = 0
        isPlaying = true
        startTimer()
        updateNowPlaying()
    }

    func togglePlayback() {
        guard currentSong != nil else { return }
        isPlaying.toggle()
        if isPlaying {
            startTimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
        updateNowPlaying()
    }

    func skipForward() {
        guard let currentSong,
              let index = Song.library.firstIndex(of: currentSong) else { return }
        play(Song.library[(index + 1) % Song.library.count])
    }

    func skipBackward() {
        guard let currentSong,
              let index = Song.library.firstIndex(of: currentSong) else { return }
        if elapsedTime > 3 {
            elapsedTime = 0
            updateNowPlaying()
        } else {
            play(Song.library[(index - 1 + Song.library.count) % Song.library.count])
        }
    }

    func seek(to progress: Float) {
        guard let currentSong else { return }
        elapsedTime = TimeInterval(min(max(progress, 0), 1)) * currentSong.duration
        updateNowPlaying()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let song = self.currentSong else { return }
            self.elapsedTime += 1
            if self.elapsedTime >= song.duration {
                self.elapsedTime = 0
                self.isPlaying = false
                self.timer?.invalidate()
                self.timer = nil
            }
            self.updateNowPlaying()
        }
    }

    private func updateNowPlaying() {
        nowPlayingViewController?.playerDidUpdate()
    }
}
