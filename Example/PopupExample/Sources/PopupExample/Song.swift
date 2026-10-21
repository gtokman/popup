import Foundation

struct Song: Equatable, Identifiable {
    let title: String
    let artist: String
    let artworkIndex: Int
    let duration: TimeInterval

    var id: String {
        "\(title)-\(artist)"
    }

    static let library: [Song] = [
        Song(title: "Velvet Skies", artist: "The Paper Moons", artworkIndex: 0, duration: 218),
        Song(
            title: "Somewhere Between the Static and the Sea (Extended Mix)",
            artist: "The Sunday Hours & The Paper Moons Orchestra",
            artworkIndex: 1,
            duration: 196
        ),
        Song(title: "Pacific Avenue", artist: "Golden State", artworkIndex: 2, duration: 243),
        Song(title: "Afterglow", artist: "June Wilder", artworkIndex: 3, duration: 205),
        Song(title: "Little by Little", artist: "The Sunday Hours", artworkIndex: 4, duration: 232),
        Song(title: "Midnight Arcade", artist: "Neon Orchard", artworkIndex: 5, duration: 189),
        Song(title: "Bluebird", artist: "Hollis & Fern", artworkIndex: 6, duration: 251),
        Song(title: "Wildflower Season", artist: "Cleo Hart", artworkIndex: 7, duration: 224),
        Song(title: "Soft Landing", artist: "Daydream Hotel", artworkIndex: 8, duration: 207),
        Song(title: "Runaway Lights", artist: "Northbound", artworkIndex: 9, duration: 238),
        Song(title: "Paper Planes", artist: "Lena June", artworkIndex: 10, duration: 202),
        Song(title: "Almost Home", artist: "The Coastlines", artworkIndex: 11, duration: 229),
        Song(title: "Bright Side", artist: "Rory Finch", artworkIndex: 12, duration: 193),
        Song(title: "Easy Does It", artist: "Milo Park", artworkIndex: 13, duration: 217),
        Song(title: "Honeycomb", artist: "Olive Street", artworkIndex: 14, duration: 246),
        Song(title: "Satellite Heart", artist: "Luca Blue", artworkIndex: 15, duration: 211),
        Song(title: "City in Bloom", artist: "The New Romantics", artworkIndex: 16, duration: 234),
        Song(title: "Sweet Escape", artist: "Nina Vale", artworkIndex: 17, duration: 199),
        Song(title: "Green Light", artist: "Arden House", artworkIndex: 18, duration: 221),
        Song(title: "One More Summer", artist: "The Golden Years", artworkIndex: 19, duration: 240)
    ]
}
