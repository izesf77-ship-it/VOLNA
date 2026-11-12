import Foundation

/// Альбом
struct Album: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: URL?
    let releaseDate: Date?
    let providerID: String
    var tracks: [Track]
    
    init(
        id: String,
        title: String,
        artist: String,
        artworkURL: URL? = nil,
        releaseDate: Date? = nil,
        providerID: String,
        tracks: [Track] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.releaseDate = releaseDate
        self.providerID = providerID
        self.tracks = tracks
    }
    
    var trackCount: Int {
        tracks.count
    }
    
    var totalDuration: TimeInterval? {
        let durations = tracks.compactMap { $0.duration }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }
    
    var totalDurationFormatted: String? {
        guard let totalDuration = totalDuration else { return nil }
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else {
            return "\(minutes) мин"
        }
    }
    
    var releaseYear: String? {
        guard let releaseDate = releaseDate else { return nil }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: releaseDate)
        return "\(year)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }
}
