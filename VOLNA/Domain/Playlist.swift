import Foundation

/// Плейлист
struct Playlist: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var artworkURL: URL?
    var tracks: [Track]
    let createdAt: Date
    var modifiedAt: Date
    let isUserCreated: Bool
    
    init(
        id: String = UUID().uuidString,
        title: String,
        artworkURL: URL? = nil,
        tracks: [Track] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isUserCreated: Bool = true
    ) {
        self.id = id
        self.title = title
        self.artworkURL = artworkURL
        self.tracks = tracks
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isUserCreated = isUserCreated
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
    
    /// Generate artwork from first 4 tracks (mosaic style)
    var mosaicArtwork: [URL] {
        tracks.prefix(4).compactMap { $0.artworkURL }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}
